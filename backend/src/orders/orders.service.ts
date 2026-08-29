import { Inject, Injectable, forwardRef } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { isCheckViolation, isUniqueViolation } from '../common/pg-error';
import { AppConfig } from '../config/configuration';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { AuthContext } from '../auth/types/auth-context';
import { WalletCodService } from '../wallet-cod/wallet-cod.service';
import { OrderNotificationDispatcher } from '../notifications/order-notification.dispatcher';
import {
  FareRepository,
  serializeQuote,
  serializeSnapshot,
} from '../fare/fare.repository';
import { FareService } from '../fare/fare.service';
import { RoutingService } from '../routing/routing.service';
import { CatalogRepository } from './catalog.repository';
import { CreateOrderDto, CreateOrderStopDto } from './dto/create-order.dto';
import {
  hashRequest,
  IdempotencyRepository,
} from './idempotency.repository';
import { OrderStateMachine } from './order-state-machine';
import { OrderStatus, TransitionActor } from './order-status';
import {
  OrderOfferRow,
  OrderRow,
  OrderStopRow,
  OrdersRepository,
} from './orders.repository';

export type OrderActor = AuthContext;

@Injectable()
export class OrdersService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly orders: OrdersRepository,
    private readonly catalog: CatalogRepository,
    private readonly fares: FareRepository,
    private readonly fareService: FareService,
    private readonly routing: RoutingService,
    private readonly idempotency: IdempotencyRepository,
    private readonly machine: OrderStateMachine,
    private readonly configService: ConfigService,
    @Inject(forwardRef(() => WalletCodService))
    private readonly walletCod: WalletCodService,
    private readonly orderNotifications: OrderNotificationDispatcher,
  ) {}

  async create(auth: OrderActor, body: CreateOrderDto, idempotencyKey: string) {
    this.assertCustomer(auth);
    const key = this.scopedKey(auth.identityId, idempotencyKey);
    const requestHash = hashRequest({
      city_id: body.city_id,
      vehicle_category_id: body.vehicle_category_id,
      stops: body.stops,
    });
    const existing = await this.idempotency.find('create-order', key);
    if (existing) {
      return this.replayOrConflict(existing.request_hash, requestHash, existing.result_payload);
    }

    try {
      const created = await this.postgres.transaction(async (tx) => {
        const replay = await this.idempotency.find('create-order', key, tx);
        if (replay) {
          return this.replayOrConflict(
            replay.request_hash,
            requestHash,
            replay.result_payload,
          );
        }

        const city = await this.requireCity(body.city_id, tx);
        const category = await this.requireCategory(body.vehicle_category_id, tx);
        const stops = await this.validateStops(body.stops, city.city_id, tx);
        const displayId = await this.orders.allocateDisplayId(city.city_id, tx);
        const order = await this.orders.insertOrder(
          {
            displayId,
            customerProfileId: auth.profileId,
            cityId: city.city_id,
            cityCode: city.city_code,
            vehicleCategoryId: category.vehicle_category_id,
            vehicleCategoryName: category.name,
          },
          tx,
        );
        const insertedStops = await this.orders.insertStops(order.order_id, stops, tx);
        order.city_code = city.city_code;
        await this.orders.insertStatusEvent(
          {
            orderId: order.order_id,
            fromStatus: null,
            toStatus: 'CREATED',
            actorType: 'CUSTOMER',
            actorProfileId: auth.profileId,
            reason: 'order_created',
            idempotencyKey: 'NONE->CREATED',
          },
          tx,
        );
        const payload = this.serializeOrder(order, insertedStops);
        await this.idempotency.insert(
          {
            scope: 'create-order',
            key,
            actorIdentityId: auth.identityId,
            requestHash,
            resultEntityId: order.order_id,
            resultPayload: payload,
          },
          tx,
        );
        return payload;
      });
      return created;
    } catch (err) {
      if (isUniqueViolation(err, 'idempotency_scope_key_unique')) {
        const raced = await this.idempotency.find('create-order', key);
        if (!raced) {
          throw err;
        }
        return this.replayOrConflict(
          raced.request_hash,
          requestHash,
          raced.result_payload,
        );
      }
      if (isCheckViolation(err)) {
        throw new ApiError(
          ErrorCodes.INVALID_STOPS,
          'Order must have exactly one pickup and one to three drops',
          400,
        );
      }
      throw err;
    }
  }

  async listForCustomer(auth: OrderActor) {
    this.assertCustomer(auth);
    const rows = await this.orders.listForCustomer(auth.profileId);
    return { orders: rows.map((row) => this.serializeOrder(row)) };
  }

  async listForAdmin(auth: OrderActor) {
    this.assertAdmin(auth);
    const rows = await this.orders.listAll();
    const extras = await this.orders.listAdminExtras(
      rows.map((row) => row.order_id),
    );
    const extraById = new Map(extras.map((row) => [row.order_id, row]));
    return {
      orders: rows.map((row) =>
        this.serializeAdminOrder(row, extraById.get(row.order_id)),
      ),
    };
  }

  async getById(auth: OrderActor, orderId: string) {
    const order = await this.requireOrder(orderId);
    await this.assertCanReadOrder(auth, order);
    const [stops, snapshot] = await Promise.all([
      this.orders.listStops(order.order_id),
      this.fares.findSnapshotByOrder(order.order_id),
    ]);
    return {
      ...this.serializeOrder(order, stops),
      fare_snapshot: snapshot ? serializeSnapshot(snapshot) : null,
    };
  }

  async listStops(auth: OrderActor, orderId: string) {
    const order = await this.requireOrder(orderId);
    await this.assertCanReadOrder(auth, order);
    const stops = await this.orders.listStops(order.order_id);
    return { stops: stops.map((stop) => this.serializeStop(stop)) };
  }

  async quote(auth: OrderActor, orderId: string) {
    this.assertCustomer(auth);
    return this.postgres.transaction(async (tx) => {
      const order = await this.orders.lockById(orderId, tx);
      if (!order) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      this.assertCustomerOwns(auth, order);
      if (order.canonical_status !== 'CREATED') {
        throw new ApiError(
          ErrorCodes.ORDER_NOT_MODIFIABLE,
          'Fare can only be quoted before confirmation',
          409,
        );
      }
      const stops = await this.orders.listStops(order.order_id, tx);
      const routed = await this.routing.routeStops(stops);
      const quote = await this.fareService.quoteFromActiveConfig(
        {
          customerProfileId: auth.profileId,
          vehicleCategoryId: order.vehicle_category_id,
          distanceKm: this.routing.distanceKm(routed),
          stopCount: stops.length,
        },
        tx,
      );
      return {
        order_id: order.order_id,
        display_id: order.display_id,
        ...serializeQuote(quote),
        routing: this.routing.toResponse(routed),
      };
    });
  }

  async routeForAdmin(auth: OrderActor, orderId: string) {
    this.assertAdmin(auth);
    const order = await this.requireOrder(orderId);
    const stops = await this.orders.listStops(order.order_id);
    const routed = await this.routing.routeStops(stops);
    return {
      order_id: order.order_id,
      display_id: order.display_id,
      stop_count: stops.length,
      routing: this.routing.toResponse(routed),
    };
  }

  async confirm(auth: OrderActor, orderId: string, fareQuoteId: string) {
    this.assertCustomer(auth);
    return this.postgres.transaction(async (tx) => {
      const order = await this.orders.lockById(orderId, tx);
      if (!order) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      this.assertCustomerOwns(auth, order);
      const existingSnapshot = await this.fares.findSnapshotByOrder(order.order_id, tx);
      if (existingSnapshot) {
        const stops = await this.orders.listStops(order.order_id, tx);
        return {
          ...this.serializeOrder(order, stops),
          fare_snapshot: serializeSnapshot(existingSnapshot),
        };
      }
      if (order.canonical_status !== 'CREATED') {
        throw new ApiError(
          ErrorCodes.ORDER_NOT_MODIFIABLE,
          'Order fare is not awaiting confirmation',
          409,
        );
      }
      const quote = await this.fares.findQuote(fareQuoteId, tx);
      if (!quote) {
        throw new ApiError(ErrorCodes.QUOTE_NOT_FOUND, 'Fare quote was not found', 404);
      }
      const stops = await this.orders.listStops(order.order_id, tx);
      this.fareService.assertQuoteUsable({
        quote,
        customerProfileId: auth.profileId,
        vehicleCategoryId: order.vehicle_category_id,
        stopCount: stops.length,
      });
      const snapshot = await this.fares.insertSnapshotFromQuote(
        {
          orderId: order.order_id,
          quoteId: quote.fare_quote_id,
          vehicleCategoryName: order.vehicle_category_name_snapshot,
        },
        tx,
      );
      const updated = await this.applyTransition(
        {
          order,
          to: 'SEARCHING',
          actor: 'CUSTOMER',
          actorProfileId: auth.profileId,
          reason: 'fare_confirmed',
          eventKey: 'CREATED->SEARCHING',
        },
        tx,
      );
      return {
        ...this.serializeOrder(updated, stops),
        fare_quote: serializeQuote(quote),
        fare_snapshot: serializeSnapshot(snapshot),
      };
    });
  }

  async cancel(auth: OrderActor, orderId: string, reason?: string) {
    const actorType = this.actorType(auth);
    return this.postgres.transaction(async (tx) => {
      const order = await this.orders.lockById(orderId, tx);
      if (!order) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      if (actorType === 'CUSTOMER') {
        this.assertCustomerOwns(auth, order);
      } else if (actorType !== 'ADMIN') {
        throw new ApiError(
          ErrorCodes.FORBIDDEN,
          'Only the customer or an admin may cancel this order',
          403,
        );
      }
      if (order.canonical_status === 'CANCELLED') {
        return this.serializeOrder(order);
      }
      const updated = await this.applyTransition(
        {
          order,
          to: 'CANCELLED',
          actor: actorType,
          actorProfileId: auth.profileId,
          reason: reason ?? 'cancelled',
          eventKey: `${order.canonical_status}->CANCELLED`,
        },
        tx,
      );
      const expired = await this.orders.expireAllPendingOffers(order.order_id, tx);
      await this.orderNotifications.onOffersUnavailable(
        { order: updated, offers: expired, reason: 'CANCELLED' },
        tx,
      );
      return this.serializeOrder(updated);
    });
  }

  async transition(
    auth: OrderActor,
    orderId: string,
    toStatus: OrderStatus,
    reason?: string,
  ) {
    const actorType = this.actorType(auth);
    return this.postgres.transaction(async (tx) => {
      const order = await this.orders.lockById(orderId, tx);
      if (!order) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      if (actorType === 'CUSTOMER') {
        this.assertCustomerOwns(auth, order);
      } else if (actorType === 'RIDER') {
        if (order.rider_profile_id !== auth.profileId) {
          throw new ApiError(
            ErrorCodes.FORBIDDEN,
            'Rider is not assigned to this order',
            403,
          );
        }
      } else {
        this.assertAdmin(auth);
      }
      if (order.canonical_status === 'CREATED' && toStatus === 'SEARCHING') {
        throw new ApiError(
          ErrorCodes.FARE_NOT_CONFIRMED,
          'Confirm the fare quote to start searching',
          409,
        );
      }
      if (toStatus === 'OFFERED') {
        throw new ApiError(
          ErrorCodes.FORBIDDEN,
          'Offers are created through dispatch, not by setting status',
          403,
        );
      }
      if (toStatus === 'ASSIGNED') {
        throw new ApiError(
          ErrorCodes.FORBIDDEN,
          'Assignment happens through offer accept or admin assign',
          403,
        );
      }
      const updated = await this.applyTransition(
        {
          order,
          to: toStatus,
          actor: actorType,
          actorProfileId: auth.profileId,
          reason: reason ?? null,
          eventKey: `${order.canonical_status}->${toStatus}`,
        },
        tx,
      );
      return this.serializeOrder(updated);
    });
  }

  async offerToRider(auth: OrderActor, orderId: string, riderProfileId: string) {
    this.assertAdmin(auth);
    return this.postgres.transaction(async (tx) => {
      const order = await this.orders.lockById(orderId, tx);
      if (!order) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      const snapshot = await this.fares.findSnapshotByOrder(order.order_id, tx);
      if (!snapshot) {
        throw new ApiError(
          ErrorCodes.FARE_NOT_CONFIRMED,
          'Dispatch requires a confirmed fare snapshot',
          409,
        );
      }
      if (order.canonical_status !== 'SEARCHING' && order.canonical_status !== 'OFFERED') {
        throw new ApiError(
          ErrorCodes.ORDER_NOT_MODIFIABLE,
          'Offers can only be created while searching or offered',
          409,
        );
      }
      await this.assertRiderEligible(riderProfileId, tx);
      let offer: OrderOfferRow;
      try {
        offer = await this.orders.insertOffer(
          { orderId: order.order_id, riderProfileId },
          tx,
        );
      } catch (err) {
        if (isUniqueViolation(err, 'order_offers_pair_unique')) {
          throw new ApiError(
            ErrorCodes.OFFER_ALREADY_EXISTS,
            'This rider already has an offer for this order',
            409,
          );
        }
        throw err;
      }
      let updated = order;
      if (order.canonical_status === 'SEARCHING') {
        updated = await this.applyTransition(
          {
            order,
            to: 'OFFERED',
            actor: 'ADMIN',
            actorProfileId: auth.profileId,
            reason: 'offer_created',
            eventKey: `SEARCHING->OFFERED:${offer.order_offer_id}`,
          },
          tx,
        );
      }
      await this.orderNotifications.onNewOffer(
        {
          order: updated,
          offerId: offer.order_offer_id,
          riderProfileId,
        },
        tx,
      );
      return {
        ...this.serializeOffer(offer),
        order: this.serializeOrder(updated),
      };
    });
  }

  async assignRider(auth: OrderActor, orderId: string, riderProfileId: string) {
    this.assertAdmin(auth);
    return this.postgres.transaction(async (tx) => {
      const order = await this.orders.lockById(orderId, tx);
      if (!order) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      const snapshot = await this.fares.findSnapshotByOrder(order.order_id, tx);
      if (!snapshot) {
        throw new ApiError(
          ErrorCodes.FARE_NOT_CONFIRMED,
          'Assignment requires a confirmed fare snapshot',
          409,
        );
      }
      await this.assertRiderEligible(riderProfileId, tx, { skipOnline: true });
      const updated = await this.applyTransition(
        {
          order,
          to: 'ASSIGNED',
          actor: 'ADMIN',
          actorProfileId: auth.profileId,
          reason: 'admin_assigned',
          eventKey: `${order.canonical_status}->ASSIGNED:admin`,
          riderProfileId,
        },
        tx,
      );
      const expired = await this.orders.expireAllPendingOffers(order.order_id, tx);
      await this.orderNotifications.onOffersUnavailable(
        { order: updated, offers: expired, reason: 'CANCELLED' },
        tx,
      );
      return this.serializeOrder(updated);
    });
  }

  async listRiderOffers(auth: OrderActor) {
    this.assertRider(auth);
    const ttlMs = this.offerTtlMs();
    const rows = await this.orders.listOffersForRider(auth.profileId);
    const now = Date.now();
    return {
      offers: rows
        .filter((row) => {
          if (row.status !== 'PENDING') {
            return row.status === 'ACCEPTED';
          }
          if (row.canonical_status !== 'OFFERED' && row.canonical_status !== 'SEARCHING') {
            return false;
          }
          return row.created_at.getTime() + ttlMs > now;
        })
        .map((row) => ({
          ...this.serializeOffer(row),
          display_id: row.display_id,
          order_status: row.canonical_status,
        })),
    };
  }

  async acceptOffer(auth: OrderActor, offerId: string) {
    this.assertRider(auth);
    const idempotencyKey = `${auth.profileId}:${offerId}`;
    const requestHash = hashRequest({ offer_id: offerId, rider_profile_id: auth.profileId });
    const existing = await this.idempotency.find('accept-offer', idempotencyKey);
    if (existing) {
      return this.replayOrConflict(existing.request_hash, requestHash, existing.result_payload);
    }

    try {
      return await this.postgres.transaction(async (tx) => {
        const replay = await this.idempotency.find('accept-offer', idempotencyKey, tx);
        if (replay) {
          return this.replayOrConflict(replay.request_hash, requestHash, replay.result_payload);
        }

        const unlocked = await this.orders.findOffer(offerId, tx);
        if (!unlocked) {
          throw new ApiError(ErrorCodes.OFFER_NOT_FOUND, 'Offer was not found', 404);
        }
        const order = await this.orders.lockById(unlocked.order_id, tx);
        if (!order) {
          throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
        }
        const offer = await this.orders.lockOffer(offerId, tx);
        if (!offer) {
          throw new ApiError(ErrorCodes.OFFER_NOT_FOUND, 'Offer was not found', 404);
        }
        if (offer.rider_profile_id !== auth.profileId) {
          throw new ApiError(
            ErrorCodes.FORBIDDEN,
            'Offer does not belong to this rider',
            403,
          );
        }
        if (offer.status === 'ACCEPTED' && order.rider_profile_id === auth.profileId) {
          const payload = {
            ...this.serializeOffer(offer),
            order: this.serializeOrder(order),
          };
          return payload;
        }
        if (
          (order.rider_profile_id &&
            order.rider_profile_id !== auth.profileId) ||
          (order.canonical_status !== 'OFFERED' &&
            order.canonical_status !== 'SEARCHING')
        ) {
          throw new ApiError(
            ErrorCodes.ORDER_ALREADY_ACCEPTED,
            'Another rider has already accepted this order',
            409,
          );
        }
        if (
          offer.status === 'PENDING' &&
          offer.created_at.getTime() + this.offerTtlMs() <= Date.now()
        ) {
          await this.orders.updateOfferStatus(
            {
              offerId: offer.order_offer_id,
              fromStatus: 'PENDING',
              toStatus: 'EXPIRED',
            },
            tx,
          );
          await this.orderNotifications.onOffersUnavailable(
            {
              order,
              offers: [
                {
                  order_offer_id: offer.order_offer_id,
                  rider_profile_id: offer.rider_profile_id,
                },
              ],
              reason: 'EXPIRED',
            },
            tx,
          );
          const remaining = await this.orders.countPendingOffers(order.order_id, tx);
          if (order.canonical_status === 'OFFERED' && remaining === 0) {
            await this.applyTransition(
              {
                order,
                to: 'SEARCHING',
                actor: 'SYSTEM',
                actorProfileId: null,
                reason: 'offer_expired',
                eventKey: `OFFERED->SEARCHING:expired:${offer.order_offer_id}`,
              },
              tx,
            );
          }
          throw new ApiError(ErrorCodes.OFFER_EXPIRED, 'Offer has expired', 409);
        }
        this.assertOfferAcceptable(offer, order);
        await this.assertRiderEligible(auth.profileId, tx);
        if (await this.orders.riderHasLiveOrder(auth.profileId, tx)) {
          throw new ApiError(
            ErrorCodes.RIDER_HAS_ACTIVE_ORDER,
            'Rider already has a live order',
            409,
          );
        }

        const accepted = await this.orders.updateOfferStatus(
          { offerId: offer.order_offer_id, fromStatus: 'PENDING', toStatus: 'ACCEPTED' },
          tx,
        );
        if (!accepted) {
          throw new ApiError(
            ErrorCodes.OFFER_NOT_PENDING,
            'Offer is no longer pending',
            409,
          );
        }
        await this.orders.expireOtherPendingOffers(
          order.order_id,
          offer.order_offer_id,
          tx,
        ).then(async (expired) => {
          await this.orderNotifications.onOffersUnavailable(
            { order, offers: expired, reason: 'CANCELLED' },
            tx,
          );
        });
        const updated = await this.applyTransition(
          {
            order,
            to: 'ASSIGNED',
            actor: 'RIDER',
            actorProfileId: auth.profileId,
            reason: 'offer_accepted',
            eventKey: `${order.canonical_status}->ASSIGNED:${offer.order_offer_id}`,
            riderProfileId: auth.profileId,
          },
          tx,
        );
        const payload = {
          ...this.serializeOffer(accepted),
          order: this.serializeOrder(updated),
        };
        await this.idempotency.insert(
          {
            scope: 'accept-offer',
            key: idempotencyKey,
            actorIdentityId: auth.identityId,
            requestHash,
            resultEntityId: updated.order_id,
            resultPayload: payload,
          },
          tx,
        );
        return payload;
      });
    } catch (err) {
      if (isUniqueViolation(err, 'order_offers_one_accepted')) {
        throw new ApiError(
          ErrorCodes.ORDER_ALREADY_ACCEPTED,
          'Another rider has already accepted this order',
          409,
        );
      }
      if (isUniqueViolation(err, 'idempotency_scope_key_unique')) {
        const raced = await this.idempotency.find('accept-offer', idempotencyKey);
        if (!raced) {
          throw err;
        }
        return this.replayOrConflict(
          raced.request_hash,
          requestHash,
          raced.result_payload,
        );
      }
      throw err;
    }
  }

  async rejectOffer(auth: OrderActor, offerId: string) {
    this.assertRider(auth);
    return this.postgres.transaction(async (tx) => {
      const unlocked = await this.orders.findOffer(offerId, tx);
      if (!unlocked) {
        throw new ApiError(ErrorCodes.OFFER_NOT_FOUND, 'Offer was not found', 404);
      }
      const order = await this.orders.lockById(unlocked.order_id, tx);
      if (!order) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      const offer = await this.orders.lockOffer(offerId, tx);
      if (!offer) {
        throw new ApiError(ErrorCodes.OFFER_NOT_FOUND, 'Offer was not found', 404);
      }
      if (offer.rider_profile_id !== auth.profileId) {
        throw new ApiError(
          ErrorCodes.FORBIDDEN,
          'Offer does not belong to this rider',
          403,
        );
      }
      if (offer.status === 'REJECTED') {
        return { ...this.serializeOffer(offer), order: this.serializeOrder(order) };
      }
      if (offer.status !== 'PENDING') {
        throw new ApiError(
          ErrorCodes.OFFER_NOT_PENDING,
          'Only a pending offer can be rejected',
          409,
        );
      }
      const rejected = await this.orders.updateOfferStatus(
        { offerId: offer.order_offer_id, fromStatus: 'PENDING', toStatus: 'REJECTED' },
        tx,
      );
      if (!rejected) {
        throw new ApiError(
          ErrorCodes.OFFER_NOT_PENDING,
          'Offer is no longer pending',
          409,
        );
      }
      let updated = order;
      const remaining = await this.orders.countPendingOffers(order.order_id, tx);
      if (order.canonical_status === 'OFFERED' && remaining === 0) {
        updated = await this.applyTransition(
          {
            order,
            to: 'SEARCHING',
            actor: 'RIDER',
            actorProfileId: auth.profileId,
            reason: 'offer_rejected',
            eventKey: `OFFERED->SEARCHING:${offer.order_offer_id}`,
          },
          tx,
        );
      }
      return { ...this.serializeOffer(rejected), order: this.serializeOrder(updated) };
    });
  }

  private async applyTransition(
    input: {
      order: OrderRow;
      to: OrderStatus;
      actor: TransitionActor;
      actorProfileId: string | null;
      reason: string | null;
      eventKey: string;
      riderProfileId?: string;
    },
    tx: Queryable,
  ): Promise<OrderRow> {
    this.machine.assert({
      from: input.order.canonical_status,
      to: input.to,
      actor: input.actor,
    });
    const updated = await this.orders.compareAndSetStatus(
      {
        orderId: input.order.order_id,
        fromStatus: input.order.canonical_status,
        toStatus: input.to,
        riderProfileId: input.riderProfileId,
      },
      tx,
    );
    if (!updated) {
      throw new ApiError(
        ErrorCodes.INVALID_TRANSITION,
        'Order status changed concurrently',
        409,
      );
    }
    await this.orders.insertStatusEvent(
      {
        orderId: input.order.order_id,
        fromStatus: input.order.canonical_status,
        toStatus: input.to,
        actorType: input.actor,
        actorProfileId: input.actorProfileId,
        reason: input.reason,
        idempotencyKey: input.eventKey,
      },
      tx,
    );
    await this.orderNotifications.onStatusChange(
      {
        order: updated,
        from: input.order.canonical_status,
        to: input.to,
      },
      tx,
    );
    return updated;
  }

  private assertOfferAcceptable(offer: OrderOfferRow, order: OrderRow): void {
    if (
      (order.rider_profile_id &&
        order.rider_profile_id !== offer.rider_profile_id) ||
      (order.canonical_status !== 'OFFERED' &&
        order.canonical_status !== 'SEARCHING')
    ) {
      throw new ApiError(
        ErrorCodes.ORDER_ALREADY_ACCEPTED,
        'Another rider has already accepted this order',
        409,
      );
    }
    if (offer.status === 'REJECTED') {
      throw new ApiError(
        ErrorCodes.OFFER_REJECTED,
        'Rejected offers cannot be accepted',
        409,
      );
    }
    if (offer.status === 'EXPIRED') {
      throw new ApiError(ErrorCodes.OFFER_EXPIRED, 'Offer has expired', 409);
    }
    if (offer.status !== 'PENDING') {
      throw new ApiError(
        ErrorCodes.OFFER_NOT_PENDING,
        'Offer is not pending',
        409,
      );
    }
    if (offer.created_at.getTime() + this.offerTtlMs() <= Date.now()) {
      throw new ApiError(ErrorCodes.OFFER_EXPIRED, 'Offer has expired', 409);
    }
  }

  private async assertRiderEligible(
    riderProfileId: string,
    db: Queryable,
    opts?: { skipOnline?: boolean },
  ): Promise<void> {
    const rider = await this.catalog.findRider(riderProfileId, db);
    if (!rider || rider.deactivated_at) {
      throw new ApiError(ErrorCodes.RIDER_NOT_ELIGIBLE, 'Rider was not found', 409);
    }
    if (rider.approval_status !== 'APPROVED') {
      throw new ApiError(
        ErrorCodes.RIDER_NOT_ELIGIBLE,
        'Rider is not approved to receive orders',
        409,
      );
    }
    if (!opts?.skipOnline && rider.online_status !== 'ONLINE') {
      throw new ApiError(
        ErrorCodes.RIDER_NOT_ELIGIBLE,
        'Rider must be online to accept offers',
        409,
      );
    }
    await this.walletCod.assertNotSuspended(riderProfileId, db);
  }

  private async validateStops(
    stops: CreateOrderStopDto[],
    cityId: string,
    db: Queryable,
  ): Promise<CreateOrderStopDto[]> {
    const sorted = [...stops].sort((left, right) => left.sequence - right.sequence);
    const sequences = sorted.map((stop) => stop.sequence);
    if (new Set(sequences).size !== sequences.length) {
      throw new ApiError(
        ErrorCodes.INVALID_STOPS,
        'Stop sequences must be unique',
        400,
      );
    }
    if (sequences.some((sequence, index) => sequence !== index)) {
      throw new ApiError(
        ErrorCodes.INVALID_STOPS,
        'Stop sequences must start at 0 and be contiguous',
        400,
      );
    }
    const pickups = sorted.filter((stop) => stop.stop_type === 'PICKUP');
    const drops = sorted.filter((stop) => stop.stop_type === 'DROP');
    if (pickups.length !== 1) {
      throw new ApiError(
        ErrorCodes.INVALID_STOPS,
        'Order must have exactly one pickup',
        400,
      );
    }
    if (drops.length < 1 || drops.length > 3) {
      throw new ApiError(
        ErrorCodes.INVALID_STOPS,
        'Order must have one to three drop stops',
        400,
      );
    }
    if (sorted[0].stop_type !== 'PICKUP') {
      throw new ApiError(
        ErrorCodes.INVALID_STOPS,
        'Pickup must be sequence 0',
        400,
      );
    }
    if (sorted.slice(1).some((stop) => stop.stop_type !== 'DROP')) {
      throw new ApiError(
        ErrorCodes.INVALID_STOPS,
        'Stops after pickup must be drops',
        400,
      );
    }
    for (const stop of sorted) {
      if (stop.address_text.trim().length === 0) {
        throw new ApiError(
          ErrorCodes.INVALID_STOPS,
          'Each stop requires an address',
          400,
        );
      }
      if (stop.zone_id) {
        const zone = await this.catalog.findZone(stop.zone_id, db);
        if (!zone || !zone.active) {
          throw new ApiError(ErrorCodes.ZONE_INVALID, 'Zone was not found', 400);
        }
        if (zone.city_id !== cityId) {
          throw new ApiError(
            ErrorCodes.ZONE_INVALID,
            'Zone does not belong to the order city',
            400,
          );
        }
      }
    }
    return sorted;
  }

  private async requireCity(cityId: string, db: Queryable) {
    const city = await this.catalog.findActiveCity(cityId, db);
    if (!city || !city.active) {
      throw new ApiError(ErrorCodes.CITY_INVALID, 'City was not found or is inactive', 400);
    }
    return city;
  }

  private async requireCategory(vehicleCategoryId: string, db: Queryable) {
    const category = await this.catalog.findActiveVehicleCategory(
      vehicleCategoryId,
      db,
    );
    if (!category || !category.active) {
      throw new ApiError(
        ErrorCodes.VEHICLE_CATEGORY_INVALID,
        'Vehicle category was not found or is inactive',
        400,
      );
    }
    return category;
  }

  private async requireOrder(orderId: string): Promise<OrderRow> {
    const order = await this.orders.findById(orderId);
    if (!order) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    return order;
  }

  private async assertCanReadOrder(auth: OrderActor, order: OrderRow): Promise<void> {
    if (auth.role === 'ADMIN') {
      return;
    }
    if (auth.role === 'CUSTOMER') {
      if (order.customer_profile_id !== auth.profileId) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      return;
    }
    if (auth.role === 'RIDER') {
      if (order.rider_profile_id === auth.profileId) {
        return;
      }
      if (await this.orders.riderHasOffer(order.order_id, auth.profileId)) {
        return;
      }
      throw new ApiError(
        ErrorCodes.FORBIDDEN,
        'Rider is not permitted to access this order',
        403,
      );
    }
    throw new ApiError(ErrorCodes.FORBIDDEN, 'Not permitted', 403);
  }

  private assertCustomerOwns(auth: OrderActor, order: OrderRow): void {
    if (order.customer_profile_id !== auth.profileId) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
  }

  private assertCustomer(auth: OrderActor): void {
    if (auth.role !== 'CUSTOMER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Customer role required', 403);
    }
  }

  private assertRider(auth: OrderActor): void {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider role required', 403);
    }
  }

  private assertAdmin(auth: OrderActor): void {
    if (auth.role !== 'ADMIN') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin role required', 403);
    }
  }

  private actorType(auth: OrderActor): TransitionActor {
    return auth.role;
  }

  private scopedKey(identityId: string, key: string): string {
    return `${identityId}:${key}`;
  }

  private replayOrConflict(
    storedHash: string,
    requestHash: string,
    payload: unknown,
  ) {
    if (storedHash !== requestHash) {
      throw new ApiError(
        ErrorCodes.IDEMPOTENCY_CONFLICT,
        'Idempotency-Key was reused with a different request',
        409,
      );
    }
    return payload;
  }

  private offerTtlMs(): number {
    return (
      this.configService.getOrThrow<AppConfig['dispatch']>('dispatch')
        .offerTtlSeconds * 1000
    );
  }

  private serializeOrder(order: OrderRow, stops?: OrderStopRow[]) {
    return {
      order_id: order.order_id,
      display_id: order.display_id,
      customer_profile_id: order.customer_profile_id,
      rider_profile_id: order.rider_profile_id,
      city_id: order.city_id,
      city_code: order.city_code,
      vehicle_category_id: order.vehicle_category_id,
      vehicle_category_name: order.vehicle_category_name_snapshot,
      canonical_status: order.canonical_status,
      created_at: order.created_at.toISOString(),
      updated_at: order.updated_at.toISOString(),
      ...(stops ? { stops: stops.map((stop) => this.serializeStop(stop)) } : {}),
    };
  }

  private serializeAdminOrder(
    order: OrderRow,
    extra?: Awaited<ReturnType<OrdersRepository['listAdminExtras']>>[number],
  ) {
    const frozen = extra?.rider_amount != null;
    return {
      ...this.serializeOrder(order),
      customer_display_name: extra?.customer_display_name ?? null,
      customer_phone: extra?.customer_phone ?? null,
      rider_phone: extra?.rider_phone ?? null,
      pickup_address: extra?.pickup_address ?? null,
      drop_address: extra?.drop_address ?? null,
      trip_fare: extra?.trip_fare ?? null,
      net_payable: extra?.net_payable ?? null,
      finance_snapshot: frozen
        ? {
            snapshot_kind: 'ORIGINAL',
            trip_fare: extra.trip_fare,
            rider_amount: extra.rider_amount,
            company_commission_amount: extra.company_commission_amount,
            operational_cost_amount: extra.operational_cost_amount,
            profit_amount: extra.profit_amount,
            rider_percentage: extra.rider_percentage,
            company_commission_percentage: extra.company_commission_percentage,
            operational_cost_percentage_of_commission:
              extra.operational_cost_percentage_of_commission,
            tax: '0.00',
          }
        : null,
    };
  }

  private serializeStop(stop: OrderStopRow) {
    return {
      order_stop_id: stop.order_stop_id,
      sequence: stop.sequence,
      stop_type: stop.stop_type,
      address_text: stop.address_text,
      latitude: stop.latitude,
      longitude: stop.longitude,
      zone_id: stop.zone_id,
      contact_name: stop.contact_name,
      contact_phone: stop.contact_phone,
    };
  }

  private serializeOffer(offer: OrderOfferRow) {
    return {
      order_offer_id: offer.order_offer_id,
      order_id: offer.order_id,
      rider_profile_id: offer.rider_profile_id,
      status: offer.status,
      created_at: offer.created_at.toISOString(),
      responded_at: offer.responded_at ? offer.responded_at.toISOString() : null,
    };
  }
}


import { Inject, Injectable, forwardRef } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { isCheckViolation, isUniqueViolation } from '../common/pg-error';
import { AppConfig } from '../config/configuration';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { AuthContext } from '../auth/types/auth-context';
import { SettlementService } from '../settlement/settlement.service';
import { FinanceService } from '../payments/finance.service';
import { LocationService } from '../location/location.service';
import { WalletCodService } from '../wallet-cod/wallet-cod.service';
import { OrderNotificationDispatcher } from '../notifications/order-notification.dispatcher';
import {
  FareRepository,
  serializeQuote,
  serializeSnapshot,
} from '../fare/fare.repository';
import { FareService } from '../fare/fare.service';
import { formatInr } from '../fare/money';
import { haversineMeters } from '../routing/coordinates';
import { RoutingService } from '../routing/routing.service';
import { riderMayAccessRides } from '../files/rider-verification';
import { riderProfileGaps } from '../profiles/rider-profile-completion';
import { CatalogRepository } from './catalog.repository';
import { CreateOrderDto, CreateOrderStopDto } from './dto/create-order.dto';
import { PreviewVehicleFaresDto } from './dto/preview-vehicle-fares.dto';
import { assertPackageForVehicle, assertDropContact, normalizeContactPhone } from './package-constraints';
import {
  isCustomerBookableVehicle,
  serializeCustomerVehicleFare,
} from './vehicle-fare';
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
    private readonly settlement: SettlementService,
    @Inject(forwardRef(() => FinanceService))
    private readonly finance: FinanceService,
    private readonly locations: LocationService,
  ) {}

  async create(auth: OrderActor, body: CreateOrderDto, idempotencyKey: string) {
    this.assertCustomer(auth);
    const key = this.scopedKey(auth.identityId, idempotencyKey);
    const requestHash = hashRequest({
      city_id: body.city_id,
      vehicle_category_id: body.vehicle_category_id,
      package_weight_kg: body.package_weight_kg ?? null,
      package_size_cm: body.package_size_cm ?? null,
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

        await this.settlement.assertNoOutstanding(auth.profileId, tx);
        const city = await this.requireCity(body.city_id, tx);
        const category = await this.requireCategory(body.vehicle_category_id, tx);
        assertPackageForVehicle({
          weightKg: body.package_weight_kg ?? null,
          weightCapacity: category.weight_capacity,
          packageSizeCm: body.package_size_cm ?? null,
          sizeLimit: category.size,
        });
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
            packageWeightKg: body.package_weight_kg ?? null,
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
    return {
      orders: rows.map((row) => ({
        ...this.serializeOrder(row),
        pickup_address: row.pickup_address,
        drop_address: row.drop_address,
        trip_fare: row.list_trip_fare,
        net_payable: row.list_net_payable,
      })),
    };
  }

  async listForAdmin(auth: OrderActor) {
    this.assertAdmin(auth);
    const rows = await this.orders.listAll();
    const extras = await this.orders.listAdminExtras(
      rows.map((row) => row.order_id),
    );
    const extraById = new Map(extras.map((row) => [row.order_id, row]));
    const ratings = await this.orders.listCustomerRatings(
      rows.map((row) => row.order_id),
    );
    const ratingById = new Map(ratings.map((row) => [row.order_id, row]));
    return {
      orders: rows.map((row) => ({
        ...this.serializeAdminOrder(row, extraById.get(row.order_id)),
        customer_rating: this.serializeRating(ratingById.get(row.order_id)),
      })),
    };
  }

  async getById(auth: OrderActor, orderId: string) {
    let order = await this.requireOrder(orderId);
    await this.assertCanReadOrder(auth, order);
    if (order.canonical_status === 'SEARCHING' && auth.role !== 'RIDER') {
      await this.retrySearchingDispatch(order.order_id);
      order = (await this.orders.findById(order.order_id)) ?? order;
    }
    const [stops, snapshot, waiting, assignedRider, rating] = await Promise.all([
      this.orders.listStops(order.order_id),
      this.fares.findSnapshotByOrder(order.order_id),
      auth.role === 'RIDER'
        ? Promise.resolve(null)
        : this.settlement.waitingSummary(order.order_id, this.postgres),
      order.rider_profile_id
        ? this.catalog.findAssignedRiderDisplay(order.rider_profile_id)
        : Promise.resolve(null),
      this.orders.findCustomerRating(order.order_id),
    ]);
    return {
      ...this.serializeOrder(order, stops),
      customer_rating: this.serializeRating(rating),
      fare_snapshot: snapshot ? serializeSnapshot(snapshot) : null,
      assigned_rider: assignedRider
        ? {
            name: assignedRider.name,
            vehicle_registration: assignedRider.vehicle_registration,
            vehicle_category_name: assignedRider.vehicle_category_name,
            phone: assignedRider.phone,
          }
        : null,
      ...(auth.role === 'RIDER'
        ? snapshot
          ? { rider_amount: snapshot.rider_amount }
          : {}
        : { waiting }),
    };
  }

  async listStops(auth: OrderActor, orderId: string) {
    const order = await this.requireOrder(orderId);
    await this.assertCanReadOrder(auth, order);
    const stops = await this.orders.listStops(order.order_id);
    return { stops: stops.map((stop) => this.serializeStop(stop)) };
  }

  /**
   * Customer/admin live rider pin for an assigned in-progress order.
   * Does not expose location before assignment or after terminal states.
   */
  async getAssignedRiderLocation(auth: OrderActor, orderId: string) {
    if (auth.role !== 'CUSTOMER' && auth.role !== 'ADMIN') {
      throw new ApiError(
        ErrorCodes.FORBIDDEN,
        'Only the customer or an admin may read rider location for this order',
        403,
      );
    }
    const order = await this.requireOrder(orderId);
    await this.assertCanReadOrder(auth, order);
    if (!order.rider_profile_id) {
      throw new ApiError(
        ErrorCodes.ORDER_NOT_MODIFIABLE,
        'No rider is assigned to this order yet',
        409,
      );
    }
    const live = new Set<OrderStatus>([
      'ASSIGNED',
      'EN_ROUTE_PICKUP',
      'ARRIVED_PICKUP',
      'PICKED_UP',
      'IN_TRANSIT',
      'NEAR_DROP',
      'DELIVERY_ATTEMPT',
    ]);
    if (!live.has(order.canonical_status)) {
      throw new ApiError(
        ErrorCodes.ORDER_NOT_MODIFIABLE,
        'Rider location is only available during an active delivery',
        409,
      );
    }
    const payload = await this.locations.getRiderLocationForConsumer(
      order.rider_profile_id,
    );
    return {
      order_id: order.order_id,
      rider_profile_id: order.rider_profile_id,
      ...payload,
    };
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
      await this.requireCategory(order.vehicle_category_id, tx);
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

  async previewVehicleFares(auth: OrderActor, body: PreviewVehicleFaresDto) {
    this.assertCustomer(auth);
    const city = await this.requireCity(body.city_id, this.postgres);
    const stops = await this.validateStops(body.stops, city.city_id, this.postgres, {
      requireDropContact: false,
    });
    const routed = await this.routing.routeStops(stops);
    const distanceKm = this.routing.distanceKm(routed);
    const rows = await this.fares.previewActiveVehicleFares(distanceKm);
    return {
      distance_km: distanceKm,
      stop_count: stops.length,
      routing: this.routing.toResponse(routed),
      vehicles: rows
        .filter((row) => isCustomerBookableVehicle(row))
        .map((row) => serializeCustomerVehicleFare(row)),
    };
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
      const category = await this.requireCategory(order.vehicle_category_id, tx);
      const quote = await this.fares.findQuote(fareQuoteId, tx);
      if (!quote) {
        throw new ApiError(ErrorCodes.QUOTE_NOT_FOUND, 'Fare quote was not found', 404);
      }
      const stops = await this.orders.listStops(order.order_id, tx);
      const routed = await this.routing.routeStops(stops);
      const distanceKm = this.routing.distanceKm(routed);
      this.fareService.assertQuoteUsable({
        quote,
        customerProfileId: auth.profileId,
        vehicleCategoryId: order.vehicle_category_id,
        stopCount: stops.length,
        distanceKm,
      });
      assertPackageForVehicle({
        weightKg:
          order.package_weight_kg == null ? null : Number(order.package_weight_kg),
        weightCapacity: category.weight_capacity,
      });
      const recalculated = await this.fares.tripFareForVersion(
        {
          fareConfigVersionId: quote.fare_config_version_id,
          vehicleCategoryId: order.vehicle_category_id,
          distanceKm,
        },
        tx,
      );
      let recalculatedFare: string;
      let quotedFare: string;
      try {
        if (!recalculated) {
          throw new Error('missing fare');
        }
        recalculatedFare = formatInr(recalculated);
        quotedFare = formatInr(quote.trip_fare);
      } catch {
        throw new ApiError(
          ErrorCodes.QUOTE_MISMATCH,
          'Fare quote does not match the fare configuration for this route',
          409,
        );
      }
      if (recalculatedFare !== quotedFare) {
        throw new ApiError(
          ErrorCodes.QUOTE_MISMATCH,
          'Fare quote does not match the fare configuration for this route',
          409,
        );
      }
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
    }).then(async (payload) => {
      // Confirm must succeed even if no riders are online yet.
      // Dispatch uses the same order_offers seam as admin offer creation.
      try {
        await this.dispatchOffersForSearchingOrder(payload.order_id as string);
      } catch {
        // Leave order in SEARCHING; customer poll / admin can still dispatch.
      }
      return payload;
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
      return this.createOfferInTx({
        orderId,
        riderProfileId,
        actor: 'ADMIN',
        actorProfileId: auth.profileId,
        tx,
      });
    });
  }

  /**
   * Offers the nearest eligible online rider who has a fresh GPS fix.
   * One offer at a time so a reject or expiry can try the next nearest rider.
   * Riders without a recent location are skipped, not replaced by a random id.
   */
  async dispatchOffersForSearchingOrder(orderId: string) {
    return this.postgres.transaction(async (tx) => {
      const order = await this.orders.lockById(orderId, tx);
      if (!order || order.canonical_status !== 'SEARCHING') {
        return { offered: 0 };
      }
      const snapshot = await this.fares.findSnapshotByOrder(order.order_id, tx);
      if (!snapshot) {
        return { offered: 0 };
      }
      const stops = await this.orders.listStops(order.order_id, tx);
      const pickup = stops.find((stop) => stop.stop_type === 'PICKUP');
      const pickupLat = pickup ? Number(pickup.latitude) : Number.NaN;
      const pickupLng = pickup ? Number(pickup.longitude) : Number.NaN;
      if (!Number.isFinite(pickupLat) || !Number.isFinite(pickupLng)) {
        return { offered: 0 };
      }
      const alreadyOffered = new Set(
        await this.orders.listRiderIdsWithOffers(order.order_id, tx),
      );
      const candidates = await this.catalog.listEligibleOnlineRidersForCategory(
        order.vehicle_category_id,
        tx,
      );
      const ranked: Array<{ riderProfileId: string; meters: number }> = [];
      for (const riderProfileId of candidates) {
        if (alreadyOffered.has(riderProfileId)) {
          continue;
        }
        if (await this.orders.riderHasLiveOrder(riderProfileId, tx)) {
          continue;
        }
        const fix = await this.locations.getRiderLocationForConsumer(riderProfileId);
        const latitude = fix.location?.latitude;
        const longitude = fix.location?.longitude;
        if (
          fix.stale ||
          typeof latitude !== 'number' ||
          typeof longitude !== 'number'
        ) {
          continue;
        }
        ranked.push({
          riderProfileId,
          meters: haversineMeters(
            { latitude: pickupLat, longitude: pickupLng },
            { latitude, longitude },
          ),
        });
      }
      ranked.sort((a, b) => a.meters - b.meters);
      for (const candidate of ranked) {
        try {
          await this.createOfferInTx({
            orderId: order.order_id,
            riderProfileId: candidate.riderProfileId,
            actor: 'SYSTEM',
            actorProfileId: null,
            tx,
          });
          return { offered: 1 };
        } catch {
          // Duplicate or ineligible; try the next nearest rider.
        }
      }
      return { offered: 0 };
    });
  }

  private async createOfferInTx(input: {
    orderId: string;
    riderProfileId: string;
    actor: TransitionActor;
    actorProfileId: string | null;
    tx: Queryable;
  }) {
    const order = await this.orders.lockById(input.orderId, input.tx);
    if (!order) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    const snapshot = await this.fares.findSnapshotByOrder(order.order_id, input.tx);
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
    await this.assertRiderEligible(input.riderProfileId, input.tx);
    let offer: OrderOfferRow;
    try {
      offer = await this.orders.insertOffer(
        { orderId: order.order_id, riderProfileId: input.riderProfileId },
        input.tx,
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
          actor: input.actor,
          actorProfileId: input.actorProfileId,
          reason: 'offer_created',
          eventKey: `SEARCHING->OFFERED:${offer.order_offer_id}`,
        },
        input.tx,
      );
    }
    await this.orderNotifications.onNewOffer(
      {
        order: updated,
        offerId: offer.order_offer_id,
        riderProfileId: input.riderProfileId,
      },
      input.tx,
    );
    return {
      ...this.serializeOffer(offer),
      order: this.serializeOrder(updated),
    };
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
    const rider = await this.catalog.findRider(auth.profileId);
    if (
      !rider ||
      !riderMayAccessRides({
        approvalStatus: rider.approval_status,
        deactivated: Boolean(rider.deactivated_at),
      })
    ) {
      throw new ApiError(
        ErrorCodes.RIDER_NOT_ELIGIBLE,
        'Rider is not approved to receive orders',
        409,
      );
    }
    await this.releaseExpiredOffers();
    if (rider.online_status === 'ONLINE' && !rider.deactivated_at) {
      const searching = await this.orders.listSearchingOrderIdsForRider(
        auth.profileId,
      );
      for (const searchingOrderId of searching) {
        await this.retrySearchingDispatch(searchingOrderId);
      }
    }
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
          crn: row.crn,
          order_status: row.canonical_status,
          rider_amount: row.rider_amount,
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
      let redispatchOrderId: string | null = null;
      const payload = await this.postgres.transaction(async (tx) => {
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
          // Commit expire (+ optional SEARCHING) before surfacing 409 so
          // the status change is not rolled back with the error.
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
            redispatchOrderId = order.order_id;
          }
          return { __offerExpired: true as const };
        }
        this.assertOfferAcceptable(offer, order);
        await this.assertRiderEligible(auth.profileId, tx);
        await this.assertRiderOnboardingComplete(auth.profileId, tx);
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
        const acceptedPayload = {
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
            resultPayload: acceptedPayload,
          },
          tx,
        );
        return acceptedPayload;
      });
      if (
        payload &&
        typeof payload === 'object' &&
        '__offerExpired' in payload &&
        (payload as { __offerExpired?: boolean }).__offerExpired
      ) {
        if (redispatchOrderId) {
          await this.redispatchSearchingQuietly(redispatchOrderId);
        }
        throw new ApiError(ErrorCodes.OFFER_EXPIRED, 'Offer has expired', 409);
      }
      return payload;
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
    const result = await this.postgres.transaction(async (tx) => {
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
    if (result.order?.canonical_status === 'SEARCHING') {
      await this.redispatchSearchingQuietly(result.order.order_id as string);
    }
    return result;
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
    if (input.to === 'PICKED_UP') {
      await this.settlement.onPickedUp(updated.order_id, tx);
    }
    if (input.to === 'DELIVERED') {
      await this.settlement.settleDelivered(updated, tx);
      // Trip Fare 85/15 freeze + wallet/COD sync (idempotent).
      await this.finance.captureOnDelivered(updated, tx);
    }
    if (input.to === 'CANCELLED') {
      await this.settlement.onCancelled(updated.order_id, tx);
    }
    return updated;
  }

  /** Expires pending offers past TTL and offers the next nearest rider. */
  private async releaseExpiredOffers(): Promise<void> {
    const cutoff = new Date(Date.now() - this.offerTtlMs());
    const expired = await this.orders.expirePendingOffersOlderThan(cutoff);
    const orderIds = [...new Set(expired.map((row) => row.order_id))];
    for (const orderId of orderIds) {
      let searching = false;
      try {
        searching = await this.postgres.transaction(async (tx) => {
          const order = await this.orders.lockById(orderId, tx);
          if (!order || order.canonical_status !== 'OFFERED') {
            return order?.canonical_status === 'SEARCHING';
          }
          const remaining = await this.orders.countPendingOffers(order.order_id, tx);
          if (remaining > 0) {
            return false;
          }
          await this.applyTransition(
            {
              order,
              to: 'SEARCHING',
              actor: 'SYSTEM',
              actorProfileId: null,
              reason: 'offer_expired',
              eventKey: `OFFERED->SEARCHING:expired:${order.order_id}`,
            },
            tx,
          );
          return true;
        });
      } catch {
        searching = false;
      }
      if (searching) {
        await this.redispatchSearchingQuietly(orderId);
      }
    }
  }

  /**
   * Confirm dispatches once. A rider who is online with the right vehicle
   * can still be missing a fresh GPS fix at that instant. The existing
   * customer order poll and rider offer poll call this so the same
   * nearest-rider rules run again after a location arrives.
   */
  private async retrySearchingDispatch(orderId: string): Promise<void> {
    try {
      await this.dispatchOffersForSearchingOrder(orderId);
    } catch {
      // Leave SEARCHING. The next poll can try again.
    }
  }

  /** Best-effort SYSTEM redispatch; never fails the caller path. */
  private async redispatchSearchingQuietly(orderId: string): Promise<void> {
    try {
      await this.dispatchOffersForSearchingOrder(orderId);
    } catch {
      // Leave SEARCHING; admin or a later retry can dispatch.
    }
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

  private async assertRiderOnboardingComplete(
    riderProfileId: string,
    db: Queryable,
  ): Promise<void> {
    const facts = await this.catalog.findRiderOnboardingFacts(riderProfileId, db);
    const missing = riderProfileGaps({
      name: facts?.name,
      email: facts?.email,
      dateOfBirth: facts?.date_of_birth,
      vehicleCategoryName: facts?.vehicle_category_name,
      vehicleRegistration: facts?.vehicle_registration,
      vehicleModel: facts?.vehicle_model,
      vehicleColor: facts?.vehicle_color,
      manufacturingYear: facts?.manufacturing_year,
      drivingLicence: facts?.driving_licence,
    });
    if (!facts || missing.length > 0) {
      throw new ApiError(
        ErrorCodes.RIDER_NOT_ELIGIBLE,
        'Complete your rider profile before accepting orders',
        409,
      );
    }
  }

  private async validateStops(
    stops: CreateOrderStopDto[],
    cityId: string,
    db: Queryable,
    options?: { requireDropContact?: boolean },
  ): Promise<CreateOrderStopDto[]> {
    const requireDropContact = options?.requireDropContact !== false;
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
      if (stop.stop_type === 'DROP' && requireDropContact) {
        assertDropContact({
          contactName: stop.contact_name,
          contactPhone: stop.contact_phone,
        });
        const normalized = normalizeContactPhone(stop.contact_phone);
        stop.contact_name = (stop.contact_name ?? '').trim();
        stop.contact_phone = normalized ?? stop.contact_phone;
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
    if (!category || !isCustomerBookableVehicle(category)) {
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
      crn: order.crn ?? null,
      customer_profile_id: order.customer_profile_id,
      rider_profile_id: order.rider_profile_id,
      city_id: order.city_id,
      city_code: order.city_code,
      vehicle_category_id: order.vehicle_category_id,
      vehicle_category_name: order.vehicle_category_name_snapshot,
      canonical_status: order.canonical_status,
      package_weight_kg: order.package_weight_kg,
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
      distance_km: extra?.distance_km ?? null,
      base_fare: extra?.base_fare ?? null,
      per_km: extra?.per_km ?? null,
      distance_charge: extra?.distance_charge ?? null,
      waiting: extra?.waiting ?? null,
      pickup_waiting_amount: extra?.pickup_waiting_amount ?? null,
      pickup_waiting_status: extra?.pickup_waiting_status ?? null,
      receivable_outstanding: extra?.receivable_outstanding ?? null,
      surge: extra?.surge ?? null,
      toll: extra?.toll ?? null,
      parking: extra?.parking ?? null,
      discount: extra?.discount ?? null,
      fare_rider_percentage: extra?.fare_rider_percentage ?? null,
      fare_company_commission_percentage:
        extra?.fare_company_commission_percentage ?? null,
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
      proof_file_id: stop.proof_file_id,
    };
  }

  async getByCrn(auth: OrderActor, crn: string) {
    if (!/^IU-CRN-[A-Z]{2,5}-[0-9]{10}$/.test(crn)) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    const order = await this.orders.findByCrn(crn);
    if (!order) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    return this.getById(auth, order.order_id);
  }

  async rateDriver(auth: OrderActor, orderId: string, stars: number, comment?: string) {
    this.assertCustomer(auth);
    const trimmed = comment?.trim() ?? '';
    return this.postgres.transaction(async (tx) => {
      const order = await this.orders.lockById(orderId, tx);
      if (!order || order.customer_profile_id !== auth.profileId) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      if (order.canonical_status !== 'DELIVERED') {
        throw new ApiError(
          ErrorCodes.ORDER_NOT_MODIFIABLE,
          'Only a completed order can be rated',
          409,
        );
      }
      if (!order.rider_profile_id) {
        throw new ApiError(
          ErrorCodes.ORDER_NOT_MODIFIABLE,
          'This order has no assigned rider to rate',
          409,
        );
      }
      const existing = await this.orders.findCustomerRating(order.order_id, tx);
      if (existing) {
        throw new ApiError(
          ErrorCodes.ORDER_NOT_MODIFIABLE,
          'This order has already been rated',
          409,
        );
      }
      try {
        const row = await this.orders.insertCustomerRating(
          {
            orderId: order.order_id,
            customerProfileId: auth.profileId,
            riderProfileId: order.rider_profile_id,
            stars,
            comment: trimmed.length > 0 ? trimmed : null,
          },
          tx,
        );
        return {
          order_id: order.order_id,
          crn: order.crn ?? null,
          stars,
          comment: trimmed.length > 0 ? trimmed : null,
          created_at: row.created_at.toISOString(),
        };
      } catch (err) {
        if (isUniqueViolation(err, 'order_ratings_direction_unique')) {
          throw new ApiError(
            ErrorCodes.ORDER_NOT_MODIFIABLE,
            'This order has already been rated',
            409,
          );
        }
        throw err;
      }
    });
  }

  async riderRatings(auth: OrderActor) {
    this.assertRider(auth);
    const summary = await this.orders.riderRatingSummary(auth.profileId);
    return {
      rating_count: summary.rating_count,
      rating_average: summary.rating_average,
      ratings: summary.ratings.map((row) => ({
        order_id: row.order_id,
        display_id: row.display_id,
        crn: row.crn,
        stars: row.stars,
        comment: row.comment,
        created_at: row.created_at.toISOString(),
      })),
    };
  }

  private serializeRating(
    rating:
      | { stars: number; comment: string | null; created_at: Date }
      | undefined
      | null,
  ) {
    if (!rating) {
      return null;
    }
    return {
      stars: rating.stars,
      comment: rating.comment,
      created_at: rating.created_at.toISOString(),
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


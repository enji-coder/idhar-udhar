import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { TransitionActor } from './order-status';
import { OrderStatus } from './order-status';

export type OrderRow = {
  order_id: string;
  display_id: string;
  customer_profile_id: string;
  rider_profile_id: string | null;
  city_id: string;
  city_code: string;
  vehicle_category_id: string;
  vehicle_category_name_snapshot: string;
  vehicle_id: string | null;
  canonical_status: OrderStatus;
  parent_order_id: string | null;
  scheduled_at: Date | null;
  created_at: Date;
  updated_at: Date;
};

export type OrderStopRow = {
  order_stop_id: string;
  order_id: string;
  sequence: number;
  stop_type: 'PICKUP' | 'DROP';
  address_text: string;
  latitude: string;
  longitude: string;
  zone_id: string | null;
  contact_name: string | null;
  contact_phone: string | null;
  arrived_at: Date | null;
  completed_at: Date | null;
};

export type OrderOfferRow = {
  order_offer_id: string;
  order_id: string;
  rider_profile_id: string;
  status: 'PENDING' | 'REJECTED' | 'EXPIRED' | 'ACCEPTED';
  created_at: Date;
  responded_at: Date | null;
};

export type InsertStopInput = {
  sequence: number;
  stop_type: 'PICKUP' | 'DROP';
  address_text: string;
  latitude: number;
  longitude: number;
  zone_id?: string;
  contact_name?: string;
  contact_phone?: string;
};

const ORDER_SELECT = `
  o.order_id,
  o.display_id,
  o.customer_profile_id,
  o.rider_profile_id,
  o.city_id,
  c.city_code,
  o.vehicle_category_id,
  o.vehicle_category_name_snapshot,
  o.vehicle_id,
  o.canonical_status,
  o.parent_order_id,
  o.scheduled_at,
  o.created_at,
  o.updated_at
`;

@Injectable()
export class OrdersRepository {
  constructor(private readonly postgres: PostgresService) {}

  async allocateDisplayId(cityId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ display_id: string }>(
      `SELECT allocate_order_display_id($1::uuid) AS display_id`,
      [cityId],
    );
    return result.rows[0].display_id;
  }

  async insertOrder(
    input: {
      displayId: string;
      customerProfileId: string;
      cityId: string;
      cityCode: string;
      vehicleCategoryId: string;
      vehicleCategoryName: string;
    },
    db: Queryable,
  ): Promise<OrderRow> {
    const result = await db.query<OrderRow>(
      `
      INSERT INTO orders (
        display_id,
        customer_profile_id,
        city_id,
        vehicle_category_id,
        vehicle_category_name_snapshot,
        canonical_status
      )
      VALUES ($1, $2, $3, $4, $5, 'CREATED')
      RETURNING
        order_id,
        display_id,
        customer_profile_id,
        rider_profile_id,
        city_id,
        $6::text AS city_code,
        vehicle_category_id,
        vehicle_category_name_snapshot,
        vehicle_id,
        canonical_status,
        parent_order_id,
        scheduled_at,
        created_at,
        updated_at
      `,
      [
        input.displayId,
        input.customerProfileId,
        input.cityId,
        input.vehicleCategoryId,
        input.vehicleCategoryName,
        input.cityCode,
      ],
    );
    return result.rows[0];
  }

  async insertStops(
    orderId: string,
    stops: InsertStopInput[],
    db: Queryable,
  ): Promise<OrderStopRow[]> {
    const rows: OrderStopRow[] = [];
    for (const stop of stops) {
      const result = await db.query<OrderStopRow>(
        `
        INSERT INTO order_stops (
          order_id, sequence, stop_type, address_text,
          latitude, longitude, zone_id, contact_name, contact_phone
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING
          order_stop_id,
          order_id,
          sequence,
          stop_type,
          address_text,
          latitude::text AS latitude,
          longitude::text AS longitude,
          zone_id,
          contact_name,
          contact_phone,
          arrived_at,
          completed_at
        `,
        [
          orderId,
          stop.sequence,
          stop.stop_type,
          stop.address_text,
          stop.latitude,
          stop.longitude,
          stop.zone_id ?? null,
          stop.contact_name ?? null,
          stop.contact_phone ?? null,
        ],
      );
      rows.push(result.rows[0]);
    }
    return rows;
  }

  async insertStatusEvent(
    input: {
      orderId: string;
      fromStatus: OrderStatus | null;
      toStatus: OrderStatus;
      actorType: TransitionActor;
      actorProfileId: string | null;
      reason: string | null;
      idempotencyKey: string;
    },
    db: Queryable,
  ): Promise<void> {
    await db.query(
      `
      INSERT INTO order_status_events (
        order_id, from_status, to_status, actor_type,
        actor_profile_id, reason, idempotency_key
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (order_id, idempotency_key) DO NOTHING
      `,
      [
        input.orderId,
        input.fromStatus,
        input.toStatus,
        input.actorType,
        input.actorProfileId,
        input.reason,
        input.idempotencyKey,
      ],
    );
  }

  async findById(
    orderId: string,
    db: Queryable = this.postgres,
  ): Promise<OrderRow | null> {
    const result = await db.query<OrderRow>(
      `
      SELECT ${ORDER_SELECT}
      FROM orders o
      JOIN cities c ON c.city_id = o.city_id
      WHERE o.order_id = $1
      `,
      [orderId],
    );
    return result.rows[0] ?? null;
  }

  async lockById(orderId: string, db: Queryable): Promise<OrderRow | null> {
    const result = await db.query<OrderRow>(
      `
      SELECT ${ORDER_SELECT}
      FROM orders o
      JOIN cities c ON c.city_id = o.city_id
      WHERE o.order_id = $1
      FOR UPDATE OF o
      `,
      [orderId],
    );
    return result.rows[0] ?? null;
  }

  async listForCustomer(
    customerProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<OrderRow[]> {
    const result = await db.query<OrderRow>(
      `
      SELECT ${ORDER_SELECT}
      FROM orders o
      JOIN cities c ON c.city_id = o.city_id
      WHERE o.customer_profile_id = $1
      ORDER BY o.created_at DESC
      LIMIT 50
      `,
      [customerProfileId],
    );
    return result.rows;
  }

  async listAll(db: Queryable = this.postgres): Promise<OrderRow[]> {
    const result = await db.query<OrderRow>(
      `
      SELECT ${ORDER_SELECT}
      FROM orders o
      JOIN cities c ON c.city_id = o.city_id
      ORDER BY o.created_at DESC
      LIMIT 100
      `,
    );
    return result.rows;
  }

  async listAdminExtras(
    orderIds: string[],
    db: Queryable = this.postgres,
  ): Promise<
    {
      order_id: string;
      customer_display_name: string;
      customer_phone: string;
      rider_phone: string | null;
      pickup_address: string | null;
      drop_address: string | null;
      trip_fare: string | null;
      net_payable: string | null;
      rider_amount: string | null;
      company_commission_amount: string | null;
      operational_cost_amount: string | null;
      profit_amount: string | null;
      rider_percentage: string | null;
      company_commission_percentage: string | null;
      operational_cost_percentage_of_commission: string | null;
    }[]
  > {
    if (orderIds.length === 0) {
      return [];
    }
    const result = await db.query<{
      order_id: string;
      customer_display_name: string;
      customer_phone: string;
      rider_phone: string | null;
      pickup_address: string | null;
      drop_address: string | null;
      trip_fare: string | null;
      net_payable: string | null;
      rider_amount: string | null;
      company_commission_amount: string | null;
      operational_cost_amount: string | null;
      profit_amount: string | null;
      rider_percentage: string | null;
      company_commission_percentage: string | null;
      operational_cost_percentage_of_commission: string | null;
    }>(
      `
      SELECT
        o.order_id,
        cp.display_name AS customer_display_name,
        ic.phone_normalized AS customer_phone,
        ir.phone_normalized AS rider_phone,
        pickup.address_text AS pickup_address,
        drop_stop.address_text AS drop_address,
        snap.trip_fare::text AS trip_fare,
        snap.net_payable::text AS net_payable,
        fin.rider_amount::text AS rider_amount,
        fin.company_commission_amount::text AS company_commission_amount,
        fin.operational_cost_amount::text AS operational_cost_amount,
        fin.profit_amount::text AS profit_amount,
        fin.rider_percentage::text AS rider_percentage,
        fin.company_commission_percentage::text AS company_commission_percentage,
        fin.operational_cost_percentage_of_commission::text AS operational_cost_percentage_of_commission
      FROM orders o
      JOIN customer_profiles cp ON cp.customer_profile_id = o.customer_profile_id
      JOIN identities ic ON ic.identity_id = cp.identity_id
      LEFT JOIN rider_profiles rp ON rp.rider_profile_id = o.rider_profile_id
      LEFT JOIN identities ir ON ir.identity_id = rp.identity_id
      LEFT JOIN LATERAL (
        SELECT address_text
        FROM order_stops
        WHERE order_id = o.order_id AND stop_type = 'PICKUP'
        ORDER BY sequence ASC
        LIMIT 1
      ) pickup ON TRUE
      LEFT JOIN LATERAL (
        SELECT address_text
        FROM order_stops
        WHERE order_id = o.order_id AND stop_type = 'DROP'
        ORDER BY sequence DESC
        LIMIT 1
      ) drop_stop ON TRUE
      LEFT JOIN order_fare_snapshots snap ON snap.order_id = o.order_id
      LEFT JOIN LATERAL (
        SELECT
          rider_amount,
          company_commission_amount,
          operational_cost_amount,
          profit_amount,
          rider_percentage,
          company_commission_percentage,
          operational_cost_percentage_of_commission
        FROM order_finance_snapshots
        WHERE order_id = o.order_id AND snapshot_kind = 'ORIGINAL'
        ORDER BY frozen_at DESC
        LIMIT 1
      ) fin ON TRUE
      WHERE o.order_id = ANY($1::uuid[])
      `,
      [orderIds],
    );
    return result.rows;
  }

  async listStops(
    orderId: string,
    db: Queryable = this.postgres,
  ): Promise<OrderStopRow[]> {
    const result = await db.query<OrderStopRow>(
      `
      SELECT
        order_stop_id,
        order_id,
        sequence,
        stop_type,
        address_text,
        latitude::text AS latitude,
        longitude::text AS longitude,
        zone_id,
        contact_name,
        contact_phone,
        arrived_at,
        completed_at
      FROM order_stops
      WHERE order_id = $1
      ORDER BY sequence ASC
      `,
      [orderId],
    );
    return result.rows;
  }

  async compareAndSetStatus(
    input: {
      orderId: string;
      fromStatus: OrderStatus;
      toStatus: OrderStatus;
      riderProfileId?: string | null;
    },
    db: Queryable,
  ): Promise<OrderRow | null> {
    const result = await db.query<OrderRow>(
      `
      UPDATE orders AS o
      SET
        canonical_status = $3,
        rider_profile_id = COALESCE($4, o.rider_profile_id)
      WHERE o.order_id = $1
        AND o.canonical_status = $2
      RETURNING
        o.order_id,
        o.display_id,
        o.customer_profile_id,
        o.rider_profile_id,
        o.city_id,
        (SELECT city_code FROM cities WHERE city_id = o.city_id) AS city_code,
        o.vehicle_category_id,
        o.vehicle_category_name_snapshot,
        o.vehicle_id,
        o.canonical_status,
        o.parent_order_id,
        o.scheduled_at,
        o.created_at,
        o.updated_at
      `,
      [
        input.orderId,
        input.fromStatus,
        input.toStatus,
        input.riderProfileId === undefined ? null : input.riderProfileId,
      ],
    );
    return result.rows[0] ?? null;
  }

  async insertOffer(
    input: { orderId: string; riderProfileId: string },
    db: Queryable,
  ): Promise<OrderOfferRow> {
    const result = await db.query<OrderOfferRow>(
      `
      INSERT INTO order_offers (order_id, rider_profile_id, status)
      VALUES ($1, $2, 'PENDING')
      RETURNING
        order_offer_id,
        order_id,
        rider_profile_id,
        status,
        created_at,
        responded_at
      `,
      [input.orderId, input.riderProfileId],
    );
    return result.rows[0];
  }

  async findOffer(
    offerId: string,
    db: Queryable = this.postgres,
  ): Promise<OrderOfferRow | null> {
    const result = await db.query<OrderOfferRow>(
      `
      SELECT
        order_offer_id,
        order_id,
        rider_profile_id,
        status,
        created_at,
        responded_at
      FROM order_offers
      WHERE order_offer_id = $1
      `,
      [offerId],
    );
    return result.rows[0] ?? null;
  }

  async lockOffer(offerId: string, db: Queryable): Promise<OrderOfferRow | null> {
    const result = await db.query<OrderOfferRow>(
      `
      SELECT
        order_offer_id,
        order_id,
        rider_profile_id,
        status,
        created_at,
        responded_at
      FROM order_offers
      WHERE order_offer_id = $1
      FOR UPDATE
      `,
      [offerId],
    );
    return result.rows[0] ?? null;
  }

  async listOffersForRider(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<Array<OrderOfferRow & { display_id: string; canonical_status: OrderStatus }>> {
    const result = await db.query<
      OrderOfferRow & { display_id: string; canonical_status: OrderStatus }
    >(
      `
      SELECT
        off.order_offer_id,
        off.order_id,
        off.rider_profile_id,
        off.status,
        off.created_at,
        off.responded_at,
        o.display_id,
        o.canonical_status
      FROM order_offers off
      JOIN orders o ON o.order_id = off.order_id
      WHERE off.rider_profile_id = $1
      ORDER BY off.created_at DESC
      LIMIT 50
      `,
      [riderProfileId],
    );
    return result.rows;
  }

  async riderHasOffer(
    orderId: string,
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<boolean> {
    const result = await db.query<{ present: boolean }>(
      `
      SELECT EXISTS (
        SELECT 1
        FROM order_offers
        WHERE order_id = $1 AND rider_profile_id = $2
      ) AS present
      `,
      [orderId, riderProfileId],
    );
    return result.rows[0]?.present === true;
  }

  async updateOfferStatus(
    input: {
      offerId: string;
      fromStatus: OrderOfferRow['status'];
      toStatus: OrderOfferRow['status'];
    },
    db: Queryable,
  ): Promise<OrderOfferRow | null> {
    const result = await db.query<OrderOfferRow>(
      `
      UPDATE order_offers
      SET
        status = $3,
        responded_at = CASE
          WHEN $3 IN ('ACCEPTED', 'REJECTED', 'EXPIRED') THEN now()
          ELSE responded_at
        END
      WHERE order_offer_id = $1
        AND status = $2
      RETURNING
        order_offer_id,
        order_id,
        rider_profile_id,
        status,
        created_at,
        responded_at
      `,
      [input.offerId, input.fromStatus, input.toStatus],
    );
    return result.rows[0] ?? null;
  }

  async expireOtherPendingOffers(
    orderId: string,
    exceptOfferId: string,
    db: Queryable,
  ): Promise<{ order_offer_id: string; rider_profile_id: string }[]> {
    const result = await db.query<{
      order_offer_id: string;
      rider_profile_id: string;
    }>(
      `
      UPDATE order_offers
      SET status = 'EXPIRED', responded_at = now()
      WHERE order_id = $1
        AND order_offer_id <> $2
        AND status = 'PENDING'
      RETURNING order_offer_id, rider_profile_id
      `,
      [orderId, exceptOfferId],
    );
    return result.rows;
  }

  async expireAllPendingOffers(
    orderId: string,
    db: Queryable,
  ): Promise<{ order_offer_id: string; rider_profile_id: string }[]> {
    const result = await db.query<{
      order_offer_id: string;
      rider_profile_id: string;
    }>(
      `
      UPDATE order_offers
      SET status = 'EXPIRED', responded_at = now()
      WHERE order_id = $1
        AND status = 'PENDING'
      RETURNING order_offer_id, rider_profile_id
      `,
      [orderId],
    );
    return result.rows;
  }

  async countPendingOffers(orderId: string, db: Queryable): Promise<number> {
    const result = await db.query<{ count: string }>(
      `
      SELECT count(*)::text AS count
      FROM order_offers
      WHERE order_id = $1 AND status = 'PENDING'
      `,
      [orderId],
    );
    return Number.parseInt(result.rows[0].count, 10);
  }

  async riderHasLiveOrder(
    riderProfileId: string,
    db: Queryable,
  ): Promise<boolean> {
    const result = await db.query<{ present: boolean }>(
      `
      SELECT EXISTS (
        SELECT 1
        FROM orders
        WHERE rider_profile_id = $1
          AND canonical_status NOT IN ('DELIVERED', 'CANCELLED', 'RESEND_COMPLETED')
      ) AS present
      `,
      [riderProfileId],
    );
    return result.rows[0]?.present === true;
  }
}

import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { formatInr, formatKm } from '../fare/money';
import { OrderStatus } from '../orders/order-status';

export type FareQuoteRow = {
  fare_quote_id: string;
  customer_profile_id: string;
  fare_config_version_id: string;
  vehicle_category_id: string;
  distance_km: string;
  stop_count: number;
  base_fare: string;
  per_km: string;
  distance_charge: string;
  initial_minimum: string;
  waiting: string;
  surge: string;
  toll: string;
  parking: string;
  trip_fare: string;
  discount: string;
  rounding: string;
  net_payable: string;
  tax: string;
  expires_at: Date;
  created_at: Date;
};

export type FareSnapshotRow = {
  fare_snapshot_id: string;
  order_id: string;
  fare_config_version_id: string;
  vehicle_category_id: string;
  vehicle_category_name: string;
  distance_km: string;
  stop_count: number;
  base_fare: string;
  per_km: string;
  distance_charge: string;
  initial_minimum: string;
  waiting: string;
  surge: string;
  toll: string;
  parking: string;
  trip_fare: string;
  discount: string;
  rounding: string;
  net_payable: string;
  tax: string;
  quoted_at: Date | null;
  confirmed_at: Date;
};

const QUOTE_COLUMNS = `
  fare_quote_id,
  customer_profile_id,
  fare_config_version_id,
  vehicle_category_id,
  distance_km::text AS distance_km,
  stop_count,
  base_fare::text AS base_fare,
  per_km::text AS per_km,
  distance_charge::text AS distance_charge,
  initial_minimum::text AS initial_minimum,
  waiting::text AS waiting,
  surge::text AS surge,
  toll::text AS toll,
  parking::text AS parking,
  trip_fare::text AS trip_fare,
  discount::text AS discount,
  rounding::text AS rounding,
  net_payable::text AS net_payable,
  tax::text AS tax,
  expires_at,
  created_at
`;

@Injectable()
export class FareRepository {
  constructor(private readonly postgres: PostgresService) {}

  async insertQuoteFromActiveConfig(
    input: {
      customerProfileId: string;
      vehicleCategoryId: string;
      distanceKm: string;
      stopCount: number;
      ttlSeconds: number;
    },
    db: Queryable,
  ): Promise<FareQuoteRow | null> {
    const result = await db.query<FareQuoteRow>(
      `
      WITH rates AS (
        SELECT
          v.fare_config_version_id,
          r.vehicle_category_id,
          r.base_fare,
          r.per_km,
          ROUND(r.per_km * $3::numeric(10,3), 2) AS distance_charge,
          r.initial_minimum,
          r.waiting,
          r.surge,
          r.toll,
          r.parking
        FROM fare_config_versions v
        JOIN fare_config_version_rates r
          ON r.fare_config_version_id = v.fare_config_version_id
        WHERE v.status = 'ACTIVE'
          AND r.vehicle_category_id = $2
      ),
      calc AS (
        SELECT
          fare_config_version_id,
          vehicle_category_id,
          base_fare,
          per_km,
          distance_charge,
          initial_minimum,
          waiting,
          surge,
          toll,
          parking,
          GREATEST(
            initial_minimum,
            ROUND(
              base_fare + distance_charge + waiting + surge + toll + parking,
              2
            )
          ) AS trip_fare
        FROM rates
      )
      INSERT INTO fare_quotes (
        customer_profile_id,
        fare_config_version_id,
        vehicle_category_id,
        distance_km,
        stop_count,
        base_fare,
        per_km,
        distance_charge,
        initial_minimum,
        waiting,
        surge,
        toll,
        parking,
        trip_fare,
        discount,
        rounding,
        net_payable,
        tax,
        expires_at
      )
      SELECT
        $1,
        fare_config_version_id,
        vehicle_category_id,
        $3::numeric(10,3),
        $4,
        base_fare,
        per_km,
        distance_charge,
        initial_minimum,
        waiting,
        surge,
        toll,
        parking,
        trip_fare,
        0,
        ROUND(trip_fare, 2) - trip_fare,
        ROUND(trip_fare, 2),
        0,
        now() + ($5::text || ' seconds')::interval
      FROM calc
      RETURNING ${QUOTE_COLUMNS}
      `,
      [
        input.customerProfileId,
        input.vehicleCategoryId,
        input.distanceKm,
        input.stopCount,
        input.ttlSeconds,
      ],
    );
    return result.rows[0] ?? null;
  }

  async findQuote(
    fareQuoteId: string,
    db: Queryable = this.postgres,
  ): Promise<FareQuoteRow | null> {
    const result = await db.query<FareQuoteRow>(
      `
      SELECT ${QUOTE_COLUMNS}
      FROM fare_quotes
      WHERE fare_quote_id = $1
      `,
      [fareQuoteId],
    );
    return result.rows[0] ?? null;
  }

  async insertSnapshotFromQuote(
    input: {
      orderId: string;
      quoteId: string;
      vehicleCategoryName: string;
    },
    db: Queryable,
  ): Promise<FareSnapshotRow> {
    const result = await db.query<FareSnapshotRow>(
      `
      INSERT INTO order_fare_snapshots (
        order_id,
        fare_config_version_id,
        vehicle_category_id,
        vehicle_category_name,
        distance_km,
        stop_count,
        base_fare,
        per_km,
        distance_charge,
        initial_minimum,
        waiting,
        surge,
        toll,
        parking,
        trip_fare,
        discount,
        rounding,
        net_payable,
        tax,
        quoted_at
      )
      SELECT
        $1,
        fare_config_version_id,
        vehicle_category_id,
        $3,
        distance_km,
        stop_count,
        base_fare,
        per_km,
        distance_charge,
        initial_minimum,
        waiting,
        surge,
        toll,
        parking,
        trip_fare,
        discount,
        rounding,
        net_payable,
        tax,
        created_at
      FROM fare_quotes
      WHERE fare_quote_id = $2
      RETURNING
        fare_snapshot_id,
        order_id,
        fare_config_version_id,
        vehicle_category_id,
        vehicle_category_name,
        distance_km::text AS distance_km,
        stop_count,
        base_fare::text AS base_fare,
        per_km::text AS per_km,
        distance_charge::text AS distance_charge,
        initial_minimum::text AS initial_minimum,
        waiting::text AS waiting,
        surge::text AS surge,
        toll::text AS toll,
        parking::text AS parking,
        trip_fare::text AS trip_fare,
        discount::text AS discount,
        rounding::text AS rounding,
        net_payable::text AS net_payable,
        tax::text AS tax,
        quoted_at,
        confirmed_at
      `,
      [input.orderId, input.quoteId, input.vehicleCategoryName],
    );
    return result.rows[0];
  }

  async findSnapshotByOrder(
    orderId: string,
    db: Queryable = this.postgres,
  ): Promise<FareSnapshotRow | null> {
    const result = await db.query<FareSnapshotRow>(
      `
      SELECT
        fare_snapshot_id,
        order_id,
        fare_config_version_id,
        vehicle_category_id,
        vehicle_category_name,
        distance_km::text AS distance_km,
        stop_count,
        base_fare::text AS base_fare,
        per_km::text AS per_km,
        distance_charge::text AS distance_charge,
        initial_minimum::text AS initial_minimum,
        waiting::text AS waiting,
        surge::text AS surge,
        toll::text AS toll,
        parking::text AS parking,
        trip_fare::text AS trip_fare,
        discount::text AS discount,
        rounding::text AS rounding,
        net_payable::text AS net_payable,
        tax::text AS tax,
        quoted_at,
        confirmed_at
      FROM order_fare_snapshots
      WHERE order_id = $1
      `,
      [orderId],
    );
    return result.rows[0] ?? null;
  }
}

export function serializeQuote(row: FareQuoteRow) {
  return {
    fare_quote_id: row.fare_quote_id,
    customer_profile_id: row.customer_profile_id,
    fare_config_version_id: row.fare_config_version_id,
    vehicle_category_id: row.vehicle_category_id,
    distance_km: formatKm(row.distance_km),
    stop_count: row.stop_count,
    base_fare: formatInr(row.base_fare),
    per_km: formatInr(row.per_km),
    distance_charge: formatInr(row.distance_charge),
    initial_minimum: formatInr(row.initial_minimum),
    waiting: formatInr(row.waiting),
    surge: formatInr(row.surge),
    toll: formatInr(row.toll),
    parking: formatInr(row.parking),
    trip_fare: formatInr(row.trip_fare),
    discount: formatInr(row.discount),
    rounding: formatInr(row.rounding),
    net_payable: formatInr(row.net_payable),
    tax: formatInr(row.tax),
    expires_at: row.expires_at.toISOString(),
    created_at: row.created_at.toISOString(),
  };
}

export function serializeSnapshot(row: FareSnapshotRow) {
  return {
    fare_snapshot_id: row.fare_snapshot_id,
    order_id: row.order_id,
    fare_config_version_id: row.fare_config_version_id,
    vehicle_category_id: row.vehicle_category_id,
    vehicle_category_name: row.vehicle_category_name,
    distance_km: formatKm(row.distance_km),
    stop_count: row.stop_count,
    base_fare: formatInr(row.base_fare),
    per_km: formatInr(row.per_km),
    distance_charge: formatInr(row.distance_charge),
    initial_minimum: formatInr(row.initial_minimum),
    waiting: formatInr(row.waiting),
    surge: formatInr(row.surge),
    toll: formatInr(row.toll),
    parking: formatInr(row.parking),
    trip_fare: formatInr(row.trip_fare),
    discount: formatInr(row.discount),
    rounding: formatInr(row.rounding),
    net_payable: formatInr(row.net_payable),
    tax: formatInr(row.tax),
    quoted_at: row.quoted_at ? row.quoted_at.toISOString() : null,
    confirmed_at: row.confirmed_at.toISOString(),
  };
}

export type { OrderStatus };

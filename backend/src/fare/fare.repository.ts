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
  rider_percentage: string;
  company_commission_percentage: string;
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
  rider_percentage: string;
  company_commission_percentage: string;
  rider_amount: string;
  quoted_at: Date | null;
  confirmed_at: Date;
};

const TRIP_FARE_SQL = `GREATEST(
  initial_minimum,
  ROUND(
    base_fare + distance_charge + waiting + surge + toll + parking,
    2
  )
)`;

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
  rider_percentage::text AS rider_percentage,
  company_commission_percentage::text AS company_commission_percentage,
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
          r.parking,
          r.rider_percentage,
          r.company_commission_percentage
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
          rider_percentage,
          company_commission_percentage,
          ${TRIP_FARE_SQL} AS trip_fare
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
        rider_percentage,
        company_commission_percentage,
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
        rider_percentage,
        company_commission_percentage,
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
        rider_percentage,
        company_commission_percentage,
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
        rider_percentage,
        company_commission_percentage,
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
        rider_percentage::text AS rider_percentage,
        company_commission_percentage::text AS company_commission_percentage,
        ROUND(trip_fare * rider_percentage / 100, 2)::text AS rider_amount,
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
        rider_percentage::text AS rider_percentage,
        company_commission_percentage::text AS company_commission_percentage,
        ROUND(trip_fare * rider_percentage / 100, 2)::text AS rider_amount,
        quoted_at,
        confirmed_at
      FROM order_fare_snapshots
      WHERE order_id = $1
      `,
      [orderId],
    );
    return result.rows[0] ?? null;
  }

  /**
   * Same active-version formula as insertQuoteFromActiveConfig, without writing a quote.
   * One distance prices every active canonical vehicle from its own rate row.
   */
  async previewActiveVehicleFares(
    distanceKm: string,
    db: Queryable = this.postgres,
  ): Promise<
    Array<{
      vehicle_category_id: string;
      name: string;
      vehicle_type: string | null;
      vehicle: string | null;
      active: boolean;
      weight_capacity: string | null;
      size: string | null;
      fare_config_version_id: string;
      base_fare: string;
      distance_charge: string;
      waiting: string;
      surge: string;
      toll: string;
      parking: string;
      trip_fare: string;
      discount: string;
      rounding: string;
      net_payable: string;
      tax: string;
    }>
  > {
    const result = await db.query<{
      vehicle_category_id: string;
      name: string;
      vehicle_type: string | null;
      vehicle: string | null;
      active: boolean;
      weight_capacity: string | null;
      size: string | null;
      fare_config_version_id: string;
      base_fare: string;
      distance_charge: string;
      waiting: string;
      surge: string;
      toll: string;
      parking: string;
      trip_fare: string;
      discount: string;
      rounding: string;
      net_payable: string;
      tax: string;
    }>(
      `
      WITH rates AS (
        SELECT
          v.fare_config_version_id,
          c.vehicle_category_id,
          c.name,
          c.vehicle_type,
          c.vehicle,
          c.active,
          c.weight_capacity,
          c.size,
          r.base_fare,
          ROUND(r.per_km * $1::numeric(10,3), 2) AS distance_charge,
          r.initial_minimum,
          r.waiting,
          r.surge,
          r.toll,
          r.parking
        FROM vehicle_categories c
        JOIN fare_config_versions v
          ON v.status = 'ACTIVE'
        JOIN fare_config_version_rates r
          ON r.fare_config_version_id = v.fare_config_version_id
         AND r.vehicle_category_id = c.vehicle_category_id
        WHERE c.active = TRUE
          AND c.vehicle_type IS NOT NULL
          AND c.vehicle IS NOT NULL
      ),
      calc AS (
        SELECT
          fare_config_version_id,
          vehicle_category_id,
          name,
          vehicle_type,
          vehicle,
          active,
          weight_capacity,
          size,
          base_fare,
          distance_charge,
          initial_minimum,
          waiting,
          surge,
          toll,
          parking,
          ${TRIP_FARE_SQL} AS trip_fare
        FROM rates
      )
      SELECT
        vehicle_category_id,
        name,
        vehicle_type,
        vehicle,
        active,
        weight_capacity,
        size,
        fare_config_version_id,
        base_fare::money_inr::text AS base_fare,
        distance_charge::money_inr::text AS distance_charge,
        waiting::money_inr::text AS waiting,
        surge::money_inr::text AS surge,
        toll::money_inr::text AS toll,
        parking::money_inr::text AS parking,
        trip_fare::money_inr::text AS trip_fare,
        '0.00'::text AS discount,
        (ROUND(trip_fare, 2) - trip_fare)::money_inr::text AS rounding,
        ROUND(trip_fare, 2)::money_inr::text AS net_payable,
        '0.00'::text AS tax
      FROM calc
      ORDER BY vehicle_type ASC, name ASC
      `,
      [distanceKm],
    );
    return result.rows;
  }

  /** Recalculate trip fare from the quote's fare version and the routed distance. */
  async tripFareForVersion(
    input: {
      fareConfigVersionId: string;
      vehicleCategoryId: string;
      distanceKm: string;
    },
    db: Queryable = this.postgres,
  ): Promise<string | null> {
    const result = await db.query<{ trip_fare: string }>(
      `
      WITH rates AS (
        SELECT
          r.base_fare,
          ROUND(r.per_km * $3::numeric(10,3), 2) AS distance_charge,
          r.initial_minimum,
          r.waiting,
          r.surge,
          r.toll,
          r.parking
        FROM fare_config_version_rates r
        WHERE r.fare_config_version_id = $1
          AND r.vehicle_category_id = $2
      )
      SELECT ${TRIP_FARE_SQL}::money_inr::text AS trip_fare
      FROM rates
      `,
      [input.fareConfigVersionId, input.vehicleCategoryId, input.distanceKm],
    );
    return result.rows[0]?.trip_fare ?? null;
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

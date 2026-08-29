import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import {
  isForeignKeyViolation,
  isRestrictViolation,
} from '../common/pg-error';
import { AuthContext } from '../auth/types/auth-context';
import { PostgresService } from '../database/postgres.service';
import {
  fareRatesHaveAmount,
  normalizeFareRates,
} from './dto/fare-rates.dto';
import { CreateVehicleCategoryDto } from './dto/create-vehicle-category.dto';
import { UpdateVehicleCategoryDto } from './dto/update-vehicle-category.dto';
import { FarePublishRepository } from './fare-publish.repository';
import {
  CategoryUsage,
  VehicleCategoriesRepository,
  VehicleCategoryRow,
} from './vehicle-categories.repository';

@Injectable()
export class VehicleCategoriesService {
  constructor(
    private readonly categories: VehicleCategoriesRepository,
    private readonly fares: FarePublishRepository,
    private readonly postgres: PostgresService,
  ) {}

  async list(_auth: AuthContext) {
    const rows = await this.categories.list();
    const usage = await this.categories.usageByCategory();
    return {
      vehicle_categories: rows.map((row) =>
        this.serialize(row, usage.get(row.vehicle_category_id)),
      ),
    };
  }

  async get(_auth: AuthContext, id: string) {
    const row = await this.categories.findById(id);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Vehicle category was not found', 404);
    }
    const usage = await this.categories.usage(id);
    return this.serialize(row, usage);
  }

  async create(auth: AuthContext, body: CreateVehicleCategoryDto) {
    const name = body.name.replace(/\s+/g, ' ').trim();
    await this.assertNameAvailable(name, null);
    const active = body.active !== false;
    const code = this.normalizeCode(body.code);
    const created = await this.postgres.transaction(async (db) => {
      const inserted = await this.categories.insert(
        {
          name,
          code,
          active,
          weight_capacity: this.emptyToNull(body.weight_capacity),
          size: this.emptyToNull(body.size),
        },
        db,
      );
      if (fareRatesHaveAmount(body.rates)) {
        const rates = normalizeFareRates(body.rates);
        await this.fares.publishCategoryRates(
          {
            adminProfileId: auth.profileId,
            vehicleCategoryId: inserted.vehicle_category_id,
            ...rates,
          },
          db,
        );
      }
      return inserted.vehicle_category_id;
    });
    const row = await this.categories.findById(created);
    if (!row) {
      throw new ApiError(ErrorCodes.INTERNAL_ERROR, 'Vehicle category was not found after create', 500);
    }
    return this.serialize(row, await this.categories.usage(created));
  }

  async update(auth: AuthContext, id: string, body: UpdateVehicleCategoryDto) {
    const existing = await this.categories.findById(id);
    if (!existing) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Vehicle category was not found', 404);
    }
    const name = (body.name ?? existing.name).replace(/\s+/g, ' ').trim();
    await this.assertNameAvailable(name, id);
    const next = {
      name,
      code: body.code !== undefined ? this.normalizeCode(body.code) : existing.code,
      active: body.active ?? existing.active,
      weight_capacity:
        body.weight_capacity !== undefined
          ? this.emptyToNull(body.weight_capacity)
          : existing.weight_capacity,
      size: body.size !== undefined ? this.emptyToNull(body.size) : existing.size,
    };
    await this.postgres.transaction(async (db) => {
      await this.categories.update(id, next, db);
      if (body.rates && this.ratesChanged(existing, body.rates)) {
        const rates = normalizeFareRates(body.rates);
        await this.fares.publishCategoryRates(
          {
            adminProfileId: auth.profileId,
            vehicleCategoryId: id,
            ...rates,
          },
          db,
        );
      }
    });
    const row = await this.categories.findById(id);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Vehicle category was not found', 404);
    }
    return this.serialize(row, await this.categories.usage(id));
  }

  async remove(_auth: AuthContext, id: string) {
    const existing = await this.categories.findById(id);
    if (!existing) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Vehicle category was not found', 404);
    }
    const usage = await this.categories.usage(id);
    if (this.inUse(usage)) {
      throw this.inUseError(usage);
    }
    try {
      await this.categories.delete(id);
    } catch (err) {
      if (isForeignKeyViolation(err) || isRestrictViolation(err)) {
        throw this.inUseError(await this.categories.usage(id));
      }
      throw err;
    }
    return { deleted: true, vehicle_category_id: id };
  }

  private async assertNameAvailable(name: string, excludeId: string | null) {
    const taken = await this.categories.findByName(name, excludeId);
    if (taken) {
      throw new ApiError(
        ErrorCodes.VEHICLE_CATEGORY_NAME_TAKEN,
        'This vehicle category already exists.',
        409,
      );
    }
  }

  private inUseError(usage: CategoryUsage) {
    return new ApiError(
      ErrorCodes.VEHICLE_CATEGORY_IN_USE,
      'Cannot delete this vehicle category because it is already used by published fare data or other protected records. Please deactivate it instead.',
      409,
      usage,
    );
  }

  private inUse(usage: CategoryUsage): boolean {
    return (
      Number(usage.vehicles || 0) +
        Number(usage.orders || 0) +
        Number(usage.fare_quotes || 0) +
        Number(usage.fare_snapshots || 0) +
        Number(usage.fare_rates || 0) >
      0
    );
  }

  private ratesChanged(
    existing: VehicleCategoryRow,
    incoming: NonNullable<UpdateVehicleCategoryDto['rates']>,
  ): boolean {
    if (!fareRatesHaveAmount(incoming) && !existing.fare_config_version_id) {
      return false;
    }
    const next = normalizeFareRates(incoming);
    return (
      next.base_fare !== (existing.base_fare ?? '0.00') ||
      next.per_km !== (existing.per_km ?? '0.00') ||
      next.initial_minimum !== (existing.initial_minimum ?? '0.00') ||
      next.waiting !== (existing.waiting ?? '0.00') ||
      next.surge !== (existing.surge ?? '0.00') ||
      next.toll !== (existing.toll ?? '0.00') ||
      next.parking !== (existing.parking ?? '0.00')
    );
  }

  private normalizeCode(code?: string | null): string | null {
    const value = String(code || '').trim().toUpperCase();
    return value ? value : null;
  }

  private emptyToNull(value?: string | null): string | null {
    const trimmed = String(value ?? '').trim();
    return trimmed ? trimmed : null;
  }

  private serialize(row: VehicleCategoryRow, usage?: CategoryUsage) {
    return {
      vehicle_category_id: row.vehicle_category_id,
      code: row.code,
      name: row.name,
      active: row.active,
      weight_capacity: row.weight_capacity,
      size: row.size,
      created_at: row.created_at,
      updated_at: row.updated_at,
      fare_config_version_id: row.fare_config_version_id,
      rates: {
        base_fare: row.base_fare ?? '0.00',
        per_km: row.per_km ?? '0.00',
        initial_minimum: row.initial_minimum ?? '0.00',
        waiting: row.waiting ?? '0.00',
        surge: row.surge ?? '0.00',
        toll: row.toll ?? '0.00',
        parking: row.parking ?? '0.00',
      },
      usage: usage ?? null,
    };
  }
}

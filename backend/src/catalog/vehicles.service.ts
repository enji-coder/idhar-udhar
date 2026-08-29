import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AuthContext } from '../auth/types/auth-context';
import { CatalogRepository } from '../orders/catalog.repository';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';
import { VehicleRow, VehiclesRepository } from './vehicles.repository';

@Injectable()
export class VehiclesService {
  constructor(
    private readonly vehicles: VehiclesRepository,
    private readonly catalog: CatalogRepository,
  ) {}

  async list(_auth: AuthContext) {
    const rows = await this.vehicles.list();
    return { vehicles: rows.map((row) => this.serialize(row)) };
  }

  async get(_auth: AuthContext, id: string) {
    const row = await this.vehicles.findById(id);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Vehicle was not found', 404);
    }
    return this.serialize(row);
  }

  async create(_auth: AuthContext, body: CreateVehicleDto) {
    await this.assertCategory(body.vehicle_category_id);
    const registration = body.registration.replace(/\s+/g, ' ').trim();
    await this.assertRegistrationAvailable(registration, null);
    const inserted = await this.vehicles.insert({
      vehicleCategoryId: body.vehicle_category_id,
      riderProfileId: body.rider_profile_id ?? null,
      registration,
      twoWheelerSubtype: body.two_wheeler_subtype ?? null,
      active: body.active !== false,
    });
    const row = await this.vehicles.findById(inserted.vehicle_id);
    if (!row) {
      throw new ApiError(ErrorCodes.INTERNAL_ERROR, 'Vehicle was not found after create', 500);
    }
    return this.serialize(row);
  }

  async update(_auth: AuthContext, id: string, body: UpdateVehicleDto) {
    const existing = await this.vehicles.findById(id);
    if (!existing) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Vehicle was not found', 404);
    }
    const categoryId = body.vehicle_category_id ?? existing.vehicle_category_id;
    await this.assertCategory(categoryId);
    const registration = (body.registration ?? existing.registration ?? '')
      .replace(/\s+/g, ' ')
      .trim();
    if (!registration) {
      throw new ApiError(ErrorCodes.VALIDATION_ERROR, 'Vehicle registration is required', 400);
    }
    await this.assertRegistrationAvailable(registration, id);
    const rider =
      body.rider_profile_id === undefined
        ? existing.rider_profile_id
        : body.rider_profile_id;
    await this.vehicles.update(id, {
      vehicleCategoryId: categoryId,
      riderProfileId: rider,
      registration,
      twoWheelerSubtype:
        body.two_wheeler_subtype === undefined
          ? existing.two_wheeler_subtype
          : body.two_wheeler_subtype,
      active: body.active ?? existing.active,
    });
    const row = await this.vehicles.findById(id);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Vehicle was not found', 404);
    }
    return this.serialize(row);
  }

  async remove(_auth: AuthContext, id: string) {
    const existing = await this.vehicles.findById(id);
    if (!existing) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Vehicle was not found', 404);
    }
    if (existing.order_count > 0) {
      throw new ApiError(
        ErrorCodes.VEHICLE_IN_USE,
        'Cannot delete this vehicle because orders reference it. Please deactivate it instead.',
        409,
      );
    }
    await this.vehicles.delete(id);
    return { deleted: true, vehicle_id: id };
  }

  private async assertCategory(vehicleCategoryId: string) {
    const category = await this.catalog.findActiveVehicleCategory(vehicleCategoryId);
    if (!category) {
      throw new ApiError(
        ErrorCodes.VEHICLE_CATEGORY_INVALID,
        'Vehicle category was not found',
        400,
      );
    }
  }

  private async assertRegistrationAvailable(registration: string, excludeId: string | null) {
    const taken = await this.vehicles.findByRegistration(registration, excludeId);
    if (taken) {
      throw new ApiError(
        ErrorCodes.VEHICLE_REGISTRATION_TAKEN,
        'A vehicle with this RC number already exists.',
        409,
      );
    }
  }

  private serialize(row: VehicleRow) {
    return {
      vehicle_id: row.vehicle_id,
      vehicle_category_id: row.vehicle_category_id,
      category_name: row.category_name,
      rider_profile_id: row.rider_profile_id,
      rider_phone: row.rider_phone,
      registration: row.registration,
      two_wheeler_subtype: row.two_wheeler_subtype,
      active: row.active,
      created_at: row.created_at,
      updated_at: row.updated_at,
      order_count: row.order_count,
    };
  }
}

import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AuthContext } from '../auth/types/auth-context';
import { CreateZoneDto } from './dto/create-zone.dto';
import { UpdateZoneDto } from './dto/update-zone.dto';
import { ZoneRow, ZonesRepository } from './zones.repository';

@Injectable()
export class ZonesService {
  constructor(private readonly zones: ZonesRepository) {}

  async list(_auth: AuthContext) {
    const rows = await this.zones.list();
    return { zones: rows.map((row) => this.serialize(row)) };
  }

  async get(_auth: AuthContext, id: string) {
    const row = await this.zones.findById(id);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Zone was not found', 404);
    }
    return this.serialize(row);
  }

  async create(_auth: AuthContext, body: CreateZoneDto) {
    const city = await this.zones.findLaunchCity();
    if (!city) {
      throw new ApiError(
        ErrorCodes.CITY_INVALID,
        'Launch city AMD is not configured',
        409,
      );
    }
    const name = body.name.replace(/\s+/g, ' ').trim();
    await this.assertNameAvailable(city.city_id, name, null);
    const inserted = await this.zones.insert({
      cityId: city.city_id,
      name,
      active: body.active !== false,
    });
    const row = await this.zones.findById(inserted.zone_id);
    if (!row) {
      throw new ApiError(ErrorCodes.INTERNAL_ERROR, 'Zone was not found after create', 500);
    }
    return this.serialize(row);
  }

  async update(_auth: AuthContext, id: string, body: UpdateZoneDto) {
    const existing = await this.zones.findById(id);
    if (!existing) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Zone was not found', 404);
    }
    const name = (body.name ?? existing.name).replace(/\s+/g, ' ').trim();
    await this.assertNameAvailable(existing.city_id, name, id);
    await this.zones.update(id, {
      name,
      active: body.active ?? existing.active,
    });
    const row = await this.zones.findById(id);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Zone was not found', 404);
    }
    return this.serialize(row);
  }

  async remove(_auth: AuthContext, id: string) {
    const existing = await this.zones.findById(id);
    if (!existing) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Zone was not found', 404);
    }
    const riders = await this.zones.riderCount(id);
    if (riders > 0) {
      throw new ApiError(
        ErrorCodes.ZONE_INVALID,
        'Cannot delete this zone because riders are assigned to it. Please deactivate it instead.',
        409,
      );
    }
    await this.zones.delete(id);
    return { deleted: true, zone_id: id };
  }

  private async assertNameAvailable(cityId: string, name: string, excludeId: string | null) {
    const taken = await this.zones.findByName(cityId, name, excludeId);
    if (taken) {
      throw new ApiError(ErrorCodes.ZONE_NAME_TAKEN, 'This zone already exists.', 409);
    }
  }

  private serialize(row: ZoneRow) {
    return {
      zone_id: row.zone_id,
      city_id: row.city_id,
      city_code: row.city_code,
      city_name: row.city_name,
      name: row.name,
      active: row.active,
      created_at: row.created_at,
      rider_count: row.rider_count,
    };
  }
}

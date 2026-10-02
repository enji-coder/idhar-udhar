import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AuthContext } from '../auth/types/auth-context';
import { CitiesRepository } from './cities.repository';
import { CreateZoneDto } from './dto/create-zone.dto';
import { UpdateZoneDto } from './dto/update-zone.dto';
import { ZoneRow, ZonesRepository } from './zones.repository';

@Injectable()
export class ZonesService {
  constructor(
    private readonly zones: ZonesRepository,
    private readonly cities: CitiesRepository,
  ) {}

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
    await this.requireActiveCity(body.city_id);
    const name = body.name.replace(/\s+/g, ' ').trim();
    await this.assertNameAvailable(body.city_id, name, null);
    const inserted = await this.zones.insert({
      cityId: body.city_id,
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
    const cityId = body.city_id ?? existing.city_id;
    if (cityId !== existing.city_id) {
      await this.requireActiveCity(cityId);
    }
    const name = (body.name ?? existing.name).replace(/\s+/g, ' ').trim();
    await this.assertNameAvailable(cityId, name, id);
    await this.zones.update(id, {
      cityId,
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

  private async requireActiveCity(cityId: string) {
    const city = await this.cities.findById(cityId);
    if (!city || !city.active) {
      throw new ApiError(
        ErrorCodes.CITY_INVALID,
        'City was not found or is inactive',
        400,
      );
    }
    return city;
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
      state_id: row.state_id,
      state_code: row.state_code,
      state_name: row.state_name,
      name: row.name,
      active: row.active,
      created_at: row.created_at,
      rider_count: row.rider_count,
    };
  }
}

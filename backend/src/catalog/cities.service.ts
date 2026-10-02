import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AuthContext } from '../auth/types/auth-context';
import { CreateCityDto } from './dto/create-city.dto';
import { UpdateCityDto } from './dto/update-city.dto';
import { CitiesRepository, CityRow } from './cities.repository';
import { StatesRepository } from './states.repository';

@Injectable()
export class CitiesService {
  constructor(
    private readonly cities: CitiesRepository,
    private readonly states: StatesRepository,
  ) {}

  async list(_auth: AuthContext) {
    const rows = await this.cities.list();
    return { cities: rows.map((row) => this.serialize(row)) };
  }

  async get(_auth: AuthContext, id: string) {
    const row = await this.cities.findById(id);
    if (!row) {
      throw new ApiError(ErrorCodes.CITY_INVALID, 'City was not found', 404);
    }
    return this.serialize(row);
  }

  async create(_auth: AuthContext, body: CreateCityDto) {
    await this.requireActiveState(body.state_id);
    const name = body.name.replace(/\s+/g, ' ').trim();
    const cityCode = body.city_code.trim().toUpperCase();
    await this.assertCodeAvailable(cityCode, null);
    const inserted = await this.cities.insert({
      stateId: body.state_id,
      name,
      cityCode,
      active: body.active !== false,
    });
    const row = await this.cities.findById(inserted.city_id);
    if (!row) {
      throw new ApiError(
        ErrorCodes.INTERNAL_ERROR,
        'City was not found after create',
        500,
      );
    }
    return this.serialize(row);
  }

  async update(_auth: AuthContext, id: string, body: UpdateCityDto) {
    const existing = await this.cities.findById(id);
    if (!existing) {
      throw new ApiError(ErrorCodes.CITY_INVALID, 'City was not found', 404);
    }
    const stateId = body.state_id ?? existing.state_id;
    if (stateId !== existing.state_id) {
      await this.requireActiveState(stateId);
    }
    const name = (body.name ?? existing.name).replace(/\s+/g, ' ').trim();
    const cityCode = (body.city_code ?? existing.city_code).trim().toUpperCase();
    await this.assertCodeAvailable(cityCode, id);
    await this.cities.update(id, {
      stateId,
      name,
      cityCode,
      active: body.active ?? existing.active,
    });
    const row = await this.cities.findById(id);
    if (!row) {
      throw new ApiError(ErrorCodes.CITY_INVALID, 'City was not found', 404);
    }
    return this.serialize(row);
  }

  private async requireActiveState(stateId: string) {
    const state = await this.states.findById(stateId);
    if (!state || !state.active) {
      throw new ApiError(
        ErrorCodes.STATE_INVALID,
        'State was not found or is inactive',
        400,
      );
    }
    return state;
  }

  private async assertCodeAvailable(cityCode: string, excludeId: string | null) {
    const taken = await this.cities.findByCode(cityCode, excludeId);
    if (taken) {
      throw new ApiError(
        ErrorCodes.CITY_CODE_TAKEN,
        'This city code already exists.',
        409,
      );
    }
  }

  private serialize(row: CityRow) {
    return {
      city_id: row.city_id,
      state_id: row.state_id,
      state_code: row.state_code,
      state_name: row.state_name,
      name: row.name,
      city_code: row.city_code,
      active: row.active,
      created_at: row.created_at,
    };
  }
}

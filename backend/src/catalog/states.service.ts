import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AuthContext } from '../auth/types/auth-context';
import { CreateStateDto } from './dto/create-state.dto';
import { UpdateStateDto } from './dto/update-state.dto';
import { StateRow, StatesRepository } from './states.repository';

@Injectable()
export class StatesService {
  constructor(private readonly states: StatesRepository) {}

  async list(_auth: AuthContext) {
    const rows = await this.states.list();
    return { states: rows.map((row) => this.serialize(row)) };
  }

  async get(_auth: AuthContext, id: string) {
    const row = await this.states.findById(id);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'State was not found', 404);
    }
    return this.serialize(row);
  }

  async create(_auth: AuthContext, body: CreateStateDto) {
    const name = body.name.replace(/\s+/g, ' ').trim();
    const code = body.code.trim().toUpperCase();
    await this.assertCodeAvailable(code, null);
    const inserted = await this.states.insert({
      name,
      code,
      active: body.active !== false,
    });
    const row = await this.states.findById(inserted.state_id);
    if (!row) {
      throw new ApiError(
        ErrorCodes.INTERNAL_ERROR,
        'State was not found after create',
        500,
      );
    }
    return this.serialize(row);
  }

  async update(_auth: AuthContext, id: string, body: UpdateStateDto) {
    const existing = await this.states.findById(id);
    if (!existing) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'State was not found', 404);
    }
    const name = (body.name ?? existing.name).replace(/\s+/g, ' ').trim();
    const code = (body.code ?? existing.code).trim().toUpperCase();
    await this.assertCodeAvailable(code, id);
    await this.states.update(id, {
      name,
      code,
      active: body.active ?? existing.active,
    });
    const row = await this.states.findById(id);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'State was not found', 404);
    }
    return this.serialize(row);
  }

  private async assertCodeAvailable(code: string, excludeId: string | null) {
    const taken = await this.states.findByCode(code, excludeId);
    if (taken) {
      throw new ApiError(
        ErrorCodes.STATE_CODE_TAKEN,
        'This state code already exists.',
        409,
      );
    }
  }

  private serialize(row: StateRow) {
    return {
      state_id: row.state_id,
      name: row.name,
      code: row.code,
      active: row.active,
      created_at: row.created_at,
    };
  }
}

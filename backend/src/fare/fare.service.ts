import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AppConfig } from '../config/configuration';
import { Queryable } from '../database/queryable';
import { assertPositiveKm } from './money';
import {
  FareQuoteRow,
  FareRepository,
  serializeQuote,
} from './fare.repository';

@Injectable()
export class FareService {
  constructor(
    private readonly fares: FareRepository,
    private readonly configService: ConfigService,
  ) {}

  async quoteFromActiveConfig(
    input: {
      customerProfileId: string;
      vehicleCategoryId: string;
      distanceKm: string;
      stopCount: number;
    },
    db: Queryable,
  ) {
    let distance: string;
    try {
      distance = assertPositiveKm(input.distanceKm);
    } catch {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'distance_km must be a positive decimal with up to 3 fractional digits',
        400,
      );
    }
    if (input.stopCount < 2 || input.stopCount > 4) {
      throw new ApiError(
        ErrorCodes.INVALID_STOPS,
        'Fare quotes require 1 pickup and 1 to 3 drops',
        400,
      );
    }

    const ttl = this.configService.getOrThrow<AppConfig['fare']>('fare')
      .quoteTtlSeconds;
    const row = await this.fares.insertQuoteFromActiveConfig(
      {
        customerProfileId: input.customerProfileId,
        vehicleCategoryId: input.vehicleCategoryId,
        distanceKm: distance,
        stopCount: input.stopCount,
        ttlSeconds: ttl,
      },
      db,
    );
    if (!row) {
      throw new ApiError(
        ErrorCodes.FARE_CONFIG_UNAVAILABLE,
        'No active fare configuration exists for this vehicle category',
        409,
      );
    }
    return row;
  }

  assertQuoteUsable(input: {
    quote: FareQuoteRow;
    customerProfileId: string;
    vehicleCategoryId: string;
    stopCount: number;
    now?: Date;
  }): void {
    if (input.quote.customer_profile_id !== input.customerProfileId) {
      throw new ApiError(
        ErrorCodes.QUOTE_MISMATCH,
        'Fare quote does not belong to this customer',
        409,
      );
    }
    if (input.quote.vehicle_category_id !== input.vehicleCategoryId) {
      throw new ApiError(
        ErrorCodes.QUOTE_MISMATCH,
        'Fare quote vehicle category does not match the order',
        409,
      );
    }
    if (input.quote.stop_count !== input.stopCount) {
      throw new ApiError(
        ErrorCodes.QUOTE_MISMATCH,
        'Fare quote stop count does not match the order',
        409,
      );
    }
    const now = input.now ?? new Date();
    if (input.quote.expires_at.getTime() <= now.getTime()) {
      throw new ApiError(
        ErrorCodes.QUOTE_EXPIRED,
        'Fare quote has expired; request a new quote',
        409,
      );
    }
    if (input.quote.tax !== '0' && input.quote.tax !== '0.00') {
      throw new ApiError(
        ErrorCodes.INTERNAL_ERROR,
        'Fare quote tax must be 0',
        500,
      );
    }
  }

  toResponse(row: FareQuoteRow) {
    return serializeQuote(row);
  }
}

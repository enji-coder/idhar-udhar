import { Type } from 'class-transformer';
import { IsNumber, IsOptional, Min } from 'class-validator';

export class FareRatesDto {
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  base_fare?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  per_km?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  initial_minimum?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  waiting?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  surge?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  toll?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  parking?: number;
}

export function fareRatesHaveAmount(rates?: FareRatesDto | null): boolean {
  if (!rates) return false;
  const values = [
    rates.base_fare,
    rates.per_km,
    rates.initial_minimum,
    rates.waiting,
    rates.surge,
    rates.toll,
    rates.parking,
  ];
  return values.some((value) => value != null && Number(value) > 0);
}

export function normalizeFareRates(rates?: FareRatesDto | null): {
  base_fare: string;
  per_km: string;
  initial_minimum: string;
  waiting: string;
  surge: string;
  toll: string;
  parking: string;
} {
  const money = (value: number | undefined) =>
    (Number.isFinite(Number(value)) ? Number(value) : 0).toFixed(2);
  return {
    base_fare: money(rates?.base_fare),
    per_km: money(rates?.per_km),
    initial_minimum: money(rates?.initial_minimum ?? rates?.base_fare),
    waiting: money(rates?.waiting),
    surge: money(rates?.surge),
    toll: money(rates?.toll),
    parking: money(rates?.parking),
  };
}

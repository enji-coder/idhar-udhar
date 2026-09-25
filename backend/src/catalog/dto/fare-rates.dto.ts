import { Type } from 'class-transformer';
import { IsNumber, IsOptional, Max, Min } from 'class-validator';

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

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(100)
  rider_percentage?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(100)
  company_commission_percentage?: number;
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
  rider_percentage: string;
  company_commission_percentage: string;
} {
  const money = (value: number | undefined) =>
    (Number.isFinite(Number(value)) ? Number(value) : 0).toFixed(2);
  const riderGiven = rates?.rider_percentage != null;
  const companyGiven = rates?.company_commission_percentage != null;
  const rider = riderGiven ? Number(rates?.rider_percentage) : 85;
  const company = companyGiven ? Number(rates?.company_commission_percentage) : 15;
  return {
    base_fare: money(rates?.base_fare),
    per_km: money(rates?.per_km),
    initial_minimum: money(rates?.initial_minimum ?? rates?.base_fare),
    waiting: money(rates?.waiting),
    surge: money(rates?.surge),
    toll: money(rates?.toll),
    parking: money(rates?.parking),
    rider_percentage: money(rider),
    company_commission_percentage: money(company),
  };
}

export function fareSharesAreExplicit(rates?: FareRatesDto | null): boolean {
  return (
    rates?.rider_percentage != null || rates?.company_commission_percentage != null
  );
}

export function fareSharesSumTo100(rider: string, company: string): boolean {
  const paise = (value: string) => {
    const [whole, frac = ''] = value.split('.');
    return Number(whole) * 100 + Number((frac + '00').slice(0, 2));
  };
  return paise(rider) + paise(company) === 10000;
}

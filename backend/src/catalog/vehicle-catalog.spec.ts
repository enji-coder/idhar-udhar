import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CreateVehicleCategoryDto } from './dto/create-vehicle-category.dto';
import { FareRatesDto } from './dto/fare-rates.dto';
import { isVehiclePair } from './vehicle-catalog';

const VALID_PAIRS: Array<[string, string]> = [
  ['two_wheeler', 'bike'],
  ['two_wheeler', 'scooty'],
  ['three_wheeler', 'loader_riksha'],
  ['truck', 'mini_truck'],
  ['truck', 'tempo'],
  ['truck', 'large_tempo'],
  ['truck', 'truck'],
];

const INVALID_PAIRS: Array<[string, string]> = [
  ['two_wheeler', 'tempo'],
  ['two_wheeler', 'truck'],
  ['three_wheeler', 'bike'],
  ['truck', 'bike'],
  ['two_wheeler', 'loader_riksha'],
  ['three_wheeler', 'scooty'],
  ['truck', 'scooty'],
];

describe('vehicle hierarchy', () => {
  it.each(VALID_PAIRS)('accepts %s / %s', (vehicleType, vehicle) => {
    expect(isVehiclePair(vehicleType, vehicle)).toBe(true);
  });

  it.each(INVALID_PAIRS)('rejects %s / %s', (vehicleType, vehicle) => {
    expect(isVehiclePair(vehicleType, vehicle)).toBe(false);
  });

  it('rejects an unknown vehicle type before the pair check', async () => {
    const dto = plainToInstance(CreateVehicleCategoryDto, {
      name: 'Van',
      vehicle_type: 'car',
      vehicle: 'bike',
    });
    const errors = await validate(dto);
    expect(errors.some((error) => error.property === 'vehicle_type')).toBe(true);
  });

  it('rejects a negative base fare', async () => {
    const dto = plainToInstance(FareRatesDto, { base_fare: -1 });
    const errors = await validate(dto);
    expect(errors.some((error) => error.property === 'base_fare')).toBe(true);
  });

  it('rejects a commission above 100', async () => {
    const dto = plainToInstance(FareRatesDto, { rider_percentage: 101 });
    const errors = await validate(dto);
    expect(errors.some((error) => error.property === 'rider_percentage')).toBe(true);
  });
});

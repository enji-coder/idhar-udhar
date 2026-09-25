import { Controller, Get } from '@nestjs/common';
import { Public } from '../common/decorators/public.decorator';
import { VehicleCategoriesService } from './vehicle-categories.service';

@Controller('vehicle-categories')
export class VehicleCategoriesController {
  constructor(private readonly categories: VehicleCategoriesService) {}

  @Public()
  @Get()
  listActive() {
    return this.categories.listActive();
  }
}

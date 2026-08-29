import { Module } from '@nestjs/common';
import { CatalogRepository } from '../orders/catalog.repository';
import { AdminVehicleCategoriesController } from './admin-vehicle-categories.controller';
import { AdminVehiclesController } from './admin-vehicles.controller';
import { AdminZonesController } from './admin-zones.controller';
import { FarePublishRepository } from './fare-publish.repository';
import { VehicleCategoriesRepository } from './vehicle-categories.repository';
import { VehicleCategoriesService } from './vehicle-categories.service';
import { VehiclesRepository } from './vehicles.repository';
import { VehiclesService } from './vehicles.service';
import { ZonesRepository } from './zones.repository';
import { ZonesService } from './zones.service';

@Module({
  controllers: [
    AdminVehicleCategoriesController,
    AdminZonesController,
    AdminVehiclesController,
  ],
  providers: [
    VehicleCategoriesRepository,
    VehicleCategoriesService,
    FarePublishRepository,
    ZonesRepository,
    ZonesService,
    VehiclesRepository,
    VehiclesService,
    CatalogRepository,
  ],
})
export class CatalogModule {}

import { Module } from '@nestjs/common';
import { CatalogRepository } from '../orders/catalog.repository';
import { AdminCitiesController } from './admin-cities.controller';
import { AdminStatesController } from './admin-states.controller';
import { AdminVehicleCategoriesController } from './admin-vehicle-categories.controller';
import { VehicleCategoriesController } from './vehicle-categories.controller';
import { AdminVehiclesController } from './admin-vehicles.controller';
import { AdminZonesController } from './admin-zones.controller';
import { CitiesRepository } from './cities.repository';
import { CitiesService } from './cities.service';
import { FarePublishRepository } from './fare-publish.repository';
import { StatesRepository } from './states.repository';
import { StatesService } from './states.service';
import { VehicleCategoriesRepository } from './vehicle-categories.repository';
import { VehicleCategoriesService } from './vehicle-categories.service';
import { VehiclesRepository } from './vehicles.repository';
import { VehiclesService } from './vehicles.service';
import { ZonesRepository } from './zones.repository';
import { ZonesService } from './zones.service';

@Module({
  controllers: [
    AdminStatesController,
    AdminCitiesController,
    AdminVehicleCategoriesController,
    VehicleCategoriesController,
    AdminZonesController,
    AdminVehiclesController,
  ],
  providers: [
    StatesRepository,
    StatesService,
    CitiesRepository,
    CitiesService,
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

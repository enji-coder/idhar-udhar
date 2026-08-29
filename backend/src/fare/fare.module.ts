import { Module } from '@nestjs/common';
import { FareRepository } from './fare.repository';
import { FareService } from './fare.service';

@Module({
  providers: [FareRepository, FareService],
  exports: [FareRepository, FareService],
})
export class FareModule {}

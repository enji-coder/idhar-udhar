import { Controller, Get, Header, HttpCode, HttpStatus, Res } from '@nestjs/common';
import { Response } from 'express';
import { Public } from '../common/decorators/public.decorator';
import { HealthService } from './health.service';

@Public()
@Controller()
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get('health')
  @Header('cache-control', 'no-store')
  async overall(@Res({ passthrough: true }) res: Response) {
    const report = await this.healthService.overall();
    res.status(
      report.status === 'ok' ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE,
    );
    return report;
  }

  @Get('health/live')
  @HttpCode(HttpStatus.OK)
  @Header('cache-control', 'no-store')
  live() {
    return {
      status: 'ok',
      service: 'idhar-udhar-api',
      checks: { process: 'ok' },
    };
  }

  @Get('health/db')
  @Header('cache-control', 'no-store')
  async database(@Res({ passthrough: true }) res: Response) {
    const report = await this.healthService.database();
    res.status(
      report.status === 'ok' ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE,
    );
    return report;
  }
}

import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { configureApp } from './app.setup';
import { AppLogger } from './common/logger/app-logger';
import { envFilePaths } from './config/configuration';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  configureApp(app);
  const logger = app.get(AppLogger);
  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  logger.info('api_started', {
    port,
    env_files: envFilePaths(),
    prefix: '/v1',
  });
}

void bootstrap();

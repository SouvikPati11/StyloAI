import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/http-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);

  app.setGlobalPrefix('v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new HttpExceptionFilter());

  const origins = config.get<string>('CORS_ALLOWED_ORIGINS');
  app.enableCors({
    origin: origins ? origins.split(',').map((o) => o.trim()) : true,
    credentials: true,
  });

  const port = config.get<number>('PORT') ?? 3000;
  // Bind to a specific host. In production the app sits behind the Nginx TLS
  // reverse proxy, so it listens on 127.0.0.1 only (never publicly on :3000);
  // BIND_ADDRESS is set to 127.0.0.1 by the deployment. Defaults to 0.0.0.0 for
  // local development where no proxy is present.
  const host = config.get<string>('BIND_ADDRESS') ?? '0.0.0.0';
  await app.listen(port, host);
  Logger.log(`StyloAI backend listening on ${host}:${port}`, 'Bootstrap');
}

bootstrap();

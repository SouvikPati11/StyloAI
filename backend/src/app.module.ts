import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { BullModule } from '@nestjs/bullmq';
import { validateEnv } from './config/env.validation';
import { PrismaModule } from './prisma/prisma.module';
import { SettingsModule } from './settings/settings.module';
import { AuthModule } from './auth/auth.module';
import { CreditsModule } from './credits/credits.module';
import { StorageModule } from './storage/storage.module';
import { UsersModule } from './users/users.module';
import { AdminModule } from './admin/admin.module';
import { AiModule } from './ai/ai.module';
import { GenerationsModule } from './generations/generations.module';
import { HealthController } from './health/health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: validateEnv,
    }),
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const url = new URL(config.get<string>('REDIS_URL') ?? 'redis://localhost:6379');
        return {
          connection: {
            host: url.hostname,
            port: url.port ? Number(url.port) : 6379,
            username: url.username || undefined,
            password: url.password || undefined,
            tls: url.protocol === 'rediss:' ? {} : undefined,
          },
        };
      },
    }),
    PrismaModule,
    SettingsModule,
    AuthModule,
    CreditsModule,
    StorageModule,
    UsersModule,
    AdminModule,
    AiModule,
    GenerationsModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}

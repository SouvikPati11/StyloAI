import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { BullModule } from '@nestjs/bullmq';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
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
import { BillingModule } from './billing/billing.module';
import { ContentModule } from './content/content.module';
import { LooksModule } from './looks/looks.module';
import { ProfileModule } from './profile/profile.module';
import { EngagementModule } from './engagement/engagement.module';
import { HealthController } from './health/health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: validateEnv,
    }),
    // Serves the admin panel SPA at /admin (static; talks to the /v1/admin API).
    // The compiled module lives at dist/src/, and `nest build` does not copy the
    // `public/` tree into dist, so the static root must point at the source
    // public/admin folder: dist/src -> ../.. -> <backend>/public/admin. This maps
    // /admin/ -> public/admin/index.html and /admin/logo.png -> the brand asset.
    ServeStaticModule.forRoot({
      rootPath: join(__dirname, '..', '..', 'public', 'admin'),
      serveRoot: '/admin',
      serveStaticOptions: { index: 'index.html' },
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
    EngagementModule,
    GenerationsModule,
    BillingModule,
    ContentModule,
    LooksModule,
    ProfileModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}

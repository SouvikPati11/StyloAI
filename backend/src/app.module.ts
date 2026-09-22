import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { validateEnv } from './config/env.validation';
import { PrismaModule } from './prisma/prisma.module';
import { SettingsModule } from './settings/settings.module';
import { AuthModule } from './auth/auth.module';
import { CreditsModule } from './credits/credits.module';
import { StorageModule } from './storage/storage.module';
import { UsersModule } from './users/users.module';
import { AdminModule } from './admin/admin.module';
import { HealthController } from './health/health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: validateEnv,
    }),
    PrismaModule,
    SettingsModule,
    AuthModule,
    CreditsModule,
    StorageModule,
    UsersModule,
    AdminModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}

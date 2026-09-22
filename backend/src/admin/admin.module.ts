import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { AdminAuthGuard } from './admin-auth.guard';

@Module({
  providers: [AdminService, AdminAuthGuard],
  controllers: [AdminController],
})
export class AdminModule {}

import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { AdminContentController } from './admin-content.controller';
import { AdminUsersController } from './admin-users.controller';
import { AdminAuthGuard } from './admin-auth.guard';

@Module({
  providers: [AdminService, AdminAuthGuard],
  controllers: [AdminController, AdminContentController, AdminUsersController],
})
export class AdminModule {}

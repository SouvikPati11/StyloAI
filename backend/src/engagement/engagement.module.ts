import { Global, Module } from '@nestjs/common';
import { EngagementController } from './engagement.controller';
import { NotificationsService } from './notifications.service';

@Global()
@Module({
  providers: [NotificationsService],
  controllers: [EngagementController],
  exports: [NotificationsService],
})
export class EngagementModule {}

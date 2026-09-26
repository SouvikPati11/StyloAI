import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { GenerationsService } from './generations.service';
import { GenerationsController } from './generations.controller';
import { GenerationHealthController } from './generation-health.controller';
import { GenerationsProcessor } from './generations.processor';
import { WorkerHeartbeatService } from './worker-heartbeat.service';
import { GENERATION_QUEUE } from './generations.constants';

@Module({
  imports: [BullModule.registerQueue({ name: GENERATION_QUEUE })],
  providers: [GenerationsService, GenerationsProcessor, WorkerHeartbeatService],
  controllers: [GenerationsController, GenerationHealthController],
})
export class GenerationsModule {}

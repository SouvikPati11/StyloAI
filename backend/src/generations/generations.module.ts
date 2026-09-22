import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { GenerationsService } from './generations.service';
import { GenerationsController } from './generations.controller';
import { GenerationsProcessor } from './generations.processor';
import { GENERATION_QUEUE } from './generations.constants';

@Module({
  imports: [BullModule.registerQueue({ name: GENERATION_QUEUE })],
  providers: [GenerationsService, GenerationsProcessor],
  controllers: [GenerationsController],
})
export class GenerationsModule {}

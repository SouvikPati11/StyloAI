import { Module } from '@nestjs/common';
import { LooksController } from './looks.controller';

@Module({
  controllers: [LooksController],
})
export class LooksModule {}

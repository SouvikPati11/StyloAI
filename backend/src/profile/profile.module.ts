import { Module } from '@nestjs/common';
import { StyleProfileController } from './style-profile.controller';

@Module({
  controllers: [StyleProfileController],
})
export class ProfileModule {}

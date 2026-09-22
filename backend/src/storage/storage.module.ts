import { Global, Module } from '@nestjs/common';
import { StorageService } from './storage.service';
import { UploadsController } from './uploads.controller';

@Global()
@Module({
  providers: [StorageService],
  controllers: [UploadsController],
  exports: [StorageService],
})
export class StorageModule {}

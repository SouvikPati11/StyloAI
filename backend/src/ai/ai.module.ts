import { Global, Module } from '@nestjs/common';
import { GeminiProvider } from './gemini.provider';
import { IMAGE_PROVIDER } from './types';

/**
 * Binds the active image-generation provider behind the IMAGE_PROVIDER token.
 * Swapping providers (or adding a second) happens here — nothing else changes.
 */
@Global()
@Module({
  providers: [GeminiProvider, { provide: IMAGE_PROVIDER, useExisting: GeminiProvider }],
  exports: [IMAGE_PROVIDER, GeminiProvider],
})
export class AiModule {}

import { Global, Module } from '@nestjs/common';
import { OpenAiProvider } from './openai.provider';
import { GeminiProvider } from './gemini.provider';
import { IMAGE_PROVIDER } from './types';

/**
 * Binds the ACTIVE image-generation provider behind the IMAGE_PROVIDER token.
 * OpenAI is the active provider; Gemini is kept as a (currently inactive)
 * alternative implementation of the same interface. Swapping providers (or
 * adding a second) happens ONLY here — orchestration, the worker, the health
 * probe, and the app never change. Both providers keep their API key entirely
 * server-side.
 */
@Global()
@Module({
  providers: [
    OpenAiProvider,
    GeminiProvider,
    { provide: IMAGE_PROVIDER, useExisting: OpenAiProvider },
  ],
  exports: [IMAGE_PROVIDER, OpenAiProvider, GeminiProvider],
})
export class AiModule {}

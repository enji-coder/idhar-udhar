import { IsIn } from 'class-validator';

export const RIDER_LANGUAGES = ['en', 'hi', 'gu'] as const;

export class UpdateRiderLanguageDto {
  @IsIn(RIDER_LANGUAGES)
  preferred_language!: (typeof RIDER_LANGUAGES)[number];
}

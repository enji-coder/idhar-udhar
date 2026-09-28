import { IsString, MaxLength, MinLength } from 'class-validator';

export class RejectRiderDocumentDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  rejection_reason!: string;
}

import { IsIn, IsString } from 'class-validator';
import { RIDER_DOCUMENT_TYPES } from '../file-validation';

export class UploadRiderDocumentDto {
  @IsString()
  @IsIn([...RIDER_DOCUMENT_TYPES])
  document_type!: (typeof RIDER_DOCUMENT_TYPES)[number];
}

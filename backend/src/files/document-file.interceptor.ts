import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { MAX_DOCUMENT_BYTES } from './file-validation';

export function documentFileInterceptor() {
  return FileInterceptor('file', {
    storage: memoryStorage(),
    limits: { fileSize: MAX_DOCUMENT_BYTES, files: 1 },
  });
}

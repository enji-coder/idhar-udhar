import { PipeTransform, Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';

export const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Injectable()
export class UuidParamPipe implements PipeTransform<string, string> {
  transform(value: string): string {
    if (!UUID_RE.test(value)) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Parameter must be a UUID',
        400,
      );
    }
    return value.toLowerCase();
  }
}

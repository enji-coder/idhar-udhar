import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { IS_PUBLIC_KEY } from '../../common/decorators/public.decorator';
import { ApiError } from '../../common/errors/api-error';
import { ErrorCodes } from '../../common/errors/error-codes';
import { AuthService } from '../auth.service';
import { AuthContext } from '../types/auth-context';

type AuthedRequest = Request & { auth?: AuthContext };

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly auth: AuthService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) {
      return true;
    }

    const request = context.switchToHttp().getRequest<AuthedRequest>();
    const header = request.header('authorization') ?? '';
    const [scheme, token] = header.split(' ');
    if (!token || scheme?.toLowerCase() !== 'bearer') {
      throw new ApiError(
        ErrorCodes.UNAUTHENTICATED,
        'Missing bearer access token',
        401,
      );
    }

    request.auth = await this.auth.resolveAccessToken(token);
    return true;
  }
}

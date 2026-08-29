import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { ApiError } from '../../common/errors/api-error';
import { ErrorCodes } from '../../common/errors/error-codes';
import { AuthContext, ProfileRole } from '../types/auth-context';

type AuthedRequest = Request & { auth?: AuthContext };

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const roles = this.reflector.getAllAndOverride<ProfileRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!roles || roles.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest<AuthedRequest>();
    const auth = request.auth;
    if (!auth) {
      throw new ApiError(
        ErrorCodes.UNAUTHENTICATED,
        'Missing bearer access token',
        401,
      );
    }
    if (!roles.includes(auth.role)) {
      throw new ApiError(
        ErrorCodes.FORBIDDEN,
        'This resource is not available for the active role',
        403,
      );
    }
    return true;
  }
}

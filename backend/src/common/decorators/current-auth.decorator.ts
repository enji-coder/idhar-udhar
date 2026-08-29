import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AuthContext } from '../../auth/types/auth-context';

export const CurrentAuth = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthContext => {
    const request = ctx.switchToHttp().getRequest<{ auth?: AuthContext }>();
    if (!request.auth) {
      throw new Error('CurrentAuth used without JwtAuthGuard');
    }
    return request.auth;
  },
);

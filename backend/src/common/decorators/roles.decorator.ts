import { SetMetadata } from '@nestjs/common';
import { ProfileRole } from '../../auth/types/auth-context';

export const ROLES_KEY = 'roles';

export const Roles = (...roles: ProfileRole[]) => SetMetadata(ROLES_KEY, roles);

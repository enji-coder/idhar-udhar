import { AuditService } from './audit.service';
import { AuditRepository } from './audit.repository';
import { AppLogger } from '../common/logger/app-logger';
import { AuthContext } from '../auth/types/auth-context';

const auth: AuthContext = {
  identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  sessionId: 'session',
  role: 'ADMIN',
  profileId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
};

const input = {
  auth,
  action: 'ORDER_PURGED',
  entityType: 'ORDER',
  entityId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  category: 'ADMIN' as const,
  reason: 'historical cleanup',
};

describe('AuditService', () => {
  it('keeps best-effort audit from aborting the caller', async () => {
    const repo = {
      insert: jest.fn(async () => {
        throw new Error('audit down');
      }),
    };
    const logger = { error: jest.fn() };
    const audit = new AuditService(repo as unknown as AuditRepository, logger as unknown as AppLogger);
    await expect(audit.record(input, { query: jest.fn() })).resolves.toBeUndefined();
    expect(logger.error).toHaveBeenCalledWith(
      'audit_write_failed',
      expect.objectContaining({ action: 'ORDER_PURGED' }),
    );
  });

  it('propagates a mandatory audit failure on the caller transaction', async () => {
    const tx = { query: jest.fn() };
    const repo = {
      insert: jest.fn(async (_row: unknown, db: unknown) => {
        expect(db).toBe(tx);
        throw new Error('audit down');
      }),
    };
    const logger = { error: jest.fn() };
    const audit = new AuditService(repo as unknown as AuditRepository, logger as unknown as AppLogger);
    await expect(audit.recordRequired(input, tx)).rejects.toThrow('audit down');
    expect(logger.error).not.toHaveBeenCalled();
  });
});

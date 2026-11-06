import { ConfigService } from '@nestjs/config';
import { IdentityRepository } from './identity.repository';
import { PostgresService } from '../../database/postgres.service';

const riderId = '11111111-1111-4111-8111-111111111111';

class RecordingDb {
  readonly sql: string[] = [];

  constructor(private readonly allowSessions: boolean) {}

  async query(text: string) {
    this.sql.push(text);
    if (!this.allowSessions && text.includes('rider_online_sessions')) {
      throw new Error('rider_online_sessions was queried while disabled');
    }
    return {
      rows: [
        {
          approval_status: 'APPROVED',
          online_status: 'OFFLINE',
          rider_profile_id: riderId,
          deactivated_at: new Date('2026-11-06T00:00:00.000Z'),
          session_id: '22222222-2222-4222-8222-222222222222',
          started_at: new Date('2026-11-06T00:00:00.000Z'),
          ended_at: null,
          name: null,
          phone_normalized: '919999999999',
        },
      ],
      rowCount: 1,
    };
  }

  transaction<T>(fn: (tx: RecordingDb) => Promise<T>): Promise<T> {
    return fn(this);
  }
}

function config(onlineTimeEnabled: boolean): ConfigService {
  return {
    getOrThrow: () => ({ onlineTimeEnabled, presenceStaleMs: 180_000 }),
  } as unknown as ConfigService;
}

function repository(onlineTimeEnabled: boolean, db: RecordingDb): IdentityRepository {
  return new IdentityRepository(
    db as unknown as PostgresService,
    config(onlineTimeEnabled),
  );
}

describe('rider online sessions stay unread while disabled', () => {
  it('updates availability, presence, expiry, and deactivation without the session table', async () => {
    const db = new RecordingDb(false);
    const identities = repository(false, db);

    await identities.updateRiderOnlineStatus(riderId, 'ONLINE');
    await identities.updateRiderOnlineStatus(riderId, 'OFFLINE');
    await identities.closeOpenOnlineSessions(riderId, 'OFFLINE');
    await identities.closeOpenOnlineSessions(riderId, 'DEACTIVATED');
    await identities.touchRiderLastSeen(riderId);
    await identities.expireStaleOnlineRiders(180_000);
    await identities.listOnlineSessionsOverlapping(
      '2026-11-05T18:30:00.000Z',
      '2026-11-06T18:30:00.000Z',
      riderId,
      '',
    );
    await identities.deactivateRider(riderId);

    const joined = db.sql.join('\n');
    expect(joined).not.toContain('rider_online_sessions');
    expect(joined).toContain('UPDATE rider_profiles');
    expect(joined).toContain('last_seen_at = now()');
    expect(joined).toContain("online_status = 'OFFLINE'");
    expect(joined).toContain('deactivated_at = now()');
  });

  it('still queries rider_online_sessions when the flag is enabled', async () => {
    const db = new RecordingDb(true);
    const identities = repository(true, db);

    await identities.listOnlineSessionsOverlapping(
      '2026-11-05T18:30:00.000Z',
      '2026-11-06T18:30:00.000Z',
      null,
      '',
    );

    expect(db.sql.join('\n')).toContain('rider_online_sessions');
  });
});

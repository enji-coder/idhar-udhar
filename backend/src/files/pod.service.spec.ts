import { ApiError } from '../common/errors/api-error';
import { AuthContext } from '../auth/types/auth-context';
import { PostgresService } from '../database/postgres.service';
import { OrderRow, OrderStopRow, OrdersRepository } from '../orders/orders.repository';
import { ObjectStorage } from '../storage/object-storage';
import { FilesRepository } from './files.repository';
import { PodService } from './pod.service';

const orderId = '33333333-3333-4333-8333-333333333333';
const stopId = '44444444-4444-4444-8444-444444444444';
const riderId = '11111111-1111-4111-8111-111111111111';
const otherRiderId = '55555555-5555-4555-8555-555555555555';
const customerId = '77777777-7777-4777-8777-777777777777';

function jpeg(): Buffer {
  const buffer = Buffer.alloc(32, 0);
  buffer[0] = 0xff;
  buffer[1] = 0xd8;
  buffer[2] = 0xff;
  return buffer;
}

function riderAuth(profileId = riderId): AuthContext {
  return {
    identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    role: 'RIDER',
    profileId,
  };
}

function customerAuth(profileId = customerId): AuthContext {
  return {
    identityId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    sessionId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    role: 'CUSTOMER',
    profileId,
  };
}

function order(status: OrderRow['canonical_status'] = 'DELIVERY_ATTEMPT'): OrderRow {
  return {
    order_id: orderId,
    display_id: 'AMD-1',
    customer_profile_id: customerId,
    rider_profile_id: riderId,
    city_id: '88888888-8888-4888-8888-888888888888',
    city_code: 'AMD',
    vehicle_category_id: '99999999-9999-4999-8999-999999999999',
    vehicle_category_name_snapshot: 'Bike',
    vehicle_id: null,
    canonical_status: status,
    parent_order_id: null,
    scheduled_at: null,
    created_at: new Date('2026-09-19T08:00:00.000Z'),
    updated_at: new Date('2026-09-19T08:00:00.000Z'),
  };
}

function dropStop(): OrderStopRow {
  return {
    order_stop_id: stopId,
    order_id: orderId,
    sequence: 2,
    stop_type: 'DROP',
    address_text: 'Drop',
    latitude: '23.0',
    longitude: '72.5',
    zone_id: null,
    contact_name: null,
    contact_phone: null,
    arrived_at: null,
    completed_at: null,
    proof_file_id: null,
  };
}

describe('PodService', () => {
  const storage: jest.Mocked<ObjectStorage> = {
    putObject: jest.fn(),
    deleteObject: jest.fn(),
    getSignedGetUrl: jest.fn(),
  };
  const files = {
    insertStoredFile: jest.fn(),
    attachPodFile: jest.fn(),
    findPodFile: jest.fn(),
  };
  const orders = {
    lockById: jest.fn(),
    findById: jest.fn(),
    findStopById: jest.fn(),
  };
  const postgres = {
    transaction: jest.fn(async (work: (tx: object) => Promise<unknown>) =>
      work({}),
    ),
  };
  const service = new PodService(
    postgres as unknown as PostgresService,
    orders as unknown as OrdersRepository,
    files as unknown as FilesRepository,
    storage,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    storage.putObject.mockResolvedValue(undefined);
    storage.deleteObject.mockResolvedValue(undefined);
    storage.getSignedGetUrl.mockResolvedValue({
      url: 'https://example.invalid/pod?X-Amz-Signature=secret',
      expiresInSeconds: 300,
    });
    orders.lockById.mockResolvedValue(order());
    orders.findById.mockResolvedValue(order('DELIVERED'));
    orders.findStopById.mockResolvedValue(dropStop());
    files.insertStoredFile.mockResolvedValue({});
    files.attachPodFile.mockResolvedValue(undefined);
    files.findPodFile.mockResolvedValue({
      order_id: orderId,
      order_stop_id: stopId,
      stop_type: 'DROP',
      proof_file_id: '66666666-6666-4666-8666-666666666666',
      storage_key: `orders/${orderId}/pod/${stopId}/pod.jpg`,
      content_type: 'image/jpeg',
      size_bytes: 32,
      purpose: 'POD',
    });
  });

  it('uploads POD for the assigned rider in an allowed delivery state', async () => {
    const result = await service.uploadForRider(riderAuth(), orderId, stopId, {
      buffer: jpeg(),
      mimetype: 'image/jpeg',
      originalname: 'pod.jpg',
    });
    expect(storage.putObject).toHaveBeenCalledWith(
      expect.objectContaining({
        key: `orders/${orderId}/pod/${stopId}/pod.jpg`,
        contentType: 'image/jpeg',
      }),
    );
    expect(files.insertStoredFile).toHaveBeenCalledWith(
      expect.objectContaining({ purpose: 'POD' }),
      {},
    );
    expect(files.attachPodFile).toHaveBeenCalledWith(stopId, expect.any(String), {});
    expect(result.proof_file_id).toEqual(expect.any(String));
  });

  it('does not bypass order status to allow an early POD upload', async () => {
    orders.lockById.mockResolvedValue(order('IN_TRANSIT'));
    await expect(
      service.uploadForRider(riderAuth(), orderId, stopId, {
        buffer: jpeg(),
        mimetype: 'image/jpeg',
        originalname: 'pod.jpg',
      }),
    ).rejects.toMatchObject({ code: 'ORDER_NOT_MODIFIABLE', status: 409 });
    expect(storage.putObject).not.toHaveBeenCalled();
  });

  it('rejects a rider who is not assigned to the order', async () => {
    await expect(
      service.uploadForRider(riderAuth(otherRiderId), orderId, stopId, {
        buffer: jpeg(),
        mimetype: 'image/jpeg',
        originalname: 'pod.jpg',
      }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN', status: 403 });
    expect(storage.putObject).not.toHaveBeenCalled();
  });

  it('does not persist POD metadata when S3 fails', async () => {
    storage.putObject.mockRejectedValue(
      new ApiError('STORAGE_UNAVAILABLE', 'down', 503),
    );
    await expect(
      service.uploadForRider(riderAuth(), orderId, stopId, {
        buffer: jpeg(),
        mimetype: 'image/jpeg',
        originalname: 'pod.jpg',
      }),
    ).rejects.toMatchObject({ code: 'STORAGE_UNAVAILABLE' });
    expect(files.insertStoredFile).not.toHaveBeenCalled();
    expect(files.attachPodFile).not.toHaveBeenCalled();
  });

  it('rejects a customer downloading another customer POD', async () => {
    await expect(
      service.downloadForActor(
        customerAuth('00000000-0000-4000-8000-000000000000'),
        orderId,
        stopId,
      ),
    ).rejects.toMatchObject({ code: 'FORBIDDEN', status: 403 });
    expect(storage.getSignedGetUrl).not.toHaveBeenCalled();
  });

  it('returns a short-lived private download URL to the owning customer', async () => {
    const result = await service.downloadForActor(
      customerAuth(),
      orderId,
      stopId,
    );
    expect(result.download_url_expires_in).toBe(300);
    expect(files.findPodFile).toHaveBeenCalledWith(orderId, stopId);
  });
});

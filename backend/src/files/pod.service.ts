import { createHash, randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AuthContext } from '../auth/types/auth-context';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { OrderRow, OrderStopRow, OrdersRepository } from '../orders/orders.repository';
import { OrderStatus } from '../orders/order-status';
import { OBJECT_STORAGE, ObjectStorage } from '../storage/object-storage';
import { UploadedBinary, validateUpload } from './file-validation';
import { FilesRepository } from './files.repository';
import { fileNameFromStorageKey, orderPodObjectKey } from './object-key';

const POD_UPLOAD_STATUSES: ReadonlySet<OrderStatus> = new Set([
  'NEAR_DROP',
  'DELIVERY_ATTEMPT',
  'DELIVERED',
]);

@Injectable()
export class PodService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly orders: OrdersRepository,
    private readonly files: FilesRepository,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
  ) {}

  async uploadForRider(
    auth: AuthContext,
    orderId: string,
    stopId: string,
    file: UploadedBinary | undefined,
  ) {
    this.assertRider(auth);
    const validated = validateUpload(file);
    const fileId = randomUUID();
    const checksum = createHash('sha256').update(validated.buffer).digest('hex');
    const storageKey = orderPodObjectKey({
      orderId,
      stopId,
      fileName: validated.safeFileName,
    });

    await this.postgres.transaction(async (tx) => {
      await this.assertReadyForPod(auth, orderId, stopId, tx);
    });

    await this.storage.putObject({
      key: storageKey,
      body: validated.buffer,
      contentType: validated.contentType,
    });

    try {
      await this.postgres.transaction(async (tx) => {
        const stop = await this.assertReadyForPod(auth, orderId, stopId, tx);
        await this.files.insertStoredFile(
          {
            fileId,
            storageKey,
            contentType: validated.contentType,
            sizeBytes: validated.sizeBytes,
            checksum,
            purpose: 'POD',
            createdByIdentityId: auth.identityId,
          },
          tx,
        );
        await this.files.attachPodFile(stop.order_stop_id, fileId, tx);
      });
    } catch (err) {
      await this.storage.deleteObject(storageKey).catch(() => undefined);
      throw err;
    }

    return {
      order_id: orderId,
      order_stop_id: stopId,
      proof_file_id: fileId,
      content_type: validated.contentType,
      size_bytes: validated.sizeBytes,
    };
  }

  async downloadForActor(
    auth: AuthContext,
    orderId: string,
    stopId: string,
  ) {
    const order = await this.orders.findById(orderId);
    if (!order) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    this.assertCanReadPod(auth, order);
    const pod = await this.files.findPodFile(orderId, stopId);
    if (!pod) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Proof of delivery was not found', 404);
    }
    const signed = await this.storage.getSignedGetUrl(
      pod.storage_key,
      fileNameFromStorageKey(pod.storage_key),
    );
    return {
      order_id: pod.order_id,
      order_stop_id: pod.order_stop_id,
      proof_file_id: pod.proof_file_id,
      content_type: pod.content_type,
      size_bytes: pod.size_bytes,
      download_url: signed.url,
      download_url_expires_in: signed.expiresInSeconds,
    };
  }

  private async assertReadyForPod(
    auth: AuthContext,
    orderId: string,
    stopId: string,
    tx: Queryable,
  ): Promise<OrderStopRow> {
    const order = await this.orders.lockById(orderId, tx);
    if (!order) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    this.assertAssignedRider(auth, order);
    this.assertPodUploadStatus(order.canonical_status);
    return this.requireDropStop(orderId, stopId, tx);
  }

  private async requireDropStop(
    orderId: string,
    stopId: string,
    tx: Queryable,
  ): Promise<OrderStopRow> {
    const stop = await this.orders.findStopById(orderId, stopId, tx);
    if (!stop) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order stop was not found', 404);
    }
    if (stop.stop_type !== 'DROP') {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Proof of delivery can only be attached to a drop stop',
        400,
      );
    }
    return stop;
  }

  private assertPodUploadStatus(status: OrderStatus): void {
    if (!POD_UPLOAD_STATUSES.has(status)) {
      throw new ApiError(
        ErrorCodes.ORDER_NOT_MODIFIABLE,
        'Proof of delivery can only be uploaded near drop, during a delivery attempt, or after delivery',
        409,
      );
    }
  }

  private assertAssignedRider(auth: AuthContext, order: OrderRow): void {
    if (order.rider_profile_id !== auth.profileId) {
      throw new ApiError(
        ErrorCodes.FORBIDDEN,
        'Rider is not assigned to this order',
        403,
      );
    }
  }

  private assertCanReadPod(auth: AuthContext, order: OrderRow): void {
    if (auth.role === 'ADMIN') {
      return;
    }
    if (auth.role === 'CUSTOMER' && order.customer_profile_id === auth.profileId) {
      return;
    }
    if (auth.role === 'RIDER' && order.rider_profile_id === auth.profileId) {
      return;
    }
    throw new ApiError(
      ErrorCodes.FORBIDDEN,
      'Not permitted to access this proof of delivery',
      403,
    );
  }

  private assertRider(auth: AuthContext): void {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider role required', 403);
    }
  }
}

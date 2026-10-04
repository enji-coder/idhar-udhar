export const OTP_DELIVERY = Symbol('OTP_DELIVERY');

export type OtpDeliveryMode = 'capture' | 'unconfigured' | 'msg91';

export type OtpDeliveryInput = {
  phoneNormalized: string;
  code: string;
  /** Used to select the Android SMS Retriever app hash for the actor app. */
  actorType?: 'CUSTOMER' | 'RIDER' | 'ADMIN';
};

export interface OtpDeliveryProvider {
  readonly mode: OtpDeliveryMode;
  send(input: OtpDeliveryInput): Promise<void>;
}

export const OTP_DELIVERY = Symbol('OTP_DELIVERY');

export type OtpDeliveryMode = 'capture' | 'unconfigured' | 'msg91';

export type OtpDeliveryInput = {
  phoneNormalized: string;
  code: string;
};

export interface OtpDeliveryProvider {
  readonly mode: OtpDeliveryMode;
  send(input: OtpDeliveryInput): Promise<void>;
}

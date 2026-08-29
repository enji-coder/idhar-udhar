export const OTP_DELIVERY = Symbol('OTP_DELIVERY');

export type OtpDeliveryInput = {
  phoneNormalized: string;
  code: string;
};

export interface OtpDeliveryProvider {
  readonly mode: 'capture' | 'unconfigured';
  send(input: OtpDeliveryInput): Promise<void>;
}

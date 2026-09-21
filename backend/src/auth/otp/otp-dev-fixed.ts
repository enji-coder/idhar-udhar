/**
 * Temporary development OTP for capture-mode testing.
 * Not a secret. Never accepted when NODE_ENV=production.
 * Any exactly-4-digit code is accepted only in non-production capture.
 */
export function isDevCaptureDummyOtp(input: {
  code: string;
  nodeEnv: string;
  delivery: 'capture' | 'unconfigured' | 'msg91';
}): boolean {
  if (input.nodeEnv.toLowerCase() === 'production') {
    return false;
  }
  if (input.delivery !== 'capture') {
    return false;
  }
  return /^\d{4}$/.test(input.code);
}

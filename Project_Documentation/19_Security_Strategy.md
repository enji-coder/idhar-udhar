# 19 — Security Strategy

## 19.1 Threat Model (Summary)

| Threat | Mitigation |
|--------|------------|
| Stolen session | Short-lived tokens; secure storage; revoke on logout |
| Fare tampering | Server-side fare calculation |
| Fake accept races | Transactional matching Function |
| KYC document leakage | Storage rules; signed URLs; admin-only list |
| OTP brute force | Rate limits; Firebase/App Check |
| Privileged admin abuse | MFA + audit logs (future) |
| API key theft | Restricted keys; prefer Functions proxy for sensitive Google calls |

## 19.2 Authentication Security

- Store refresh/session material in **Flutter Secure Storage**
- Prefer biometric unlock for returning sessions (V1.1 optional)
- Clear secure storage on logout
- Enforce strong password policy (min length, complexity)
- Phone OTP expiry & resend cooldown

## 19.3 Authorization

- Custom claims: `role`
- Firestore rules check `request.auth.uid` and role
- Clients never trusted for role escalation
- Admin operations only via Admin SDK

## 19.4 Data Protection

- PII minimization in logs/analytics
- Encrypt backups per Firebase defaults
- KYC retention & access policy
- Mask phone numbers in rider-facing UI where not needed

## 19.5 Network Security

- HTTPS only
- Certificate pinning optional (V1.1) for Functions domain
- Dio interceptor strips secrets from logs

## 19.6 App Integrity

- Enable **Firebase App Check**
- Obfuscate release builds (`--obfuscate` + split debug info)
- ProGuard/R8 on Android
- Hide Maps keys via restrictions

## 19.7 Payment Security

- Never store card PAN in Firestore
- Gateway tokenization only
- Verify webhooks with signatures
- Idempotent payment processing

## 19.8 Secure Coding Practices

- No secrets in git
- `.env` / CI secrets for keys
- Dependency vulnerability scanning in CI
- Least privilege service accounts for Functions

## 19.9 Incident Response (Lightweight)

1. Revoke compromised API keys
2. Force logout via token invalidation / version gate
3. Crashlytics + support triage
4. Postmortem template in repo `docs/` later

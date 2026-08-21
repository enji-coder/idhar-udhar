# 24 — Git Workflow

## 24.1 Branching Model

**GitHub Flow + protected main**

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready; protected |
| `develop` | Integration (optional if small team; else PR to main) |
| `feature/<app>-<short-name>` | Features |
| `fix/<short-name>` | Bugfixes |
| `chore/<short-name>` | Tooling |
| `release/x.y.z` | Release hardening |

Examples: `feature/customer-login`, `feature/rider-kyc`, `fix/fare-rounding`

## 24.2 Commit Messages

Conventional Commits:

```
feat(customer): add OTP verification screen
fix(rider): prevent double accept on job request
docs: add Firebase architecture notes
chore(ci): cache flutter deps
```

## 24.3 Pull Requests

- Small, reviewable PRs
- Link FR IDs when relevant
- Screenshots for UI changes
- Checklist: analyze, tests, no secrets
- Require 1 approval before merge to `main`

## 24.4 Versioning

SemVer: `MAJOR.MINOR.PATCH`  
App `version` + `buildNumber` in pubspec per flavor.

## 24.5 Hotfixes

```
main → hotfix/x.y.z → PR to main → tag → cherry-pick develop
```

## 24.6 Secrets

- Never commit `google-services.json` / `GoogleService-Info.plist` with prod keys to public repos without private controls
- Prefer CI-injected secrets; document local setup in README

## 24.7 Tagging & Releases

- Tag `v1.0.0` on production cut
- Generate changelog from conventional commits

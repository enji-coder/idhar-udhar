# 25 — Coding Standards

## 25.1 Language & Style

- Dart latest stable language features (null safety mandatory)
- Official Effective Dart + project `analysis_options.yaml` (lints recommended / flutter_lints)
- `dart format` line length 80 or 100 (team choice; document in analyze config)

## 25.2 Architecture Rules

1. Feature-first folders
2. Presentation → Application → Domain → Data dependency direction only
3. No Firebase in widgets
4. Freezed for DTOs & failures
5. Riverpod for state; no `setState` across features (local ephemeral OK)

## 25.3 Naming

| Item | Style |
|------|-------|
| Files | `snake_case.dart` |
| Classes | `PascalCase` |
| Variables / methods | `camelCase` |
| Constants | `camelCase` or `SCREAMING_SNAKE` for true compile-time env |
| Providers | `xxxProvider` |
| Private | `_leadingUnderscore` |

## 25.4 Widgets

- Prefer small private widgets over huge `build`
- `const` constructors wherever possible
- Keys for OTP fields / lists with identity
- Design system components over one-off colors

## 25.5 Async

- Prefer `async`/`await`
- Handle `AsyncValue` exhaustively
- Cancel subscriptions in `dispose` / Riverpod `ref.onDispose`

## 25.6 Comments

- Comment **why**, not what
- No commented-out dead code
- TODOs must include owner/ticket

## 25.7 Localization

- No hardcoded user-visible English in production widgets—use l10n ARB
- Exceptions: brand name “IDHAR UDHAR”

## 25.8 Logging

- Use shared logger; levels debug/info/warning/error
- Redact tokens, OTP, precise addresses in logs if required by policy

## 25.9 PR Hygiene

- One logical change per PR
- Update docs when architecture changes
- Do not mix format-only with feature changes unless necessary

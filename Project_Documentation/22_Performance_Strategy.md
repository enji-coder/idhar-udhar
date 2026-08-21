# 22 — Performance Strategy

## 22.1 Client Performance

| Area | Strategy |
|------|----------|
| Startup | Minimize work in `main`; defer non-critical init |
| Images | `cached_network_image`; WebP; sized decodes |
| Lists | Pagination; `ListView.builder`; avoid shrinkWrap stacks |
| Maps | Single map instance per screen; throttle camera |
| Blur | Conditional blur on low-end / reduce layers |
| Build | `const` widgets; avoid rebuild storms (Riverpod select) |
| Fonts | Google Fonts with runtime fetching + cache; consider bundling subset |
| Lottie | Load once; pause offstage |

## 22.2 Network Performance

- Parallelize independent reads carefully
- Compress images before Storage upload (KYC)
- Places session tokens to reduce cost/latency
- Cache Directions results for identical rounded coordinates

## 22.3 Firestore Performance

- Narrow projections via document design (avoid huge docs)
- Paginate history (`limit` + cursor)
- Close unused listeners on dispose
- Denormalize trip card fields to avoid joins

## 22.4 Location Performance

- Rider: balanced accuracy when online idle; high when on trip
- Write throttle 3–5s
- Stop streams when Offline

## 22.5 CI / Release Performance Budgets

- Track app size per release
- Startup trace via Firebase Performance Monitoring (enable V1.1)
- Frame rendering jank monitoring on booking + tracking screens

## 22.6 Low-End Device Profile

Target validation devices: ~4GB RAM Android mid-tier.

Degrade:

1. Disable multi-layer blur
2. Reduce shadow complexity
3. Lower map padding animations

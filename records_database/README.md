# records_database — IDHAR UDHAR long-term source of truth

This folder is the **project documentation for database architecture, business rules, financial rules, role rules, and finalized application decisions**.

It is **not** the Flutter or Admin application. Application code lives in `idhar_udhar/` and `IDHAR_UDHAR_ADMIN/`.

**Do not treat any file in this folder as a live database.** PostgreSQL is **not implemented**. Firebase is **not** the production data store.

---

## How to read this folder

| If you need… | Open |
|---|---|
| **Current system as the apps work today** | [`FINAL_MASTER_ANALYSIS.md`](FINAL_MASTER_ANALYSIS.md) |
| **Simple-language business rules** (non-developer) | [`RULES_BOOK.md`](RULES_BOOK.md) |
| **Questions that still cannot be answered from code** | [`OPEN_QUESTIONS.md`](OPEN_QUESTIONS.md) |
| **V1 business-rule lock for future database work** | [`18_FINAL_BUSINESS_DECISIONS.md`](18_FINAL_BUSINESS_DECISIONS.md) |
| **Feature → future table requirements** | [`19_DATABASE_REQUIREMENTS_FROM_FEATURES.md`](19_DATABASE_REQUIREMENTS_FROM_FEATURES.md) |
| **Historical discovery of each app** | `01` Customer · `02` Rider · `03` Admin |
| **Recommended production architecture (not built)** | `00` · `04`–`16` |

**Primary current-system analysis:** `FINAL_MASTER_ANALYSIS.md`  
**Simple rules reference:** `RULES_BOOK.md`  
**FINAL payment model:** WHO PAYS (Customer / Receiver) is separate from HOW THEY PAY (Online / Cash). Split payment is supported.

---

## Documentation principle

```text
CURRENT CODE
      ↓
CURRENT BUSINESS BEHAVIOR
      ↓
FINAL_MASTER_ANALYSIS.md
      ↓
RULES_BOOK.md
      ↓
DATABASE / ARCHITECTURE FILES (planned, not live)
```

The documentation must not describe a removed feature as if it were active.

Historical files (`00`–`19`) are **preserved**. If a later re-analysis finds a change, the change is recorded as:

```text
OLD DECISION / OLD EVIDENCE
↓
CURRENT DECISION / CURRENT CODE
```

---

## File index

| File | Role |
|---|---|
| `FINAL_MASTER_ANALYSIS.md` | Current Customer + Rider + Admin + mock data + planned DB |
| `RULES_BOOK.md` | Plain-language rules |
| `OPEN_QUESTIONS.md` | Only remaining genuine unknowns |
| `00_MASTER_DATABASE_ARCHITECTURE.md` | Recommended Postgres/API architecture (not built) |
| `01_customer_database_discovery.md` | Customer app discovery snapshot |
| `02_RIDER_DATABASE_DISCOVERY.md` | Rider app discovery snapshot |
| `03_ADMIN_DATABASE_DISCOVERY.md` | Admin app discovery snapshot |
| `04_UNIFIED_ENTITY_RELATIONSHIPS.md` | Planned entity relationships |
| `05_DATABASE_SCHEMA_BLUEPRINT.md` | Planned schema |
| `06_API_CONTRACT_BLUEPRINT.md` | Planned API |
| `07_REALTIME_ARCHITECTURE.md` | Planned realtime |
| `08_PAYMENT_FINANCIAL_ARCHITECTURE.md` | Planned finance |
| `09_NOTIFICATION_ARCHITECTURE.md` | Planned notifications |
| `10_REPORTING_ARCHITECTURE.md` | Planned reports |
| `11_SECURITY_ARCHITECTURE.md` | Planned security |
| `12_FILE_STORAGE_ARCHITECTURE.md` | Planned file storage |
| `13_ROLE_PERMISSION_MATRIX.md` | Role matrix (target + current) |
| `14_DATA_FLOW_CUSTOMER_RIDER_ADMIN.md` | Planned data flow |
| `15_MOCK_TO_PRODUCTION_MAPPING.md` | Mock → production mapping |
| `16_ARCHITECTURE_DECISIONS.md` | ADRs |
| `17_OPEN_DECISIONS.md` | Earlier open-decision list (historical; see `OPEN_QUESTIONS.md`) |
| `18_FINAL_BUSINESS_DECISIONS.md` | Locked V1 business rules |
| `19_DATABASE_REQUIREMENTS_FROM_FEATURES.md` | Must-support relationships when Postgres is built |

---

## Last re-analysis

**Date:** 2026-08-21 (final business-rule alignment)

Shared engines and Admin/Customer/Rider UI were aligned to the locked rules. There is still **no shared production database**. Live Customer→Rider→Admin row linking is **IMPLEMENTATION PENDING BACKEND**.

**Where to start:** `FINAL_MASTER_ANALYSIS.md` · `RULES_BOOK.md` · `18_FINAL_BUSINESS_DECISIONS.md`


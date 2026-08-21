# 01 — Project Overview

## 1.1 Project Name

**IDHAR UDHAR**

## 1.2 One-Line Summary

IDHAR UDHAR is a production-grade, multi-sided logistics platform that connects customers with verified delivery riders for on-demand parcel and goods transportation—similar in market positioning to Porter, optimized for the Indian urban logistics market.

## 1.3 Problem Statement

Urban customers and small businesses struggle to move goods quickly, affordably, and reliably. Existing options are fragmented: informal drivers lack tracking and trust; traditional transporters are slow and opaque; consumer courier apps are optimized for small packages only.

IDHAR UDHAR solves this by offering:

- Instant booking of the right vehicle for the load
- Transparent, distance- and vehicle-based fare estimation
- Live GPS tracking from pickup to drop
- Verified riders with document KYC
- Secure in-app payments and digital trip history

## 1.4 Solution

A three-product ecosystem:

| Product | Audience | Purpose |
|---------|----------|---------|
| **Customer App** | Individuals & SMBs | Book, pay, track, rate deliveries |
| **Rider App** | Delivery partners | Receive jobs, navigate, earn |
| **Admin Panel** (future) | Operations team | Manage users, bookings, payouts, offers |

All products share a common Firebase-backed backend, consistent domain models, and a unified design system derived from the IDHAR UDHAR brand identity.

## 1.5 Brand Identity Snapshot

| Attribute | Value |
|-----------|-------|
| Brand name | IDHAR UDHAR (“Here & There”) |
| Tagline | Delivering Trust, Every Time |
| Positioning | Fast · Safe · Reliable |
| Primary orange | `#FF6624` (energetic, action) |
| Primary navy | `#2E4072` (trust, professionalism) |
| Visual language | Premium glassmorphism + warm sunset logistics imagery |

## 1.6 Technology Snapshot

| Layer | Choice |
|-------|--------|
| Client | Flutter (latest stable) + Dart |
| UI | Material Design 3 + custom glass design system |
| State | Riverpod |
| Navigation | GoRouter |
| Backend | Firebase (Auth, Firestore, Storage, FCM, Crashlytics) |
| Maps | Google Maps, Places, Directions |
| Networking | Dio |
| Models | Freezed + Json Serializable |
| Local | Hive, Flutter Secure Storage, Shared Preferences |
| Media | Cached Network Image, Lottie, Google Fonts |

## 1.7 Architecture Principles

1. **Scalability first** — Firestore data models and indexes designed for growth to millions of users.
2. **Clear boundaries** — Feature-first Flutter modules; shared packages for design system and domain.
3. **Security by default** — Secure storage for tokens, Firestore security rules, least-privilege access.
4. **Offline resilience** — Critical booking and trip states cached; graceful degradation.
5. **Observability** — Crashlytics, structured logging, analytics hooks from day one.
6. **Admin-ready** — Collection schemas and status machines designed for a future Admin Panel without schema rewrites.

## 1.8 Success Metrics (Product)

| Metric | Target (Year 1 aspirational) |
|--------|------------------------------|
| Booking completion rate | ≥ 85% of accepted trips |
| Average time to first rider accept | < 3 minutes in launch cities |
| Customer NPS | ≥ 40 |
| Rider weekly active retention | ≥ 60% |
| Crash-free sessions | ≥ 99.5% |
| App Store / Play rating | ≥ 4.5 |

## 1.9 Document Map

This folder contains the complete pre-implementation specification. Read in order for onboarding; use individually as implementation references.

| # | Document | Purpose |
|---|----------|---------|
| 01 | Project Overview | This document |
| 02 | Product Vision | Vision, mission, positioning |
| 03 | User Personas | Customer, rider, admin personas |
| 04 | Feature List | Exhaustive feature inventory |
| 05 | Project Scope | In / out of scope |
| 06 | Functional Requirements | Detailed FR specs |
| 07 | Non-Functional Requirements | Performance, security, scale |
| 08 | User Flows | End-to-end journeys |
| 09 | System Architecture | High-level system design |
| 10 | Folder Structure | Flutter monorepo / multi-app layout |
| 11 | Database Architecture | Firestore collections & models |
| 12 | Firebase Architecture | Services, rules, functions |
| 13 | API Strategy | External + Cloud Functions APIs |
| 14 | State Management | Riverpod patterns |
| 15 | UI/UX Guidelines | Interaction & screen principles |
| 16 | Design System | Tokens from brand & UI refs |
| 17 | Animation Guidelines | Motion language |
| 18 | Navigation Architecture | GoRouter routes |
| 19 | Security Strategy | Auth, data, device |
| 20 | Error Handling | UX + technical error model |
| 21 | Offline Strategy | Cache & sync |
| 22 | Performance Strategy | App & backend performance |
| 23 | Testing Strategy | Unit, widget, integration, E2E |
| 24 | Git Workflow | Branching & PRs |
| 25 | Coding Standards | Dart / Flutter conventions |
| 26 | Project Roadmap | Timeline milestones |
| 27 | Development Phases | Phased implementation plan |
| 28 | Risk Assessment | Risks & mitigations |
| 29 | Future Enhancements | Post-MVP backlog |
| 30 | README | Developer entry point |

## 1.10 Explicit Non-Goals for This Documentation Phase

- No Flutter / Dart application code
- No Firebase rule or Cloud Function implementations
- No generated models, widgets, or UI screens
- No Admin Panel UI design implementation

Documentation only. Implementation begins after stakeholder sign-off on this package.

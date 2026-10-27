# Health & Fitness Data Integration

**Status:** research / decision draft
**Last checked:** 26 Oct 2026
**Scope:** collecting workouts, routes, heart rate, steps and related health data from Apple Health, Google Health Connect, wearables and other fitness apps into NubiSport.

> Prices and platform rules change often. Treat every number here as a list price checked on the date above, not a quote.

---

## 1. Goal

NubiSport should be able to:

- import runs/walks/rides recorded in other apps (Apple Watch, Garmin, Samsung Health, Strava, etc.);
- read heart rate, steps, calories, elevation and GPS routes when the source provides them;
- show imported activities in the existing feed/profile/activity detail;
- keep the user in control of permissions, sync and deletion.

The important product question is not “which SDK?” but:

1. Do we only need data that is already on the phone (Apple Health / Health Connect)?
2. Do we need cloud data from Garmin, WHOOP, Oura, Fitbit, etc. without building each integration?
3. Are we willing to pay per connected user for a normalized backend?

---

## 2. TL;DR

- **Start free, on-device.** Use the open-source `health` Flutter package (MIT) for Apple HealthKit + Android Health Connect. No vendor fee, no health data leaves the phone. This covers most iPhone/Apple Watch and Android/Samsung Health users.
- **Do not build on Google Fit.** Google stopped new Google Fit API sign-ups on 1 May 2024 and supports the Fit APIs only until the end of 2026. Health Connect is the replacement on Android.
- **Sahha is not free for production.** It has a 30-day trial and a sandbox with 25 development users, then plans start at **$299/month billed annually** (1,000 users included; $0.40 per extra user). The Flutter package is also a thin, low-usage wrapper; the main risk is vendor lock-in, not the package itself.
- **If we later need Garmin/Oura/WHOOP/Fitbit in one normalized API**, the realistic options are:
  - **Open Wearables** — MIT, self-hosted, free licence but you run it and register each provider;
  - **Sahha** — fastest “health scores” product, from $299/mo annual;
  - **Junction (formerly Vital)** — flat $300/mo for 1–500 connected users;
  - **Terra** — from $399/mo annual, credit-based;
  - **Rook / Spike / Thryve** — higher entry points, better for enterprise.
- **Recommendation for NubiSport now:** Phase 1 native `health` package behind a `HealthDataSource` interface. Design the abstraction so a paid aggregator can be added later without rewriting the activity layer.

---

## 3. Options at a glance

| Option | Type | Entry cost | Coverage | Fit for NubiSport |
|---|---|---:|---|---|
| **Apple HealthKit + Android Health Connect** via `health` | Free, MIT, on-device | $0 API | Data already written to the phone by other apps/watch | **Best MVP.** No backend, no vendor |
| `health_connector` | Free, MIT, on-device | $0 API | 143 typed data types, incremental sync, HealthKit/Health Connect | Strong alternative if we need sync/typed APIs |
| **Open Wearables** | Open source, self-host | $0 licence + hosting | Apple Health, Health Connect, Garmin, WHOOP, Oura, Strava, Polar, Suunto, Samsung, Ultrahuman, Google Health | Free aggregator path, but we operate it |
| **Validic Inform** | Free developer tier | $0 (limits) | 5 users, 5 cloud integrations, 90-day retention | Spike/testing only |
| **Sahha** | Paid API + Flutter SDK | $299/mo annual; $399 monthly | 800+ devices/165 integrations; derived scores/archetypes | Fastest if we need insights, not just raw data |
| **Junction (Vital)** | Paid API | $300/mo flat | 1–500 connected users, 300+ devices | Simple flat pricing for early scale |
| **Terra** | Paid API | $399/mo annual; $499 monthly | 300+ integrations, 100k credits/mo | Flexible, credit-based; gets expensive with many sources |
| **Rook** | Paid API | $399/mo Core (750 active users) | 300+ sources, scores/signals add-ons | Enterprise-ish; Core+ $999/5k users |
| **Spike** | Paid API | from $450/mo | 40+ providers/500+ devices | Enterprise sales process |
| **Thryve** | Paid API | from €499/mo (500 users) | Health data integrations; BAA on all plans | EU-oriented; higher entry |
| **Strava API** | Direct provider API | No separate API fee, but 2026 Standard Tier needs a Strava subscription | Strava activities only | Useful as one source, not an aggregator |
| **Google Fit API** | Deprecated | — | Legacy | Do not build new work on it |
| **Garmin / WHOOP / Oura / Fitbit direct** | Partner APIs | Varies / free with approval | One provider each | Too much work unless one source is a must |

---

## 4. Free options in detail

### 4.1 Apple HealthKit + Android Health Connect (recommended MVP)

Both platform stores are free to read from. The cost is engineering + platform review, not an API fee.

**Flutter bridge: `health` (`^13.3.2`, MIT, carp.dk/DTU)**

- Supports Apple Health on iOS and Health Connect on Android.
- Removed Google Fit support in v11.0.0 because Google deprecated it.
- Reads/writes: steps, heart rate, resting HR, sleep, workouts, workout routes, calories, distance, elevation-ish data, body metrics, etc.
- Android requirements:
  - Health Connect app installed and available.
  - Health Connect permissions declared in `AndroidManifest.xml` per data type.
  - Android 14+ requires `FlutterFragmentActivity`.
  - Historical reads default to 30 days; request `READ_HEALTH_DATA_HISTORY` for more.
  - Routes from other apps may require the user to manually allow “Exercise routes” in Health Connect.
- iOS requirements:
  - HealthKit capability + `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription`.
  - Device must be unlocked when reading.
- Maturity: ~230k downloads, ~682 likes, MIT.
- Good default: simple API, broad adoption, fewer build-system surprises.

**Alternative bridge: `health_connector` (`^3.14.0`, MIT)**

- 143 typed health data types, compile-time type safety.
- Incremental `synchronize()` with a sync token and deleted-record IDs — very useful for background sync.
- Reads/writes/deletes, aggregation, exercise sessions and routes.
- Requirements are stricter:
  - Flutter ≥ 3.38 / Dart ≥ 3.10
  - Android API 26+, Kotlin 2.1, `compileSdkExtension 19`
  - iOS 15+
- Maturity: ~1.93k downloads, ~24 likes. Newer, less battle-tested than `health`.
- Use this if typed APIs and incremental sync are worth the extra platform setup. Otherwise start with `health`.

**HealthKit/Health Connect limits to plan around**

- HealthKit read permission cannot be enumerated (iOS returns “unknown”); infer by trying a minimal read.
- On-device data only: no cloud access when the app is not running, unless background delivery/permissions are granted.
- A workout may exist in both Apple Health and Strava, and a phone and watch may both record steps. Deduplication is required.
- Health Connect does not expose every metric that HealthKit does (and vice versa).
- Samsung Health syncs to Health Connect on Android; it is not a direct NubiSport integration.
- App Store / Play Store require clear health-data purpose strings, privacy policy and permission justification. Vague descriptions get rejected.

### 4.2 Open Wearables (free licence, self-hosted)

- MIT-licensed wearable data infrastructure; no licence fee.
- Mobile SDK components for **Apple Health** and **Google Health Connect**; OAuth integrations for **Garmin, WHOOP, Oura, Strava, Polar, Suunto, Ultrahuman, Samsung Health, Google Health**, etc.
- You host it (Docker Compose), register developer credentials with each provider, and handle infrastructure, backups, security, and compliance.
- Enterprise support/BAA is paid; the software itself is free.
- Best if we want an aggregator schema but have backend capacity and want zero per-user licence.
- Not the fastest path if the team has no backend/ops capacity.

### 4.3 Validic Inform (free developer tier)

- Reported free developer plan: **5 users, 5 cloud integrations, 90-day retention**.
- Useful for a proof of concept, not a production launch.
- Verify current limits on Validic’s own page before relying on them.

### 4.4 Direct provider APIs (free-ish, but each is work)

- **Strava API:** no separate API fee, but in 2026 new Standard Tier developers need a Strava subscription. Default rate limit is 200 requests/15 min and 2,000/day. Activities/routes only; not full health data.
- **Garmin Health API:** partner application/approval; useful for Garmin-first users.
- **Fitbit Web API:** being sunset in 2026; use the Google Health API path instead.
- **WHOOP / Oura / Polar / Suunto / Withings:** OAuth partner APIs, each with its own approval, schema and token lifecycle.
- **Google Fit:** deprecated; do not start here. Migrate to Health Connect (on-device) or Google Health API (cloud).

---

## 5. Paid aggregators in detail

### Sahha

- **Trial/sandbox:** 30-day free trial; sandbox with 25 development users and all products unlocked.
- **Production:**
  - Starter: **$299/mo billed annually** (or $399 monthly), 1,000 users included, then $0.40/user, 30-day data retention, DPA GDPR, SOC 2.
  - Pro: **$1,499/mo annual** (or $1,999 monthly), 10,000 users, then $0.20/user, 120-day retention, HIPAA BAA.
  - Enterprise: custom.
- Coverage: 800+ devices / 165 integrations, Apple Health, Health Connect, Garmin, Fitbit, Oura, WHOOP, Samsung Health, Strava, etc.
- Value-add: 100+ biomarkers, scores (activity/sleep/readiness/wellbeing), archetypes, tags, insights. Phone alone works as a source.
- Flutter: `sahha_flutter` 1.4.0; pub score low (1 like, 110 points, ~474 downloads), unverified uploader, unknown license. The SDK is a client for the Sahha API, not an offline bridge.
- Watch out: production has no free tier; 30-day retention on Starter means we must store history ourselves.

### Junction (formerly Vital)

- **Launch:** **$300/mo**, billed monthly, 1–500 connected users, 300+ device integrations, Link widget, free sandbox.
- **Enterprise:** custom, annual, unlimited users, lab testing, SLA, BAA.
- Good middle ground if we want a flat early price and only need device data.
- Beyond 500 users requires sales/enterprise.

### Terra

- **Quick Start:** **$399/mo billed annually** or **$499/mo monthly**, 100,000 Unified API credits/month, 30-day money-back guarantee.
- Credits: each active authentication (one source for one user) costs 200 credits/month; first 400 events per source free; extra events 0.5 credits; extra credits from $0.005.
- 300+ integrations, mobile SDK (Flutter supported), normalized format, webhooks.
- Add-ons: Health Scores from $499/mo, Streaming, Planned Workouts, Graph API.
- BAA on Enterprise.
- Good if we need many sources per user and can manage credit math; multiple wearables per user increase cost.

### Rook

- **Core:** **$399/mo**, up to 750 active users.
- Core+: $999/mo, up to 5,000; Business: $1,999/mo, up to 15,000; Enterprise custom.
- Add-ons (health score, user profile, signals, notification webhooks, etc.) are paid on Core and partly on Core+.
- 12-month standard contract, 30-day cancellation.
- Sandbox available; production requires a plan.
- Better for a funded product than an MVP.

### Spike

- Sandbox starts from **$450/mo**, 40+ providers/500+ devices, dedicated implementation engineer.
- Enterprise custom.
- Higher entry point; sales-led.

### Thryve

- Start Up from **€499/mo**, 500 users, one app connection; €0.50 per extra user.
- 14-day trial; BAA on all plans.
- EU-focused; less relevant unless that market matters.

---

## 6. What “free” really means

“Free” usually means **no per-API-call fee**, not zero total cost:

- Apple/Google developer accounts and store review still apply.
- Someone must build and maintain permission flows, sync, dedupe, mapping and UI.
- Health data compliance is not free: privacy policy, consent, access/delete, encryption, retention, incident handling.
- Self-hosting Open Wearables means servers, backups, monitoring, secrets, provider registrations and security reviews.
- Free tiers (Validic 5 users) are proof-of-concept limits, not production.
- A paid aggregator removes provider integration labour, but not our storage, compliance, support or platform costs.

For NubiSport, the biggest hidden cost is **deduplication and data quality**, not the SDK license.

---

## 7. Recommended path for NubiSport

### Phase 1 — Native / free (now)

1. Add `health` (or `health_connector` after a spike) behind our own interface.
2. Start with workouts + route + distance + duration + calories + heart-rate summary.
3. Onboarding screen: explain what is read, why, and that data stays on device.
4. Settings → **Connected apps / Health**:
   - Apple Health / Health Connect status
   - Connect / reconnect
   - Last sync
   - Disconnect and delete imported data
5. Store the source ID and source name with every imported activity.
6. Show a small source badge: “Apple Health”, “Health Connect”, “Garmin”.
7. Keep `IS_MOCK=true` with a `MockHealthDataSource` so UI work does not need a real device.

This gets NubiSport users’ existing Apple Watch/Samsung Health runs without a monthly bill and without sending health data to a third party.

### Phase 2 — Aggregator (only if needed)

Add an aggregator when at least one is true:

- users ask for Garmin/WHOOP/Oura/Fitbit data that is not reaching HealthKit/Health Connect;
- we need server-side normalized scores (readiness, sleep, recovery) rather than raw samples;
- we do not want to maintain provider OAuth/approval ourselves.

Shortlist:

- **Open Wearables** if we can host and register providers; licence $0.
- **Junction** if ≤500 connected users and we want a flat $300/mo.
- **Sahha** if derived scores/archetypes are a product requirement; from $299/mo annual.
- **Terra** if multi-source per user and credit-based pricing fit.

Do not choose an aggregator before the native path is working: the native path is the fallback and the cheapest way to validate demand.

---

## 8. Proposed architecture

### Modules

```text
lib/features/health/
  domain/
    health_data_source.dart      # interface
    health_workout.dart          # normalized source-independent workout
    health_permission.dart
  data/
    platform_health_data_source.dart   # health / health_connector
    aggregator_health_data_source.dart # Sahha/Open Wearables later
    mock_health_data_source.dart
    health_data_source_provider.dart
  presentation/
    health_connect_page.dart
    health_connect_controller.dart
```

### Interface

```dart
abstract interface class HealthDataSource {
  Future<HealthAvailability> availability();
  Future<HealthPermissionResult> requestPermissions();
  Future<List<HealthWorkout>> fetchWorkouts({DateTime? since});
  Future<List<HealthSample>> fetchSamples({DateTime? since});
  Future<void> disconnect();
}
```

Keep the interface free of `health`, `health_connector` or Sahha types. That is what lets us swap vendors later.

### Mapping to the existing Activity model

| Health field | NubiSport `Activity` |
|---|---|
| `sourceId` / UUID | `sourceId` (new) + dedupe key |
| `sourceName` | `sourceName` (Apple Health / Health Connect / Garmin) |
| workout type | `ActivityType.run/walk/hike/ride` |
| start/end | `startedAt` + `duration` |
| distance | `distanceKm` |
| calories | `calories` |
| elevation | `elevationGainM` |
| route | `List<GeoPoint>` + first point as `latitude/longitude` |
| heart-rate summary | new fields (avg/max HR) |
| title | “Larian pagi” fallback; user can edit later |
| location | reverse geocode first point or “Apple Health” |

Extend `Activity` with `sourceId`, `sourceName`, maybe `avgHeartRate`, `maxHeartRate`, `rawSource`. Do not dump raw payloads into the activity.

### Sync and deduplication

- Dedupe key: `(userId, source, sourceId)`.
- Optional fuzzy match for cross-source duplicates: same user, start time within ±2 minutes, duration within ±3%, distance within ±5%.
- Store `lastSyncAt`/sync token per source.
- Fetch only records since the last sync; upsert and handle deletions.
- Refresh `myActivitiesProvider`, progress, feed after sync.
- Background sync:
  - iOS: HealthKit background delivery.
  - Android: Health Connect `READ_HEALTH_DATA_IN_BACKGROUND` + OS scheduling constraints.
- Never block the UI on sync; show sync state and errors.

### Privacy and compliance

- Explicit consent screen before the OS permission prompt; the OS prompt is not the onboarding.
- Purpose strings: say exactly what is read and why.
- Data minimisation: request workouts/routes/HR first; steps/sleep only when needed.
- On-device first; if using an aggregator, disclose that health data leaves the device and name the processor.
- Support access, export and deletion; deleting the NubiSport account should delete imported health data.
- Tokens in secure storage; encrypt local DB; avoid health data in logs/analytics.
- Malaysia PDPA and app-store health-data rules apply; get legal review before production.
- Aggregator choice must include a DPA; HIPAA BAA only if we are a covered entity/business associate (not automatically required for a Malaysian consumer app).

---

## 9. UI touchpoints

- **Settings** → `Connected apps` / `Health & fitness` (new row).
- **Health connect page**:
  - Apple Health / Health Connect card with status.
  - What we read and why.
  - Connect / manage permissions.
  - Last sync + manual sync.
  - Imported activity count.
  - Disconnect + delete imported data.
- **Onboarding** after first login: optional “Import your runs” card; never auto-prompt on launch.
- **Activity detail**: source badge and “Imported from …”.
- **Feed/profile**: imported activities look identical, with a small source label.

---

## 10. Risks and open questions

- Sahha Flutter package risk: low adoption, unverified uploader, unknown license. Prefer calling their REST API via our own data source, or use the official SDK only after a spike.
- Paid aggregators charge per connected user, not MAU. Budget for growth.
- Sahha Starter retains 30 days; Terra/Rook/others have different retention. We still need our own history.
- Health Connect historical access is 30 days by default; request history permission and explain it.
- HealthKit read permissions are opaque on iOS; UX must handle “unknown” and re-request.
- Routes from third-party apps may not be available unless the user allows exercise routes.
- Google Fit is being retired; Fitbit Web API is being sunset. Do not add new dependencies on either.
- Apple Watch users may have data only in Apple Health; Android watch users may have data only in Health Connect. Native covers both.
- If we later add a paid aggregator, the mapping/dedupe work still remains ours.
- Pricing changes: re-check vendor pages before signing.

### Decision questions

1. Is the first release iOS-only, Android-only, or both?
2. Do we need routes and heart rate on day one, or only distance/duration?
3. Are Garmin/WHOOP/Oura users a must-have for launch?
4. Do we need server-side health scores, or can the app compute from raw data?
5. Can we operate Open Wearables (backend + provider registrations + security), or do we prefer a managed vendor?
6. What is the monthly budget at 1,000 / 5,000 connected users?

---

## 11. Sources

Checked 26 Oct 2026:

- [Sahha pricing](https://sahha.ai/pricing/)
- [Sahha homepage / coverage & sandbox](https://sahha.ai/)
- [sahha_flutter on pub.dev](https://pub.dev/packages/sahha_flutter)
- [Terra pricing](https://tryterra.co/pricing)
- [Junction pricing](https://www.junction.com/pricing)
- [ROOK pricing](https://tryrook.io/pricing/)
- [Open Wearables pricing](https://openwearables.io/pricing)
- [Open Wearables integrations](https://openwearables.io/integrations/)
- [Health data aggregator pricing comparison (AIFitnessAPI, 17 Oct 2026)](https://aifitnessapi.com/pricing/health-data-aggregator-pricing)
- [health package on pub.dev](https://pub.dev/packages/health)
- [health_connector package on pub.dev](https://pub.dev/packages/health_connector)
- [Google Fit → Health Connect migration](https://developer.android.com/health-and-fitness/health-connect/migration/fit)
- [Strava API rate limits](https://developers.strava.com/docs/rate-limits/)
- [Strava developer program changes 2026](https://appsforstrava.com/blog/strava-developer-program-changes-2026)
- [Strava developer program update](https://communityhub.strava.com/insider-journal-9/an-update-to-our-developer-program-13428)
- [Validic Inform free developer tier (announcement)](https://validic.com/blog/Validic-Inform-Is-Now-Free/)

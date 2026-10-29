# Training plans on web + app (one generator, cloud-synced)

Date: 2026-10-29 · Repos: `nubisport-astro` (web), `hono-workers` (API), `nubisport-flutter` (app)

## Why

A member must be able to create, update, follow and tick a training plan on **either** the web or the
app, in any mix, and see the same plan and the same ticks on both. Today only the web can: the plan is
generated in the browser (`src/lib/plan-5k.ts`, `src/lib/distance-plan.ts`, engine v2), and the cloud
(`/me/apps/nubi/plan`) stores only the inputs, the tick tokens (`"<week>.<sessionIndex>"`) and the
engine version. A tick means nothing without regenerating the exact same plan. The app has its own
simplified 5K-only generator, so its sessions don't line up with the web's.

## Goals

- One generator. The same inputs give the same weeks/sessions on web and app.
- App can: list cloud plans, create (5K / 10K / 21K / 42K, same inputs as the web forms), update
  (ticks follow the same sessions, like the web's `remapProgress`), view weeks with dates, tick/untick,
  set active, set/clear walk mode, delete.
- Existing cloud plans open unchanged on both platforms with their ticks. No data migration.
- Web behaviour unchanged, including signed-out users (localStorage plans) and offline use.

## Non-goals

- Auto-ticking sessions from Strava activities stays on the web (it runs at upload, which is web-only).
  The app sees those ticks through the cloud.
- Offline plan use in the app (v1 needs network; a failed tick rolls back with a message).
- Session timer (`timer.ts`), MAF calculator, AI plan tools, plan-quality analysis in the app.
- Changing the generator's training logic, quotas, or the stored format.

## Anti-goals (a failure even if it "works")

- Any write from the app that changes `data`/`progress`/`engine` in a way the web reads differently.
- A second hand-written copy of the generator (the old Dart one is deleted, not ported).
- Breaking a web importer of the plan libs.

## Design

### 1. The generator lives in the backend; the web keeps a generated copy

Owner decision (2026-10-29): `hono-workers/src/services/nubi-plan/engine/` holds the source of
`plan-5k.ts`, `distance-plan.ts`, `date.ts`, `maf.ts`, `plan-core.ts` and their pure checks.
`hono-workers/scripts/sync-plan-engine.ts` copies them into `nubisport-astro/src/lib/` with a
"generated, do not edit" header (`--check` reports drift). The web keeps running its copy in the
browser (offline + signed-out unchanged). The extraction below was done first in the web, then moved.

#### 1a. Extraction (done in the web, before the move)

- Extract the DOM-free parts that turn inputs into a plan into one pure module
  `src/lib/plan-core.ts`: `planFromParams`, `planSessionDate`, `planSessions` (from `plan-sync.ts`),
  `normalize` / `planKeyFor` / the validation part of `previewPlan` (from `plan-save.ts`),
  `planKey`, `distancePlanKey`, `paramsFromKey`, `remapProgress`, `planParams` (from `saved-plans.ts`),
  and `ENGINE_VERSION` (from `cloud-sync.ts`). The old files re-export them, so no importer changes.
  `plan-core.ts` may import only `plan-5k.ts`, `distance-plan.ts`, `date.ts`, `maf.ts`.
- New `scripts/sync-plan-engine.ts`: copies `plan-5k.ts`, `distance-plan.ts`, `date.ts`, `maf.ts`, `plan-core.ts`
  verbatim into `../hono-workers/src/services/nubi-plan/engine/`, prefixed with a "generated, do not
  edit — run `bun scripts/sync-plan-engine.ts` in nubisport-astro" header. `--check` exits non-zero
  when the copies differ (run it with the other `check-plan-*` scripts).
- Rule (documented in both repos): any change to these five files = run the sync and deploy the API
  together; a change to session structure still bumps `ENGINE_VERSION` as today.

### 2. API builds plans (`hono-workers`)

`POST /api/v1/me/apps/nubi/plan-build` (jwtAuth, Nubi session, `account.read`; mounted before
`/me/apps` like the other `nubi/*` routes). Pure CPU, no DB.

Request:
```json
{ "kind": "5k|10k|21k|42k", "params": { "...": "string" }, "key": "existing key (update) | absent",
  "previous": { "params": {}, "progress": ["3.1"] }, "walkUntil": "YYYY-MM-DD | null" }
```
Response 200:
```json
{ "success": true, "data": { "engine": 2, "key": "pelan-10k:...", "params": { }, "amaran": [],
  "progress": ["3.1"],
  "weeks": [ { "no": 1, "fasa": "Asas", "ringan": false, "minit": 95,
    "sesi": [ { "id": "1.0", "tarikh": "2026-11-02", "jenis": "mudah", "minit": 30, "tajuk": "...",
                "arahan": "...", "usaha": "...", "walk": false } ] } ] } }
```
- `params` = normalized params (what to store in `data`); `key` = `planKeyFor` (or the given key).
- `progress` present only when `previous` was sent: `remapProgress(previous.progress, old, new)`.
- `tarikh` is null when there is no `mula` (start date) — same as the web.
- 400 `{ success:false, error: sebab, cadanganBulan?, cadanganMinggu? }` when the engine refuses the
  inputs (the web shows the same `sebab`).
- Heart-rate inputs: when `params.umur` + `params.keadaan` are set, compute `nadi` with `calcMaf`
  (`maf.ts`) and pass it to the builder, exactly as `Plan5k.astro:389` / `DistancePlan.astro:348` do;
  a `calcMaf` refusal is a 400 with "Ikut nadi: <sebab>". (`planFromParams` today omits `nadi`, so the
  web's dashboard/active-plan path shows plain text; only the session text differs, never the ids.)
- Validation at the boundary: `kind` enum, `params` same shape rules as `validators/app-items.ts`
  (≤20 string keys, values ≤100 chars), `progress` same token regex, body ≤ 16 KB.
- A test script (`scripts/verify-nubi-plan-build.ts`, like the other `verify-*`) checks: a known
  5K and 10K input gives the same week/session count and ids as the web check scripts; remap keeps a
  tick on the same session when days go 3 → 4; bad inputs give 400.

Saving, ticking, active plan and walk mode use the **existing** endpoints unchanged
(`GET /me/apps/nubi/plan` → `{ limit, items: [{ key, engine, data, progress, updatedAt }] }`;
`GET /me/apps/nubi/active` → `items[0].data = { plan, jalan? }`):
`GET/PUT/DELETE /me/apps/nubi/plan[/:key][?replace=]` (`{engine, data, progress}`, 409 = quota full)
and `PUT /me/apps/nubi/active/plan` (`{engine, data: {plan, jalan?}, progress: []}`).

### 3. App (`nubisport-flutter`)

- `features/plans/data`: `PlanRepository` (Dio, same pattern as activities) over the endpoints above,
  plus a mock for `IS_MOCK`.
- Screens: plan list (cloud plans + quota `n/limit`, active badge) → plan view (weeks, dated sessions,
  tick boxes, set active, walk mode 7/14 days / extend 7 / end, update, delete) → plan form (kind,
  then the same fields as `Plan5kForm.astro` / `DistancePlanForm.astro`, race date or weeks/months,
  optional own pace and start date; `pemula` is a form-only toggle that hides `masa`, never stored;
  preview via `plan-build` before saving). Prefill from `nubi/profil`
  when present (read only).
- Ticks: optimistic; the full progress list is PUT after a 1.5 s debounce (same as the web);
  failure rolls back and shows a SnackBar. Quota full on create → offer to replace a plan (`?replace=`).
- A saved plan whose `engine` differs from the API's → shown read-only with "Buka di web untuk
  sambung" (the web's `activePlanState` "enjin" case).
- Delete `lib/features/plans/domain/training_plan.dart`'s generator and its test.

## Constraints

- Stored format, keys, quotas and `ENGINE_VERSION` semantics stay exactly as today.
- Workers runs in UTC; the engine does date-only maths on local `Date`, so results match the browser
  for the same `mula`/`lumba`. `todayMY` is already timezone-explicit.
- App copy in Malay, matching existing screens.

## Builder's calls (decided by Claude, not the owner)

- Engine copied into the API by a sync script, not shared as a package (no publish step, no CI
  coupling between repos).
- Build on request, not stored as a snapshot (`app_items` caps `data` at 2000 chars; a stored plan
  would also stop engine fixes from reaching old plans, which the web relies on today).
- Last write wins on progress, like web-to-web today; two devices ticking within ~1.5 s can drop one tick.

## Left to the builder

Widget layout and navigation inside the plans feature; exact error copy; whether the list screen
calls `plan-build` for a session count or shows only `progress.length`.

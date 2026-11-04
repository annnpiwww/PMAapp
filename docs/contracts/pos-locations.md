# Contract: POS locations in Supabase

Goal: locations live in Supabase so new locations need no APK build. SPV manages them in-app; technician-added and legacy device-local locations are imported once.

## 1. Table `public.pos_locations`

| column | type | rule |
|---|---|---|
| pos_id | text PK | `^[A-Za-z0-9_-]{3,60}$` (app generates `<prefix><uuid6>` lowercase hex) |
| pos_name | text not null | 1..120 chars |
| cabang_name | text not null | 1..120 chars |
| full_address | text not null default '' | ≤ 300 chars |
| location_tag | text not null | 1..16 chars, uppercase |
| tag_color | bigint not null default 4294286859 | ARGB int (0xFFF59E0B) |
| branch | text not null | `manado` \| `bali` \| `ho` (= `AppBranch.name`) |
| lat | double precision not null | -90..90 |
| lng | double precision not null | -180..180 |
| active | boolean not null default true | soft delete flag |
| source | text not null default 'seed' | `seed` \| `spv` \| `device_import` |
| updated_by | text null | identity of SPV |
| created_at / updated_at | timestamptz default now() | updated_at bumped on update |

RLS enabled. Only policy: `SELECT` for `anon, authenticated` where `active = true`. No insert/update/delete grants for anon/authenticated. All writes go through the Edge Function with the service role.

Seed: every entry of `LocationService._defaultSeed` (`lib/data/services/location_service.dart:161`), source `seed`, `ON CONFLICT (pos_id) DO NOTHING`.

## 2. Edge Function `pos-locations` (POST JSON, CORS like `ai-vision`)

| action | body | auth | effect |
|---|---|---|---|
| `upsert` | `{action, identity, password, location}` | SPV | upsert by pos_id, `source='spv'`, `active=true`, `updated_by=identity` |
| `delete` | `{action, identity, password, pos_id}` | SPV | `active=false` (soft delete) |
| `import` | `{action, locations: [...]}` (≤ 50) | none | insert only, `ON CONFLICT (pos_id) DO NOTHING`, `source='device_import'` |

`location` / `locations[]` items use the table column names (snake_case) minus `active/source/updated_by/created_at/updated_at`.

SPV check (server-side, service role): find one `app_users` row where `username`, `email` or `nama` equals `identity` case-insensitively (exact, no partial match); password equal case-insensitively after trim; `lower(role) = 'spv'`.

Responses: `200 {"ok":true,"count":n}` · `400 {"error":"invalid"}` · `401 {"error":"unauthorized"}` (bad identity/password) · `403 {"error":"forbidden"}` (not SPV) · `413` body > 64 KB · `500 {"error":"server error"}` (never leak DB errors).

## 3. Dart API (`lib/data/services/location_service.dart`)

```dart
enum RemoteWriteResult { ok, invalidCredentials, notSupervisor, offline, failed }

class PosLocation {
  final AppBranch? explicitBranch; // from DB `branch`; when set, matchesBranch() uses it first
  Map<String, dynamic> toRemoteJson();
  factory PosLocation.fromRemoteJson(Map<String, dynamic> json);
}

class LocationService {
  /// GET active rows, replace local list, keep + queue local-only rows for import, persist. Never throws.
  static Future<bool> syncFromRemote();
  /// SPV write. On ok also updates the local list. Never stores the password.
  static Future<RemoteWriteResult> saveLocationRemote(PosLocation pos, {required String identity, required String password});
  static Future<RemoteWriteResult> deleteLocationRemote(String posId, {required String identity, required String password});
}
```

`addLocation` (picker, task auto-create) stays local-first and queues the location for `import`; the queue is persisted and flushed on the next `syncFromRemote`. Offline: last cached list; first install offline: `_defaultSeed`.

HTTP status to result: 200 ok · 401 invalidCredentials · 403 notSupervisor · SocketException/Timeout offline · anything else failed.

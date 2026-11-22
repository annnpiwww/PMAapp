# Contract: PMApp In-App Releases (`app-releases`)

Owner: coder (`supabase/migrations/2026-11-22_app_releases.sql`, `supabase/functions/app-releases/`, `tools/publish_release.mjs`).  
Scope: `pmapp` **prod** (`com.bssparking.timemark.bssparking_timemark`) only. Demo flavor is out of scope.

---

## 1. Authorized Publishers (`RELEASE_PUBLISHER_UIDS`)

Admin actions (`list`, `create_upload`, `publish`, `rollback`, `delete_draft`) require a valid `x-app-session` token whose `session.uid` is listed in the Supabase Edge Function secret `RELEASE_PUBLISHER_UIDS` (comma-separated; empty secret denies all).

- **Active allowlist**:
  - `farhan` (`Farhan Lakoro`, SPV Manado)
- **Pending addition**:
  - Aan (owner) does not yet have a dedicated `public.app_users` row; once created, append Aan's `app_users.id` to `RELEASE_PUBLISHER_UIDS` via `supabase secrets set`.

---

## 2. Database & Storage Model

- **Table `public.app_releases`**:
  - RLS enabled with **no** `anon`/`authenticated` policies; all grants revoked from `anon`/`authenticated`; `service_role` only.
  - Unique `(app, abi, version_code)`.
  - Enforce `version_code = base_version_code + offset` (`armeabi-v7a`: `+1000`, `arm64-v8a`: `+2000`, `x86_64`: `+4000`), `size_bytes <= 52428800` (50 MiB), lowercase hex64 `sha256`, semver `X.Y.Z` for `version_name` and optional `min_supported_version`.
  - Status lifecycle: `draft` -> `published` -> (`rolled_back` | `archived`).
- **Bucket `app-releases`**:
  - Private (`public = false`), `52428800` byte limit, MIME types `application/vnd.android.package-archive`, `application/octet-stream`.
  - Server-generated object path: `prod/<version_code>-<abi>.apk` (caller-supplied paths are ignored).

---

## 3. Edge Function API (`POST /functions/v1/app-releases`)

All requests require `apikey: <anonKey>` and `Authorization: Bearer <anonKey>`.  
`verify_jwt = false` in `supabase/config.toml` (custom HMAC `x-app-session` auth).

### 3.1 `latest` (Public — NO `x-app-session` required)

Allows logged-out devices and mandatory updates to check for updates.

- **Request**:
  ```json
  {
    "action": "latest",
    "abi": "arm64-v8a",
    "current_code": 4153,
    "current_version": "2.0.140"
  }
  ```
- **Response (`200 OK`, no newer release)**:
  ```json
  { "update": false }
  ```
- **Response (`200 OK`, newer release available)**:
  ```json
  {
    "update": true,
    "mandatory": false,
    "release": {
      "id": "uuid",
      "version_name": "2.0.141",
      "version_code": 4154,
      "size_bytes": 24926834,
      "sha256": "<64-char-hex>",
      "changelog": "..."
    },
    "download_url": "<signed-url-ttl-900s>"
  }
  ```
  `mandatory` is `true` when `release.mandatory` is `true` **or** `min_supported_version != null && compareSemver(current_version, min_supported_version) < 0`.

### 3.2 `list` (Publisher allowlist)

- **Request**: `{ "action": "list" }`
- **Response (`200 OK`)**: `{ "releases": [ ... ] }` (newest first; omits `apk_path` and signed URLs).

### 3.3 `create_upload` (Publisher allowlist)

- **Request**:
  ```json
  {
    "action": "create_upload",
    "abi": "arm64-v8a",
    "base_version_code": 2154,
    "version_code": 4154,
    "version_name": "2.0.141",
    "sha256": "<64-char-hex>",
    "size_bytes": 24926834,
    "changelog": "Baseline 2.0.141",
    "mandatory": false,
    "min_supported_version": null
  }
  ```
- **Response (`201 Created`)**:
  ```json
  {
    "id": "uuid",
    "upload": {
      "path": "prod/4154-arm64-v8a.apk",
      "token": "...",
      "signedUrl": "..."
    }
  }
  ```
- Rejects with `409` if `version_code <= max(version_code)` for that ABI across **all** statuses (`versionCode` can never decrease).

### 3.4 `publish` (Publisher allowlist)

- **Request**: `{ "action": "publish", "id": "<uuid>" }`
- Verifies `status = 'draft'`, downloads object from `app-releases` bucket via `service_role`, verifies byte length and SHA-256 match `size_bytes` and `sha256` (`422 hash_mismatch` or `422 upload_missing` otherwise, keeping draft).
- Sets `status = 'published'`, `published_at = now()`.
- **Retention**: For the same `abi`, every other row with `status in ('published', 'rolled_back')` and `version_code < this.version_code` has its storage object removed, `apk_path` set to `null`, and `status` set to `'archived'`. Metadata rows are kept as history.
- **Response (`200 OK`)**: `{ "release": { ... }, "archived_count": 0 }`

### 3.5 `rollback` (Publisher allowlist)

- **Request**: `{ "action": "rollback", "id": "<uuid>" }`
- Transitions `published` -> `rolled_back` (keeps storage object).
- **Important**: `rollback` **hides** a release from `latest` checks so no new devices download it. Android enforces monotonic `versionCode` and will not downgrade an already-installed APK; a real rollback for already-updated devices requires rebuilding the previous code with a **higher** `versionCode` and publishing it.
- **Response (`200 OK`)**: `{ "release": { ... } }`

### 3.6 `delete_draft` (Publisher allowlist)

- **Request**: `{ "action": "delete_draft", "id": "<uuid>" }`
- Deletes a `draft` row and best-effort removes its storage object.
- **Response (`200 OK`)**: `{ "deleted": true, "id": "<uuid>" }`

### 3.7 Error Codes

| HTTP | `error` | Meaning |
|---|---|---|
| `400` | `invalid` / `invalid action` | Malformed JSON, missing/invalid fields (`errors` map) |
| `401` | `unauthorized` | Missing, invalid, or expired `x-app-session` (admin actions) |
| `403` | `forbidden` | Valid session not in `RELEASE_PUBLISHER_UIDS` |
| `404` | `not_found` | Release `id` does not exist |
| `405` | `method not allowed` | Non-POST/OPTIONS request |
| `409` | `version_code_must_increase` / `duplicate` / `not_draft` / `not_published` | Monotonic version violation or invalid state transition |
| `413` | `payload too large` | Request body > 32 KB |
| `422` | `upload_missing` / `hash_mismatch` | Object absent or SHA-256/size mismatch during `publish` |
| `500` | `server error` | Unexpected backend/storage failure (details logged server-side only) |

---

## 4. Release Publish Procedure

1. Store publisher credentials in `~/.config/pmapp-release.env` (never committed):
   ```env
   PMAPP_RELEASE_USER=<username>
   PMAPP_RELEASE_PASSWORD=<password>
   ```
2. Build split-per-ABI release APKs:
   ```bash
   flutter build apk --release --split-per-abi
   ```
3. Dry-run to inspect computed `version_code`, size, and SHA-256:
   ```bash
   node tools/publish_release.mjs --changelog "Release notes" --dry-run
   ```
4. Publish `arm64-v8a` and `armeabi-v7a` APKs:
   ```bash
   node tools/publish_release.mjs --changelog "Release notes" [--mandatory] [--min-version x.y.z]
   ```

---

## 5. Per-branch rollout (`target_cabang`)

Staged rollout: publish to one branch (e.g. Manado) first, then widen to all.

- **Column**: `app_releases.target_cabang text[] null`. `null` = all branches. Allowed values (normalized, lowercase): `manado`, `bali`, `ho`. Non-null array must be non-empty, deduped, sorted.
- **Normalization** (server `normalizeCabang`, same aliases as `lib/data/services/branch_service.dart` `_appBranchFromDbKey`): `manado|kc manado|mdo` -> `manado`, `bali|kc bali|dps` -> `bali`, `ho|ho makassar` -> `ho`, anything else -> `null` (unknown).
- **`latest`**: still public. When a valid `x-app-session` is sent, caller branch = `normalizeCabang(session.cabang)`; otherwise (no/invalid/expired session, unknown cabang) caller branch = `null`. Picks the highest `version_code` published row for the ABI where `target_cabang is null` OR (caller branch != null AND `target_cabang @> [caller branch]`). Invalid session on `latest` never returns 401; it is treated as logged out. Response shape unchanged.
- **Client**: `checkLatest` sends `x-app-session` when `AuthRepository.instance.sessionToken` is non-empty.
- **`create_upload`**: optional `target_cabang: null | string[]` (default `null`). Invalid value -> `400 invalid` with `errors.target_cabang`.
- **`list`** / publish / rollback / set_targets responses include `target_cabang`.
- **`publish` retention**: runs ONLY when the published row has `target_cabang = null`. A branch-targeted publish never archives older releases (other branches still need them).
- **`set_targets`** (publisher allowlist, new): `{ "action": "set_targets", "id": "<uuid>", "target_cabang": null | ["manado", ...] }`. Allowed when `status in ('draft','published')` else `409 not_editable`. Updates the row; when the row is `published` and new value is `null`, runs the same retention as `publish`. Response `200 { "release": { ... }, "archived_count": n }`.
- **Publish script**: `tools/publish_release.mjs --cabang manado[,bali]` (omit = all branches). Applied to both ABIs.
- **Admin UI**: upload form (A2) has branch choice `Semua cabang` (default) / `Manado` / `Bali` / `HO` (multi-select chips; selecting a branch clears `Semua`, clearing all returns to `Semua`). Release list (A1) shows a target badge (`Semua cabang` or `Manado, Bali`) and, on a published targeted release, action `Rilis ke semua cabang` (confirm dialog) -> `set_targets` with `null`.

---

## 6. Storage Backend

- **Column**: `app_releases.backend text not null default 'supabase'` with check constraint `backend in ('supabase', 'r2')`. Existing rows remain `'supabase'`.
- **New uploads**: `create_upload` always inserts `backend = 'r2'` and returns a SigV4 presigned `PUT` URL (`X-Amz-SignedHeaders=host`, TTL 900s) targeting Cloudflare R2 bucket `pmapp` (object key `prod/<version_code>-<abi>.apk`). Clients (`tools/publish_release.mjs`, `AppReleaseAdminService`) `PUT` directly to `upload.signedUrl` unchanged.
- **Secrets**: `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` live only in the `app-releases` Edge Function environment; never shipped to clients or logged.
- **Downloads (`latest`)**: Routes per row `backend` — `'r2'` returns a presigned R2 `GET` URL (TTL 900s), `'supabase'` keeps returning a Supabase Storage signed URL until retention archives the row. Public `latest` response shape is unchanged and never exposes `backend`.
- **Verification, retention & draft cleanup**: `publish` downloads bytes from the row's `backend` (`r2` or `supabase`) before SHA-256/size verification. `runRetention` and `delete_draft` delete objects from each row's matching backend (logging and continuing on best-effort delete errors).


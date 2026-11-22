# PMApp Self-Updater P0 Audit

Read-only baseline audit for PMApp in-app self-update design (P1 backend, P3 Android client). Current app version: `2.0.141+2154` (`pubspec.yaml:23`).

---

## 1. APK Signing & Keystore Risk

`android/keystore.properties` does **not** exist (`ls: android/keystore.properties: No such file or directory`).

### (a) `android/app/build.gradle.kts` Signing Block (`:47-68`)

```kotlin
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("keystore.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug") // honey: fallback debug only for local run, CI must provide keystore.properties
        }
    }
```

### (b) Machine Debug Keystore Fingerprint

From `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey` (password omitted):
- **Alias**: `androiddebugkey` (valid `2026-08-23` to `2056-08-15`)
- **SHA-1**: `88:4C:9D:D7:68:D6:80:01:AF:A2:FE:7A:62:A4:56:AF:C1:F8:F4:76`
- **SHA-256**: `F1:58:A6:4F:E3:00:37:18:62:58:A9:AF:65:09:C4:E4:1E:C5:F1:F2:38:5C:CA:E6:AB:87:05:65:08:42:EC:E9`

### (c) Built APK Verification (`apksigner verify --print-certs`)

Verified all APKs under `build/app/outputs/flutter-apk/*.apk` (including `2.0.141` `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk`, universal `app-release.apk` `2.0.131`, and `PMA-App-v2.0.119..134`):
- **Signer #1 DN**: `C=US, O=Android, CN=Android Debug`
- **SHA-256 digest**: `f158a64fe30037186258a9af6509c4e41ec5f1f2385ccae6ab8705650842ece9` (100% match with `(b)`)

### (d) Other Keystores (`find . ~/.config ~ -maxdepth 3`)

Only one keystore file exists:
- `/home/annnpii/.android/debug.keystore` — SHA-256 `F1:58:A6:4F:E3:00:37:18:62:58:A9:AF:65:09:C4:E4:1E:C5:F1:F2:38:5C:CA:E6:AB:87:05:65:08:42:EC:E9`

### (e) Conclusion & Recommendation

- **Field APKs carry the machine's Android debug key (`F1:58:...`)**.
- **Keep using this exact key for all future PMApp builds.** Do **not** switch to a new release keystore: Android enforces signing-certificate continuity on updates; changing keys causes `INSTALL_FAILED_UPDATE_INCOMPATIBLE` and forces manual uninstall (wiping local `SharedPreferences`/session/history).
- **Critical backup risk**: `~/.android/debug.keystore` lives outside the repo on a single developer machine. If this machine or `~/.android/debug.keystore` is lost/reinstalled, seamless in-app updates break permanently for all field devices. Back up `~/.android/debug.keystore` to secure encrypted storage immediately, and optionally wire `android/keystore.properties` (gitignored) to a permanent backed-up copy.

---

## 2. Flavors & `applicationId`

`android/app/build.gradle.kts` does **not** define `productFlavors {}` blocks; instead it switches `applicationId` in `defaultConfig` via Gradle property `isDemo` (`:26-40`, `:79-82`):

```kotlin
    defaultConfig {
        val isDemo = project.findProperty("isDemo") == "true"
        if (isDemo) {
            applicationId = "com.bssparking.timemark.demo"
            manifestPlaceholders["applicationLabel"] = "PMA Demo"
        } else {
            applicationId = "com.bssparking.timemark.bssparking_timemark"
            manifestPlaceholders["applicationLabel"] = "PMA App"
        }
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
...
val isDemo = project.findProperty("isDemo") == "true"
if (!isDemo) {
    apply(plugin = "com.google.gms.google-services")
}
```

- **Release build command** (`specs/REL-2140-coder.json:26`, `specs/REL-2141-coder.json:31`, `CHANGELOG.md:5-20`): `flutter build apk --release --split-per-abi` (no `-PisDemo=true`, so prod is always built).
- **Shipped `applicationId`** (`aapt2 dump badging` on `2.0.141` and `2.0.119..134` APKs): `com.bssparking.timemark.bssparking_timemark`.
- **Observed `--split-per-abi` `versionCode` offset** (`pubspec.yaml:23` base `2154`):
  - `app-armeabi-v7a-release.apk`: `versionCode='3154'` (`+1000`)
  - `app-arm64-v8a-release.apk`: `versionCode='4154'` (`+2000`)
  - `app-x86_64-release.apk`: `versionCode='6154'` (`+4000`)
  - Universal `app-release.apk` (`2.0.131+2144`): `versionCode='2144'` (`+0`)

---

## 3. Supabase Client & Auth Model

- **Supabase init**: App does **not** use `supabase_flutter` or `Supabase.initialize`. `DailyTaskService` (`lib/data/services/daily_task_service.dart:47-49,160-216`) uses `package:http` directly with `baseUrl` (`SharedPreferences` `custom_supabase_url` -> `--dart-define=SUPABASE_URL` -> default project URL) and `anonKey` (`custom_supabase_anon_key` -> `--dart-define=SUPABASE_ANON_KEY` -> embedded default anon key; value omitted).
- **Login flow**: `AuthRepository.loginWithPassword` (`lib/data/repositories/auth_repository.dart:212-327`) POSTs `{identity, password}` to `/functions/v1/auth-login` (`supabase/functions/auth-login/index.ts:132-336`). `auth-login` queries `public.app_users` using `SUPABASE_SERVICE_ROLE_KEY`, verifies PBKDF2-SHA256 (`password_hash`, migrating legacy plaintext on first match), and issues a signed HMAC-SHA256 session token (`signSession`, `supabase/functions/_shared/session.ts:52-79`, signed with `APP_SESSION_SECRET`, format `v1.<b64url(payload)>.<b64url(sig)>`, 30-day TTL).
- **Client session state**: Token is persisted in `SharedPreferences` under `bss_session_token_v1` (`auth_repository.dart:18,297`) and sent on Edge calls via `x-app-session` alongside `apikey` and `Authorization: Bearer <anonKey>` (`daily_task_service.dart:210-216`, `docs/contracts/app-session.md:24`).
- **Edge function verification**: Shared helper `verifySession(req)` in `supabase/functions/_shared/session.ts:82-130` validates `x-app-session` signature and `exp`; imported by `admin-accounts`, `daily-tasks`, `pos-locations`, `ai-vision`, `sheets-sync`, and `push-register`.
- **Roles & checks**:
  - `auth-login/index.ts:116-130` normalizes `app_users.role` into `'spv'` (from `spv`, `supervisor`, `ho`, `headoffice`), `'admin_pos'`, or `'technician'`.
  - Flutter client (`auth_repository.dart:259-269`, `lib/data/models/user_model.dart:1-29`) blocks `'admin_pos'` (web `/lapor/` only), maps `'spv'|'supervisor'|'ho'|'headoffice'` to `UserRole.supervisor`, else `UserRole.petugas`.
  - Server privilege helper `isSpv(session)` (`_shared/session.ts:132-134`, `session.role === 'spv'`) gates privileged mutations in `admin-accounts/index.ts:74`, `pos-locations/index.ts:244,306`, and `daily-tasks/index.ts:68`.
- **Release publish authorization**: Gate release upload/publish/rollback edge function(s) with `verifySession(req)` + `isSpv(session)` (never expose `service_role` in the app; never accept `technician` or `admin_pos`). Optionally cross-check `app_users` if publish must be restricted to `HO` / specific `uid`s rather than all branch SPVs.

---

## 4. Supabase Storage, RLS & Free Tier Limits

- **Existing buckets**: Only `task-proofs` is referenced in code/migrations (`lib/data/services/daily_task_service.dart:1506,1544`, `supabase/functions/storage-retention/index.ts:12`, `supabase/migrations/2026-10-22_security_rls_lockdown.sql:48-52`).
- **RLS & `auth.uid()`**: Zero occurrences of `auth.uid()` exist in `supabase/` or `lib/`. Because PMApp uses custom `x-app-session` tokens instead of Supabase Auth JWTs, Postgres sees all client requests as Postgres role `anon`. Recent migrations either disable `anon` completely (`2026-11-07_cutover_lockdown.sql:6`, `2026-11-11_device_push_tokens.sql:14-16`) or use `USING (true)` policies for `anon`. Therefore `app-releases` storage writes and `app_releases` table mutations **must** go through a `verifySession`-protected Edge Function using `service_role` (never client direct storage upload with anon key).
- **APK sizes vs Supabase Free Tier** (limits verified via Context7 `/websites/supabase` docs):
  - **Free Tier max file size**: **50 MB** (`storage/uploads/file-limits`).
  - **Free Tier total storage quota**: **1 GB** (`storage/pricing`).
  - **Measured `2.0.141` split APKs** (`stat -c %s`):
    - `app-arm64-v8a-release.apk`: `24,926,834` bytes (~24.9 MB) — fits under 50 MB.
    - `app-armeabi-v7a-release.apk`: `23,074,018` bytes (~23.1 MB) — fits under 50 MB.
    - `app-x86_64-release.apk`: `26,516,080` bytes (~26.5 MB) — fits under 50 MB.
  - **Measured universal APK (`2.0.131`)**: `68,497,881` bytes (~68.5 MB) — **exceeds 50 MB Free Tier limit** and would be rejected.
  - **Quota pressure**: `task-proofs` previously hit >1 GB (`docs/audit/2026-11-08-storage-retention.md:93`), now trimmed every 6h via `storage-retention`. Each arm64+arm32 release pair uses ~48 MB (~4.7% of 1 GB), so `app-releases` needs retention cleanup (keep latest N versions).

---

## 5. Android Client Facts

- **Permissions** (`android/app/src/main/AndroidManifest.xml:1-18`): `REQUEST_INSTALL_PACKAGES` is **absent**. `INTERNET` is present (`:5`); `usesCleartextTraffic="false"` (`:28`).
- **FileProvider** (`AndroidManifest.xml:57-65`): `androidx.core.content.FileProvider` is declared with `android:authorities="${applicationId}.direct_share_provider"`, `exported="false"`, `grantUriPermissions="true"`.
  - `android/app/src/main/res/xml/provider_paths.xml:1-7` currently restricts paths to `share/` under `cache-path`, `external-cache-path`, and `files-path` (used by `MainActivity.kt:76`). P3 must either save APKs under `<cache>/share/updates/` or add an explicit `<cache-path name="apk_updates" path="updates/" />` entry.
- **SDK versions** (`build.gradle.kts:13,37-38` + `aapt2 dump badging` on `2.0.141`): `minSdkVersion: 24`, `targetSdkVersion: 36`, `compileSdkVersion: 36`.
- **Relevant `pubspec.yaml` packages**:
  - **Present**: `http: ^1.6.0` (supports streaming download via `Client.send` for progress/speed), `crypto: ^3.0.6` (SHA-256 verification), `path_provider: ^2.1.5` (cache path), `package_info_plus: ^10.2.1` (runtime `version` + `buildNumber`), `permission_handler: ^11.3.1`, `shared_preferences: ^2.3.2`.
  - **Absent**: `dio`, `open_filex`, `install_plugin`, `ota_update`. `MainActivity.kt` already wires a `MethodChannel` + `FileProvider`, so P3 can trigger system install natively or add `open_filex` (verify via Context7 in P3).
- **Existing version-check / update UI**:
  - `version.json`: emitted only for web builds (`https://bssparking-pma.vercel.app/version.json`, checked by release specs `REL-2140`/`REL-2141`); **unused in `lib/`**.
  - `WhatsNewService` (`lib/data/services/whats_new_service.dart:32-77`) + `SplashScreen` (`lib/features/splash/screens/splash_screen.dart:132-146`): local-only post-install changelog popup (`PackageInfo.fromPlatform()`, `bss_whats_new_seen_version_v1`). **No** remote update check or "update available" UI exists in `lib/`.

---

## 6. Recommendations, Architecture & Open Questions

### Proposed P1 Backend Surface
- **Table `public.app_releases`**: RLS enabled, `SELECT` allowed for `anon` only where `status = 'published'` (or served exclusively through Edge Function), all writes restricted to `service_role`. Unique constraint on `(app, flavor, abi, version_code)`. Columns: `id`, `app` (`'pmapp'`), `flavor` (`'prod'`|`'demo'`), `abi` (`'arm64-v8a'`|`'armeabi-v7a'`|`'x86_64'`), `version_code` (APK `buildNumber`, i.e., `4154`/`3154`), `base_version_code` (`2154`), `version_name`, `apk_path`, `sha256`, `size_bytes`, `changelog`, `mandatory` (bool), `min_supported_code` (per-ABI or base-normalized), `status` (`'draft'`|`'published'`|`'rolled_back'`), `published_at`, `created_by`.
- **Bucket `app-releases`**: Private bucket (recommended, download via short-lived signed URL from Edge Function) or public immutable objects with versioned non-overwriting paths `<flavor>/<version_code>-<abi>.apk`. Prune old non-latest releases to protect 1 GB Free Tier quota.
- **Edge Functions**:
  - `GET/POST /functions/v1/app-releases-latest` (or action `'latest'`): takes `app`, `flavor`, `abi`, `current_code`; returns latest `'published'` row + short-lived signed download URL + computed `mandatory` flag.
  - `POST /functions/v1/app-releases-admin` (actions: `create_upload_url`, `publish`, `rollback`, `list`): requires `verifySession(req)` + `isSpv(session)`.

### ABI Split & Client Resolution
- **Use split-per-ABI rows** (`arm64-v8a` ~24.9 MB, `armeabi-v7a` ~23.1 MB), **not** universal APK (~68.5 MB > 50 MB Free Tier cap).
- **Client ABI detection**: Add a 5-line `MethodChannel` method in `MainActivity.kt` returning `Build.SUPPORTED_ABIS` so the client picks the first supported ABI in `['arm64-v8a', 'armeabi-v7a', 'x86_64']` without adding a new package.
- **Version comparison pitfall**: Because `--split-per-abi` outputs `arm32 = base + 1000` (`3154`) and `arm64 = base + 2000` (`4154`), `PackageInfo.buildNumber` on devices reports the ABI-offset code (`3154` or `4154`), **not** `2154`. Store and compare against the matching ABI's `version_code` (or normalize `buildNumber % 1000`? Safer: store explicit `abi` + exact `aapt`/APK `version_code` per row, and compare `min_supported_code` on the same scale, e.g. `base_version_code` via `currentBaseCode` or per-ABI `min_supported_code`). `[INFERENCE]` — exact `flutter` ABI offset table (`+1000`/`+2000`/`+4000`) observed directly on `2.0.141` APKs; verify in P3 tests.

### Open Questions for Aan
1. **Flavors**: Do any field devices run the `demo` (`com.bssparking.timemark.demo`) build, or should P1/P3 target `prod` only for now?
2. **Publish authority**: Can **all** `spv` accounts (Manado, Bali, HO) upload/publish/rollback APK releases, or should release management be restricted to specific `HO` / admin accounts?
3. **Debug keystore backup**: Where should `~/.android/debug.keystore` be backed up so it survives machine loss?
4. **Storage retention**: Keep how many historical releases in `app-releases` (e.g., latest 2–3 versions = ~100–150 MB) to stay safely within Supabase Free Tier 1 GB alongside `task-proofs`?

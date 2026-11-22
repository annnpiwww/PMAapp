# Contract: PMApp In-App Updater Client (P3 + P4)

Client implementation for technician self-update (`U1`..`U5`) and publisher release management (`A1`..`A2`), wired to `POST /functions/v1/app-releases` (see [app-releases.md](app-releases.md)).

---

## 1. File Locations

| Layer | Path | Responsibility |
|---|---|---|
| Native Android | `android/app/src/main/kotlin/com/bssparking/timemark/bssparking_timemark/MainActivity.kt` | `com.bssparking.timemark/app_updater` MethodChannel + SAF APK picker |
| Manifest & Paths | `android/app/src/main/AndroidManifest.xml`, `provider_paths.xml` | `REQUEST_INSTALL_PACKAGES`, `<cache-path name="apk_updates" path="updates/"/>` |
| Technician Service | `lib/data/services/app_update_service.dart` | `checkLatest`, resumable `download`, chunked/isolate `verify`, 12h `Nanti` cooldown, install bridge |
| Publisher Service | `lib/data/services/app_release_admin_service.dart` | `list`, `createUpload`, `uploadFile` (streamed PUT), `publish`, `rollback`, `deleteDraft`, APK validation |
| State & Triggers | `lib/features/updater/updater_controller.dart`, `app_update_coordinator.dart` | Download/verify/permission state machine + startup & 30m throttled resume triggers |
| Technician UI | `lib/features/updater/widgets/updater_sheet.dart`, `updater_ticket_widgets.dart`, `screens/mandatory_update_screen.dart` | `U1`..`U5` sheets & `U4` non-dismissible full-screen route |
| Publisher UI | `lib/features/updater/screens/app_releases_screen.dart`, `upload_release_screen.dart` | `A1` release list, `A2` upload form, `2B` publish & `2C` rollback dialogs |
| App Entry Wiring | `lib/features/splash/screens/splash_screen.dart`, `lib/main.dart`, `lib/features/camera/widgets/camera_drawer.dart` | Startup trigger after splash/WhatsNew, lifecycle + route observer, SPV drawer entry |

---

## 2. Native MethodChannel (`com.bssparking.timemark/app_updater`)

| Method | Arguments | Return Value | Notes |
|---|---|---|---|
| `getSupportedAbis` | none | `List<String>` | Returns `Build.SUPPORTED_ABIS` in device preference order |
| `canInstallPackages` | none | `bool` | `packageManager.canRequestPackageInstalls()` on API 26+, `true` below |
| `openInstallPermissionSettings` | none | `bool` | Opens `Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES` for `package:<applicationId>` |
| `installApk` | `{ "path": String }` | `bool` | Verifies path is inside `<cache>/updates/`, resolves `FileProvider` (`${applicationId}.direct_share_provider`), launches `Intent.ACTION_VIEW` with `application/vnd.android.package-archive`, `FLAG_GRANT_READ_URI_PERMISSION`, `FLAG_ACTIVITY_NEW_TASK` |
| `readApkInfo` | `{ "path": String }` | `Map<String, dynamic>?` | Background thread: `PackageManager.getPackageArchiveInfo` (`PackageInfoFlags.of(0)` API 33+, `longVersionCode` API 28+) + `ZipFile` scan for `lib/<abi>/` -> `{packageName, versionName, versionCode, abis}` |
| `pickApkFile` | none | `Map<String, dynamic>?` | Launches `Intent.ACTION_OPEN_DOCUMENT` (`*/*`) and streams selected URI to `<cache>/updates/picked-<ts>.apk` -> `{path, name, sizeBytes}` |

### A2 File Picker Dependency Justification

No `file_picker` package is present in `pubspec.yaml` (`image_picker` only supports photos/videos). Instead of adding a new pub plugin, `MainActivity.kt` exposes `pickApkFile` via Android's built-in `Intent.ACTION_OPEN_DOCUMENT` (`onActivityResult` + background stream copy into `<cache>/updates/`). This requires zero new dependencies, zero storage permissions on API 24-36, and keeps `pubspec.yaml` unchanged.

---

## 3. Dart Service APIs

### `AppUpdateService` (`lib/data/services/app_update_service.dart`)

- `static String? pickAbi(List<String> supportedAbis)`: first entry in `supportedAbis` present in `['arm64-v8a', 'armeabi-v7a', 'x86_64']`.
- `Future<AppUpdateCheckResult?> checkLatest()`:
  - Reads `PackageInfo.fromPlatform()` + device ABI, cleans stale `<cache>/updates/pmapp-*.apk(.part)` with `versionCode <= currentCode`.
  - `POST <baseUrl>/functions/v1/app-releases` with `{action: 'latest', abi, current_code, current_version}` (no `x-app-session` required; 8s timeout).
  - Returns `null` on `update != true`, HTTP error, timeout, or invalid JSON (never blocks app startup).
- `Stream<DownloadProgress> download(AppUpdateRelease release, String url, {Future<AppUpdateCheckResult?> Function()? refreshLatest})`:
  - Streams to `<cache>/updates/pmapp-<version_code>.apk.part`.
  - Sends `Range: bytes=<len>-` when `.part` exists; on `400`/`403` (900s signed URL expiry) calls `refreshLatest` once and resumes.
  - Computes moving-average `bytesPerSec` and `eta` over the last 3 seconds.
  - Maps network errors (`SocketException`, `TimeoutException`, `ClientException`) to `AppUpdateErrorKind.noInternet` / `interrupted`, and `ENOSPC` (`osError.errorCode == 28`) to `AppUpdateErrorKind.storageFull`.
- `Future<bool> verify(File file, AppUpdateRelease release)` / `Future<File> verifyAndFinalize(AppUpdateRelease release)`:
  - Validates exact `size_bytes` and lowercase hex SHA-256 (chunked 64 KB reads inside `Isolate.run` when `> 5 MB`).
  - Deletes corrupt file on mismatch and throws `AppUpdateErrorKind.corruptFile`; renames `.part` to `.apk` only after verification succeeds.
- `isDismissedFor12Hours(int versionCode)` / `dismissFor12Hours(int versionCode)` / `shouldPrompt(AppUpdateCheckResult)`:
  - Stores dismissal timestamp in `SharedPreferences` (`bss_updater_dismissed_<versionCode>`) for 12 hours on optional updates; `mandatory == true` ignores dismissal.

### `AppReleaseAdminService` (`lib/data/services/app_release_admin_service.dart`)

- All RPC actions (`list`, `createUpload`, `publish`, `rollback`, `deleteDraft`) send `apikey`, `Authorization: Bearer <anonKey>`, and `x-app-session`.
- `inspectLocalApk(path)`: calls `readApkInfo`, computes SHA-256 (`Isolate.run` if `> 5 MB`), validates `packageName == 'com.bssparking.timemark.bssparking_timemark'`, requires exactly 1 ABI (rejects multi-ABI universal APKs with `'Unggah APK per arsitektur, bukan universal.'`), and verifies `base_version_code = versionCode - offset(abi) > 0`.
- `uploadFile(signedUrl, file, {onProgress})`: streamed `PUT` with `Content-Type: application/vnd.android.package-archive` and `x-upsert: false`.
- Error mapping: `403` -> `'Akun ini belum punya akses rilis.'`, `409` (`version_code_must_increase` / `duplicate`) -> `'Nomor versi harus lebih tinggi dari rilis sebelumnya.'`, `400` -> server `errors` map.

---

## 4. State Machine & Triggers

```text
idle ──(checkLatest: update=true)──> available (U1 optional sheet / U4 mandatory route)
  │                                       │
  │ (Nanti, optional only: 12h cooldown)  ▼ (Perbarui sekarang / auto-start on U4)
  └<──────────────────────────────── downloading (U2 / U4)
                                          │
                 ┌───(stream error)───────┤
                 ▼                        ▼ (EOF)
               error (U5 5A-5D)      verifying
                 ▲                        │
                 └───(hash/size fail)─────┼──(canInstallPackages == false)──> needsPermission (U3 3A)
                                          │                                        │
                                          ▼ (canInstallPackages == true) <─────────┘ (on resumed == true)
                                        ready (U3 3B) ──(Pasang sekarang)──> installing (ACTION_VIEW)
```

- **Startup trigger**: `SplashScreen` calls `AppUpdateCoordinator.instance.scheduleStartupCheck(waitForPopupClose: release != null)` right after `pushReplacement` (never delays splash; if `WhatsNewSheet` opened, waits for its `PopupRoute` to pop before prompting).
- **Resume trigger**: `AppUpdateCoordinator` attaches a `WidgetsBindingObserver` in `main.dart` and checks on `AppLifecycleState.resumed` throttled to once per 30 minutes (`resumeThrottle`). Optional sheets are suppressed if a pushed capture route (`capture` / `sop_camera`) or modal is active.
- **Publisher entry**: `Rilis aplikasi` `ListTile` inside the `isSpv` section of `CameraDrawer` (directly under `Penugasan Teknisi`).

---

## 5. Testing on Device

1. Confirm device ABI and current installed version (`2.0.141`, `arm64-v8a` `4154` / `armeabi-v7a` `3154`).
2. Build a higher test release (e.g., `2.0.142+2155` using the same `~/.android/debug.keystore`) via `flutter build apk --release --split-per-abi`.
3. Publish via CLI or A2 UI:
   ```bash
   node tools/publish_release.mjs --changelog "Uji pembaruan 2.0.142"
   ```
4. Re-open PMApp (or background -> wait/bypass 30m throttle -> resume) to observe `U1` -> `U2` -> `U3` -> system installer, or publish with `--mandatory` / `--min-version 2.0.142` to verify `U4` full-screen block.
5. Verify rollback via A1 (`Tarik rilis`) hides the release from `latest` on un-updated devices.

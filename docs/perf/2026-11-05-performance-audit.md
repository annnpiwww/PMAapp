# PMA App — Performance & Data-Access Audit Report

**Date:** 2026-11-05  
**Auditor:** Tukang Security & QA (Principal AppSec Engineer + QA Specialist)  
**Target:** PMA App (Flutter Mobile/PWA + Supabase PostgREST + Supabase Edge Functions)  
**Scope:** `lib/data/services/*.dart`, `lib/data/repositories/*.dart`, `lib/features/**/screens/*.dart`, `supabase/functions/*/index.ts`, `docs/sql/*.sql`, `supabase/migrations/*.sql`  

---

## 1. Executive Summary & Scorecard

A comprehensive, read-only performance and data-access audit of the PMA App codebase was conducted across 6 core architectural practices: N+1 query prevention, database indexing, login & sync scoping, client/edge caching, lazy loading, and optimistic UI. 

Currently, **0 of 6 practices are fully implemented** according to strict production standards: 5 practices are partially implemented with significant structural gaps, and 1 practice (optimistic UI with rollback) is not implemented.

| # | Practice | Status (YES / PARTIAL / NO) | Evidence file:line | Impact (High/Med/Low) | Recommended fix |
|---|---|---|---|---|---|
| 1 | N+1 Queries | PARTIAL | [daily_task_service.dart:1064](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L1064), [daily_task_service.dart:1672](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L1672), [daily_task_service.dart:1705](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L1705), [google_sheets_service.dart:236](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/google_sheets_service.dart#L236) | High | Parallelize proof photo uploads via `Future.wait()`, batch offline task completions/creations into multi-row POST/RPC instead of iterative single HTTP calls. |
| 2 | Database Indexes | PARTIAL | [daily-tasks-per-branch.sql:56](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/docs/sql/2026-10-18-daily-tasks-per-branch.sql#L56), [2026-11-03_pos_locations.sql:5](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/supabase/migrations/2026-11-03_pos_locations.sql#L5), [2026-11-03_technicians.sql:14](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/supabase/migrations/2026-11-03_technicians.sql#L14), [2026-11-04-maintenance-logs-branch.sql:16](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/docs/sql/2026-11-04-maintenance-logs-branch.sql#L16) | High | Add missing composite indexes for `daily_tasks_*(status, created_at DESC)`, `app_users(lower(username), lower(email))`, `pos_locations(active, branch)`, and `technicians(active, branch, sort_order)`. |
| 3 | Login & Sync Scoping | PARTIAL | [auth_repository.dart:52-57](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/repositories/auth_repository.dart#L52-L57), [daily_task_service.dart:228-231](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L228-L231), [location_service.dart:1145](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/location_service.dart#L1145), [branch_service.dart:106](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/branch_service.dart#L106) | High | Scope `daily_tasks` queries by `teknisi_nama` and `branch` in PostgREST instead of pulling 100 rows across all technicians and filtering client-side; scope `pos_locations` by `branch`. |
| 4 | Caching & Redis | PARTIAL | [storage_service.dart:16-36](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/storage_service.dart#L16-L36), [location_service.dart:1495-1501](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/location_service.dart#L1495-L1501), [pos-locations/index.ts:25](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/supabase/functions/pos-locations/index.ts#L25), [ai-vision/index.ts:46](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/supabase/functions/ai-vision/index.ts#L46) | Med | Redis is completely unjustified for ~20 technicians. Use client-side in-memory TTL caching (30s) for polling queries and edge function `Cache-Control: public, max-age=300`. |
| 5 | Lazy Loading | PARTIAL | [maintenance_map_screen.dart:760,774,1415](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/maintenance/screens/maintenance_map_screen.dart#L760), [teknisi_daily_tasks_screen.dart:368,382](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart#L368), [spv_task_dispatcher_screen.dart:1800,1850](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart#L1800), [app_file_image.dart:18,72](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/core/widgets/app_file_image.dart#L18) | High | Migrate eager `ListView(children: [...])` to `ListView.builder` in daily task screens; implement map tile caching and viewport marker culling; generate low-res image thumbnails. |
| 6 | Optimistic UI | NO | [custom_task_execution_screen.dart:278-297](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/custom_task_execution_screen.dart#L278-L297), [spv_task_dispatcher_screen.dart:906-926](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart#L906-L926), [teknisi_daily_tasks_screen.dart:163-168](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart#L163-L168), [location_management_screen.dart:80-88](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/locations/screens/location_management_screen.dart#L80-L88) | Med | Switch from blocking spinner waits to immediate UI state updates, asynchronous background syncing, and explicit failure rollback handlers with user snackbars. |

---

## 2. Check 1: N+1 Queries & Batched Access

### 2.1 Audit Findings

Some parts of the codebase demonstrate excellent batching discipline:
- `MaintenanceLogService.syncLocal()` ([maintenance_log_service.dart:513-532](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/maintenance_log_service.dart#L513-L532)) expands candidates and issues a single batched HTTP POST with `Prefer: resolution=merge-duplicates`.
- `LocationService._flushImportQueue()` ([location_service.dart:1274-1296](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/location_service.dart#L1274-L1296)) chunks queued items in groups of 50 and submits a single `import` action to `pos-locations`.
- `MaintenanceMapScreen` ([maintenance_map_screen.dart:461-467](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/maintenance/screens/maintenance_map_screen.dart#L461-L467)) fetches all logs for the selected month in 1 query, and executes client-side joining in `buildStatuses`.

However, multiple severe sequential loop patterns (N+1 HTTP calls) exist:

1. **Sequential Proof Photo Uploads in `completeTask`:**
   - **File & Lines:** [lib/data/services/daily_task_service.dart:1064-1080](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L1064-L1080)
   - **Pattern:** `for (int i = 0; i < photosToUpload.length; i++) { await http.post(uploadUri, ...) }`
   - **Call count per task submission:** 1 to 5 sequential HTTP POST requests to Supabase Storage before the subsequent task patch call.
   - **Alternative:** Execute concurrent uploads via `await Future.wait(photosToUpload.map(...))` or use a single multipart upload endpoint.

2. **Sequential Queue Flushing in `flushPendingCompletions`:**
   - **File & Lines:** [lib/data/services/daily_task_service.dart:1672-1686](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L1672-L1686)
   - **Pattern:** `for (final entry in queue) { final ok = await completeTask(...); }`
   - **Call count on reconnect:** For $N$ pending completions with an average of $P$ photos, this executes $N \times (P + 1)$ sequential network requests on the main isolate.
   - **Alternative:** Single RPC endpoint `complete_tasks_batch(jsonb)` or parallel `Future.wait` across tasks with bounded concurrency.

3. **Sequential Duplicate Checks & Inserts in `flushPendingTaskCreationQueue`:**
   - **File & Lines:** [lib/data/services/daily_task_service.dart:1705-1733](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L1705-L1733)
   - **Pattern:** `for (final itemStr in list) { await _findServerDuplicate(...); await http.post(...); }`
   - **Call count on reconnect:** Up to $2 \times N$ sequential HTTP calls (1 GET + 1 POST per queued creation).
   - **Alternative:** Batched multi-row PostgREST insert: `POST /rest/v1/daily_tasks?on_conflict=tanggal,teknisi_nama,judul,pos_tag` with `Prefer: resolution=ignore-duplicates` passing all pending payloads in a single JSON array body.

4. **Sequential Webhook Flushing in `GoogleSheetsService`:**
   - **File & Lines:** [lib/data/services/google_sheets_service.dart:236-245](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/google_sheets_service.dart#L236-L245)
   - **Pattern:** `for (final item in listStr) { await http.post(uri, body: item); }`
   - **Call count:** 1 HTTP POST per queued submission (up to queue length).
   - **Alternative:** Batched payload webhook structure or bounded concurrency pool (`Future.wait` with chunking).

5. **Preset Multi-Task Dispatch in `SpvTaskDispatcherScreen`:**
   - **File & Lines:** [lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:834-850](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart#L834-L850)
   - **Pattern:** Sequential `await DailyTaskService.createTask(...)` calls for Gate Out 1-6 and Gate Ojek.
   - **Alternative:** Batch creation via single `DailyTaskService.createTasks(List<DailyTaskPayload>)`.

---

## 3. Check 2: Database Indexes

### 3.1 Table Query & Filter Analysis

Every table queried by client services and edge functions was analyzed against migration schemas:

1. **`public.daily_tasks_<branch>` (`daily_tasks_manado`, `daily_tasks_bali`, `daily_tasks_ho`):**
   - **Queried By:** `DailyTaskService.getTasksForTeknisi` ([daily_task_service.dart:228-230](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L228-L230)), `getAllTasksToday` ([daily_task_service.dart:336-340](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L336-L340)), `_findServerDuplicate` ([daily_task_service.dart:566-571](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L566-L571)).
   - **Filters / Orders Used:** `or=(status.eq.pending,tanggal.eq.$tanggal)`, `tanggal.gte.$batasLanjutan`, `order=created_at.desc`, `id=eq.$taskId`.
   - **Existing Indexes in SQL:** Primary key on `id`, unique index on `(tanggal, teknisi_nama, judul, pos_tag)` ([2026-10-18-daily-tasks-per-branch.sql:56-59](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/docs/sql/2026-10-18-daily-tasks-per-branch.sql#L56-L59), [2026-10-19-daily-tasks-ho.sql:35](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/docs/sql/2026-10-19-daily-tasks-ho.sql#L35)).
   - **Missing Indexes:** No index on `(status, created_at DESC)` or `(created_at DESC)`. Because the 25-second poller requests `status.eq.pending` ordered by `created_at DESC`, PostgreSQL must perform sequential table scans and in-memory sorting every 25 seconds for each active technician.

2. **`public.app_users`:**
   - **Queried By:** `AuthRepository.loginWithPassword` ([auth_repository.dart:43-56](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/repositories/auth_repository.dart#L43-L56)) and `pos-locations` edge function ([index.ts:101](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/supabase/functions/pos-locations/index.ts#L101)).
   - **Filters / Orders Used:** `or=(username.ilike.$val,email.ilike.$val,nama.ilike.$val)`.
   - **Existing Indexes in SQL:** No index declarations found in `docs/sql/` or `supabase/migrations/` (only referenced in RLS lockdown notes).
   - **Missing Indexes:** Functional indexes on `lower(username)`, `lower(email)`, `lower(nama)` to avoid sequential scans during login and SPV action verification.

3. **`public.pos_locations`:**
   - **Queried By:** `LocationService.syncFromRemote` ([location_service.dart:1145](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/location_service.dart#L1145)) and `pos-locations` edge function ([index.ts:207,243,292](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/supabase/functions/pos-locations/index.ts#L207)).
   - **Filters / Orders Used:** `active=eq.true`, `pos_id=eq.$pos_id`, and branch filtering.
   - **Existing Indexes in SQL:** Primary key on `pos_id` ([2026-11-03_pos_locations.sql:5](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/supabase/migrations/2026-11-03_pos_locations.sql#L5)).
   - **Missing Indexes:** Composite index on `(active, branch)`.

4. **`public.technicians`:**
   - **Queried By:** `BranchService.syncTechniciansFromRemote` ([branch_service.dart:106](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/branch_service.dart#L106)).
   - **Filters / Orders Used:** `active=eq.true&order=branch.asc,sort_order.asc`.
   - **Existing Indexes in SQL:** Primary key on `id`, unique index on `(lower(nama), branch)` ([2026-11-03_technicians.sql:14](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/supabase/migrations/2026-11-03_technicians.sql#L14)).
   - **Missing Indexes:** Index on `(active, branch, sort_order)` to support ordered retrieval without sort overhead.

5. **`public.maintenance_logs_manado`:**
   - **Queried By:** `MaintenanceLogService.fetchMonth` ([maintenance_log_service.dart:558-560](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/maintenance_log_service.dart#L558-L560)).
   - **Filters / Orders Used:** `tanggal=gte.$start&tanggal=lte.$end&branch=eq.$branch&order=tanggal.desc,jam_selesai.desc`.
   - **Existing Indexes in SQL:** Primary key on `id`, `idx_maintenance_logs_manado_tanggal` ([2026-11-02-maintenance-logs-manado.sql:24](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/docs/sql/2026-11-02-maintenance-logs-manado.sql#L24)), and `idx_maintenance_logs_branch_tanggal` on `(branch, tanggal)` ([2026-11-04-maintenance-logs-branch.sql:16](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/docs/sql/2026-11-04-maintenance-logs-branch.sql#L16)).
   - **Missing Indexes:** Including `jam_selesai DESC` in the index: `(branch, tanggal DESC, jam_selesai DESC)` avoids sorting in memory.

### 3.2 Ready-to-Run Index SQL

```sql
-- ============================================================================
-- Ready-to-run Performance Indexes for Supabase PostgreSQL
-- Safe and idempotent (CREATE INDEX IF NOT EXISTS)
-- ============================================================================

-- 1. Daily Tasks: optimize 25-second polling (status=pending order by created_at desc)
CREATE INDEX IF NOT EXISTS idx_daily_tasks_manado_status_created 
  ON public.daily_tasks_manado (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_daily_tasks_bali_status_created 
  ON public.daily_tasks_bali (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_daily_tasks_ho_status_created 
  ON public.daily_tasks_ho (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_daily_tasks_status_created 
  ON public.daily_tasks (status, created_at DESC);

-- Daily Tasks: optimize technician task scoping
CREATE INDEX IF NOT EXISTS idx_daily_tasks_manado_teknisi_status
  ON public.daily_tasks_manado (teknisi_nama, status, tanggal);

CREATE INDEX IF NOT EXISTS idx_daily_tasks_bali_teknisi_status
  ON public.daily_tasks_bali (teknisi_nama, status, tanggal);

CREATE INDEX IF NOT EXISTS idx_daily_tasks_ho_teknisi_status
  ON public.daily_tasks_ho (teknisi_nama, status, tanggal);

-- 2. App Users: functional indexes for case-insensitive login & SPV verification
CREATE INDEX IF NOT EXISTS idx_app_users_lower_username 
  ON public.app_users (lower(username));

CREATE INDEX IF NOT EXISTS idx_app_users_lower_email 
  ON public.app_users (lower(email));

CREATE INDEX IF NOT EXISTS idx_app_users_lower_nama 
  ON public.app_users (lower(nama));

-- 3. POS Locations: active filter and branch lookups
CREATE INDEX IF NOT EXISTS idx_pos_locations_active_branch 
  ON public.pos_locations (active, branch);

-- 4. Technicians: ordered active list for BranchService sync
CREATE INDEX IF NOT EXISTS idx_technicians_active_branch_sort 
  ON public.technicians (active, branch, sort_order);

-- 5. Maintenance Logs: index-only scan for monthly map display
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_branch_tanggal_jam 
  ON public.maintenance_logs_manado (branch, tanggal DESC, jam_selesai DESC);

CREATE INDEX IF NOT EXISTS idx_maintenance_logs_pos_id 
  ON public.maintenance_logs_manado (pos_id);
```

---

## 4. Check 3: Login & Post-Login Scoping

### 4.1 Login Query Scoping
- **Code Evidence:** [lib/data/repositories/auth_repository.dart:52-57](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/repositories/auth_repository.dart#L52-L57)
```dart
final uri = Uri.parse('${DailyTaskService.baseUrl}/rest/v1/app_users').replace(
  queryParameters: {
    'or': '(${orFilters.join(',')})',
    'select': '*',
    'limit': '1',
  },
);
```
- **Verdict:** Login is **properly scoped** to a single user row via `limit: '1'` and exact equality/ilike filters on username/email/nama. It does **not** fetch the whole table on login.
- **Security Note:** `select: '*'` returns all user attributes including plaintext password, with comparison occurring in Dart code on client device ([auth_repository.dart:73-83](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/repositories/auth_repository.dart#L73-L83)).

### 4.2 Post-Login Bootstrap Syncs Scoping
Tracing each post-login bootstrap synchronization triggered in `main.dart` ([main.dart:39-50](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/main.dart#L39-L50)) and `CameraCaptureScreen` ([camera_capture_screen.dart:286-294](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/camera/screens/camera_capture_screen.dart#L286-L294)):

1. **`LocationService.syncFromRemote()`:**
   - **Evidence:** [lib/data/services/location_service.dart:1144-1146](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/location_service.dart#L1144-L1146)
   - **Query:** `${DailyTaskService.baseUrl}/rest/v1/pos_locations?select=*&active=eq.true`
   - **Scoping Status:** **UNSCOPED TABLE FETCH**. Fetches all active locations across all branches (Manado, Bali, HO Makassar) without a branch filter and without any `limit`.

2. **`BranchService.syncTechniciansFromRemote()`:**
   - **Evidence:** [lib/data/services/branch_service.dart:105-107](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/branch_service.dart#L105-L107)
   - **Query:** `${DailyTaskService.baseUrl}/rest/v1/technicians?select=nama,branch,sort_order&active=eq.true&order=branch.asc,sort_order.asc`
   - **Scoping Status:** **UNSCOPED TABLE FETCH**. Fetches all active technicians across all branches without a branch filter and without any `limit`.

3. **`DailyTaskService.getTasksForTeknisi()`:**
   - **Evidence:** [lib/data/services/daily_task_service.dart:228-231, 259](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L228-L231)
   - **Query:** `$baseUrl/rest/v1/$tasksTable?or=(status.eq.pending,tanggal.eq.$tanggal)&order=created_at.desc&limit=100`
   - **Scoping Status:** **PARTIAL / CLIENT-FILTERED**. The query has `limit=100` and date/status scoping, but **lacks technician filtering** at the PostgREST layer. Line 259 executes `allTasks.where((t) => isAssignedTo(t, teknisiNama)).toList()` in client memory. All technicians download other technicians' pending tasks on every 25s polling cycle.

4. **`MaintenanceLogService.fetchMonth()`:**
   - **Evidence:** [lib/data/services/maintenance_log_service.dart:558-560](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/maintenance_log_service.dart#L558-L560)
   - **Query:** `$baseUrl/rest/v1/$tableName?tanggal=gte.$startTanggal&tanggal=lte.$endTanggal&branch=eq.${activeBranch.code}&order=tanggal.desc,jam_selesai.desc`
   - **Scoping Status:** **SCOPED BY DATE & BRANCH**. Filtered by 1-month date range and active branch, but has no `limit`.

5. **`AttendanceRecord` Archive Sync:**
   - **Evidence:** [lib/features/history/screens/attendance_archive_screen.dart:62](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/history/screens/attendance_archive_screen.dart#L62)
   - **Query:** None (local only). Reads from `StorageService.getAttendanceRecords()` (SharedPreferences). Does not perform remote Supabase queries.

---

## 5. Check 4: Caching & Redis Recommendation

### 5.1 Existing Caching Layer
1. **Persistent Offline Storage (SharedPreferences):**
   - **Evidence:** [lib/data/services/storage_service.dart:16-36](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/storage_service.dart#L16-L36)
   - Stores current user session, templates (`bss_templates_v4`), local submissions, attendance records (30-day retention), cached locations, technician lists, and offline mutation queues (`bss_location_import_queue_v1`, pending daily task completions/creations).
2. **In-Memory TTL Caching:**
   - **Evidence:** [lib/data/services/location_service.dart:1495-1501](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/location_service.dart#L1495-L1501)
   - Implements a 15-second TTL cache for device GPS fixes to prevent UI thread freezing.
   - However, **no in-memory TTL cache exists for PostgREST query results** (`getTasksForTeknisi`, `pos_locations`, `technicians`).
3. **HTTP Cache Headers in Edge Functions:**
   - **Evidence:** [supabase/functions/pos-locations/index.ts:25](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/supabase/functions/pos-locations/index.ts#L25) and [supabase/functions/ai-vision/index.ts:46](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/supabase/functions/ai-vision/index.ts#L46)
   - Both functions hardcode `'Cache-Control': 'no-store'`. Edge-level caching is entirely bypassed.

### 5.2 Redis Evaluation & Recommendation
- **Does Redis exist in the stack?** **NO**. No Redis client, configuration, or environment variable exists in the repository.
- **Is Redis justified for this stack and scale?**
  > [!IMPORTANT]
  > **Redis is completely UNJUSTIFIED and contraindicated for this stack.**
- **Rationale:**
  The PMA App serves ~20 technicians and supervisors across 3 regional branches (KC Manado: 4 technicians, KC Bali: 6 technicians, HO Makassar: 10 technicians). Peak concurrency is under 25 devices. Introducing Redis (Upstash, ElastiCache, or self-hosted Redis) would add unnecessary monthly cloud costs, introduce a network point of failure, require complex connection management, and require cache-invalidation logic that exceeds the complexity of the core application.
- **Recommended Cheaper & Simpler Alternatives:**
  1. **Client-Side In-Memory TTL Cache (Cost: $0):** Cache `DailyTaskService.getTasksForTeknisi` and `getAllTasksToday` in Dart memory with a 20-30s TTL. If data is requested within TTL, serve instant memory without hitting PostgREST.
  2. **Edge Function & PostgREST Cache Headers (Cost: $0):** Use `Cache-Control: public, max-age=300, stale-while-revalidate=600` on read-only reference endpoints like `pos_locations` and `technicians`.
  3. **PostgreSQL Materialized View (Cost: $0):** For monthly maintenance aggregation across locations, a Postgres view or periodic materialized view refreshed on submission can replace complex client-side calculations without any extra infrastructure.

---

## 6. Check 5: Lazy Loading & Asset Optimization

### 6.1 Map Lazy Loading
- **File & Lines:** [lib/features/maintenance/screens/maintenance_map_screen.dart:760-776, 1413-1440](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/maintenance/screens/maintenance_map_screen.dart#L760-L776)
- **Marker Clustering:** **NO**. All locations are plotted as individual `Marker` widgets inside `MarkerLayer(markers: _buildMarkers())`. No `MarkerClusterLayer` or superclustering is used.
- **Viewport Culling (Only Visible Markers):** **NO**. Line 1415 selects all locations with non-zero coordinates across the filtered branch: `filtered.where((s) => s.location.lat != 0 && s.location.lng != 0).toList()`. It renders off-screen markers regardless of camera zoom or bounds.
- **Tile Caching:** **NO**. Lines 760-766 use default `TileLayer` pointing to `https://tile.openstreetmap.org/{z}/{x}/{y}.png` without a persistent disk cache (`CachedNetworkTileProvider` or `flutter_map_cache`). Re-navigating to the map re-downloads map tiles over the cellular network.

### 6.2 Photos & Image Memory Management
- **Thumbnails vs Full-Resolution:** **PARTIAL**. Images captured via camera are 1080p JPEGs ([image_watermark_processor.dart:72](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/core/utils/image_watermark_processor.dart#L72)). The app does **not** generate or store separate low-resolution thumbnail files on disk or in Supabase Storage. Full-resolution images are loaded directly from disk or network.
- **`cacheWidth` / `cacheHeight` Decoding:** **YES**. Implemented properly in `AppFileImage` ([lib/core/widgets/app_file_image.dart:18, 56, 78, 109](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/core/widgets/app_file_image.dart#L18)) and callers:
  - `AttendanceArchiveScreen`: `cacheWidth: 200` ([attendance_archive_screen.dart:793](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/history/screens/attendance_archive_screen.dart#L793))
  - `GalleryScreen`: `cacheWidth: 300` ([gallery_screen.dart:429](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/history/screens/gallery_screen.dart#L429))
  - `CompletedDailyTaskModal`: `cacheWidth: 600` ([completed_daily_task_modal.dart:463](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/widgets/completed_daily_task_modal.dart#L463))
  - `CameraCaptureScreen`: `cacheWidth: 800` ([camera_capture_screen.dart:3111](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/camera/screens/camera_capture_screen.dart#L3111))
- **`Image.memory` with Base64 in Lists:** **INEFFICIENT**. `AppFileImage` lines 71-74 parses and decodes `base64Decode(base64Str)` inside its `build()` method synchronously on the UI thread for data URLs. While `AttendanceArchiveScreen` uses a 12-item LRU `_webPhotoFutures` cache ([attendance_archive_screen.dart:40](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/history/screens/attendance_archive_screen.dart#L40)), un-memoized Base64 decoding during list scrolling causes micro-jank.

### 6.3 List Rendering & Pagination
- **`AttendanceArchiveScreen`:** **LAZY LISTVIEW**. Uses `SliverList(delegate: SliverChildBuilderDelegate(...))` ([attendance_archive_screen.dart:624-636](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/history/screens/attendance_archive_screen.dart#L624-L636)). Cards are built on-demand as they enter viewport. However, the data source is loaded all-at-once from local storage (up to 30 days retention) without pagination.
- **`TeknisiDailyTasksScreen`:** **EAGER COLUMN IN LISTVIEW (NOT LAZY)**. Lines 368-406 use `ListView(children: [ ..._tasks.map(...) ])` ([teknisi_daily_tasks_screen.dart:368, 382](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart#L368)). All task widgets are instantiated eagerly in memory.
- **`SpvTaskDispatcherScreen`:** **EAGER FOR-IN LISTVIEW (NOT LAZY)**. Lines 1800-1853 use `ListView(children: [ for (final t in tasks) ... ])` ([spv_task_dispatcher_screen.dart:1800, 1850](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart#L1800)). All cards are constructed simultaneously.
- **Pagination / Cursor:** **NO**. Queries rely on static `limit: '100'` ([daily_task_service.dart:229](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L229)) or `limit: '200'` ([daily_task_service.dart:339](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L339)). Infinite scroll pagination is not implemented.

---

## 7. Check 6: Optimistic UI & Rollback Handling

An audit of state mutation flows across the 5 core user actions reveals a predominantly **pessimistic UI model** (request -> modal spinner -> wait -> response/error):

1. **Task Status Change / Completion:**
   - **Evidence:** [lib/features/daily_tasks/screens/custom_task_execution_screen.dart:278-297](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/custom_task_execution_screen.dart#L278-L297) and [lib/data/services/daily_task_service.dart:1044, 1116-1125](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L1044)
   - **Behavior:** `CustomTaskExecutionScreen` sets `_isSaving = true`, awaits `DailyTaskService.completeTask()`, and waits for photo uploads and network patch before dismissing or displaying success.
   - **Rollback:** `DailyTaskService.completeTask` mutates the local task cache optimistically via `markTaskCompletedLocally()` ([daily_task_service.dart:1044](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L1044)). If the server request fails, the task **remains marked completed locally** and is enqueued into `_enqueueCompletion`. There is **no rollback** to pending status on failure.

2. **Daily Task Create:**
   - **Evidence:** [lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:906-940](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart#L906-L940)
   - **Behavior:** The SPV screen sets `_isLoading = true`, blocks user input, and awaits `DailyTaskService.createTask()`. Only when the server (or local offline queue fallback) returns does it call `_loadTasks()` to re-fetch and render.
   - **Verdict:** **Pessimistic (Waits for server)**. No optimistic insertion into UI list with failure rollback.

3. **Daily Task Take / Claim:**
   - **Evidence:** [lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart:160-168](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart#L160-L168)
   - **Behavior:** `_ambilTugas` awaits `DailyTaskService.claimTask(task: task, olehSiapa: user.nama)`. Only after the server response is received does it show a snackbar and call `await _loadTasks()`.
   - **Verdict:** **Pessimistic (Waits for server)**.

4. **Daily Task Handover / Transfer:**
   - **Evidence:** [lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:181-190](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart#L181-L190) and [lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart:138-145](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart#L138-L145)
   - **Behavior:** Submits handover modal, displays loading indicator, awaits `DailyTaskService.transferTask()`, and re-queries `_loadTasks()` on response.
   - **Verdict:** **Pessimistic (Waits for server)**.

5. **Maintenance Submit:**
   - **Evidence:** [lib/features/maintenance/screens/maintenance_checklist_screen.dart:873-874](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/maintenance/screens/maintenance_checklist_screen.dart#L873-L874)
   - **Behavior:** Saves locally to SharedPreferences first (`await StorageService.saveMaintenanceSubmissions(list)`), then fires `unawaited(MaintenanceLogService.syncLocal())`.
   - **Verdict:** **Local-first / Offline-first**, but without rollback handling (silent failure if sync drops).

6. **Location Save / Delete:**
   - **Evidence:** [lib/features/locations/screens/location_management_screen.dart:80-97, 731-737](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/locations/screens/location_management_screen.dart#L80-L97)
   - **Behavior:** The SPV confirmation modal disables buttons, sets `isLoading = true`, awaits `LocationService.saveLocationRemote()` / `deleteLocationRemote()`, and only dismisses and updates the UI on `RemoteWriteResult.ok`.
   - **Verdict:** **Pessimistic (Waits for server)**.

7. **Shift Change:**
   - **Evidence:** [lib/data/services/absensi_setup_service.dart:514-526](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/absensi_setup_service.dart#L514-L526) and [lib/data/services/storage_service.dart:708](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/storage_service.dart#L708)
   - **Behavior:** Shift changes (technician watermark schedule & SPV shift assignments) are saved synchronously to local SharedPreferences. No backend synchronization exists for shift definitions.

---

## 8. Prioritized Fixes (Top 5)

Ranked by impact on end-user latency, database resource utilization, and implementation effort:

### Fix 1: Apply Missing Composite Indexes to Supabase PostgreSQL
- **Impact:** High
- **Effort:** S (Small, < 1 hour)
- **Target Files:**
  - `docs/sql/2026-11-05-performance-indexes.sql` (new migration file)
  - `supabase/migrations/2026-11-05_performance_indexes.sql` (new migration file)
- **Rationale:** Adding indexes on `daily_tasks_*(status, created_at DESC)`, `app_users(lower(username), lower(email))`, and `pos_locations(active, branch)` eliminates full-table scans generated every 25 seconds by background pollers and login requests.

### Fix 2: Scope `DailyTaskService.getTasksForTeknisi` PostgREST Query
- **Impact:** High
- **Effort:** S (Small, 15 lines of code)
- **Target Files:**
  - [lib/data/services/daily_task_service.dart:228-260](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L228-L260)
- **Rationale:** Update PostgREST query parameters to filter by technician at the database level: `queryParameters: {'teknisi_nama': 'eq.$cleanName', 'or': '(status.eq.pending,tanggal.eq.$tanggal)', 'limit': '50'}`. Stops each technician from downloading all 100 pending tasks across other team members every 25 seconds.

### Fix 3: Convert Eager `ListView` to Lazy `ListView.builder` in Daily Tasks
- **Impact:** High
- **Effort:** M (Medium, 2-3 hours)
- **Target Files:**
  - [lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart:368-408](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart#L368-L408)
  - [lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:1800-1860](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart#L1800-L1860)
- **Rationale:** Replacing `ListView(children: [ ..._tasks.map(...) ])` with `CustomScrollView` and `SliverList.builder` prevents constructing and maintaining entire card widget trees and image wrappers off-screen, eliminating scroll lag on lower-tier Android devices.

### Fix 4: Parallelize Proof Photo Uploads via `Future.wait`
- **Impact:** High
- **Effort:** M (Medium, 1-2 hours)
- **Target Files:**
  - [lib/data/services/daily_task_service.dart:1063-1093](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/data/services/daily_task_service.dart#L1063-L1093)
- **Rationale:** Replace the serial `for (int i = 0; i < photosToUpload.length; i++)` loop with concurrent `Future.wait` upload tasks. Reduces total task submission time from $N \times 1.5\text{s}$ (3 to 6 seconds) to a single concurrent roundtrip (~1.5s).

### Fix 5: Implement Map Tile Caching and Viewport Marker Culling
- **Impact:** Med
- **Effort:** M (Medium, 2-4 hours)
- **Target Files:**
  - [lib/features/maintenance/screens/maintenance_map_screen.dart:760-776, 1413-1440](file:///home/annnpii/Product%20development%20annpii/BssparkingTimeMark/lib/features/maintenance/screens/maintenance_map_screen.dart#L760-L776)
- **Rationale:** Add persistent disk tile caching via `flutter_map_cache` and cull off-screen markers against `_mapController.camera.visibleBounds` to stop continuous network tile fetches and reduce Flutter render tree complexity during map panning.

---

VERDICT: 0 of 6 implemented

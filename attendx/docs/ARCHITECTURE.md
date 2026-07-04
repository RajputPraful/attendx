# Architecture & Design Decisions

## Timetable versioning

A `TimetableVersion` is effective from a date forward. The active version
for any date `D` is resolved as:

```sql
SELECT * FROM timetable_versions
WHERE effective_from <= D
ORDER BY effective_from DESC
LIMIT 1
```

Because `AttendanceRecord` rows reference a specific `ClassSlot` (which
belongs to a specific version), past records are never affected by
creating a newer version — they remain linked to the slot/version that was
actually active on their date. This satisfies requirement #4 directly.

## Auto-marking

`ensure_attendance_records_for_date()` is idempotent: for a given date it
creates a `PRESENT` record for every scheduled slot that doesn't already
have one. It's called:
- whenever `/attendance/day/{date}` is requested (lazy, on read)
- once daily at 23:55 by APScheduler (`services/scheduler.py`)
- on app load via `AppState.refreshAll()` (Flutter) calling `/attendance/auto-mark`

Manual overrides (`PUT /attendance/{id}`) set `auto_marked=False` so the UI
can visually distinguish "auto" vs "confirmed" entries if desired.

## Safe-bunk formula

```
required_fraction = required_percentage / 100
safe_bunks = floor(attended / required_fraction - total_classes)
```

This is the number of additional classes you could miss (NO_CLASS-free
classes, i.e. ABSENT) while keeping your percentage at-or-above the
required threshold, given today's attended/total counts. A negative value
means you're already below the requirement, and the magnitude tells you
(non-exactly) how far under you are — the Dashboard instead surfaces the
"classes needed to recover" number for that case (see
`classes_needed_to_recover` in `attendance_engine.py`) since that is more
directly actionable for a student.

## Attendance units (NO_CLASS handling)

`duration_hours` = attendance units. `NO_CLASS` records are excluded from
both `total_classes` and `attended_classes` — they simply don't count
toward the denominator, exactly as required.

## Notifications

Implemented client-side via `flutter_local_notifications`:
- **Morning reminder**: triggered on app open / a periodic check against
  today's `ClassSlot`s, showing a summary notification.
- **Low attendance warning**: triggered when `AppState.refreshAll()` finds
  a subject whose `status` is `WARNING` or `CRITICAL`.

For true OS-level "fires even if app is closed" daily reminders, wire the
`timezone` + `flutter_local_notifications` `zonedSchedule` API as described
in the package docs, and call `NotificationService` methods from a
`WorkManager`/`BackgroundFetch` task. This is left as the production
hardening step since it depends on your target OS versions and store
policies.

## Firebase sync (optional)

The local SQLite database is the source of truth. To add Firebase sync:

1. Add `firebase_core`, `cloud_firestore` to `pubspec.yaml`.
2. After each successful API call that mutates data (`AppState` methods),
   mirror the same payload to a Firestore collection keyed by a stable
   device/user id.
3. On app start, if a `last_synced_at` timestamp is older than the local
   data's `updated_at`, pull from Firestore and reconcile (last-write-wins,
   or prompt the user on conflict).
4. The FastAPI backend already includes `firebase-admin` in
   `requirements.txt` if you'd rather sync server-side instead (e.g. a
   `/sync/push` endpoint that writes to Firestore using a service account).

This is intentionally not wired up by default, since it requires your own
Firebase project credentials.

## Why FastAPI + SQLite instead of a fully offline-first Flutter app

The brief asks for a FastAPI backend explicitly, with SQLite "local" and
Firebase sync "optional" — read here as: SQLite is the backend's local
database (not a separate on-device DB), and the Flutter app is a thin
client over the API. If you instead want the Flutter app itself to work
fully offline (e.g. using `sqflite` on-device and syncing to FastAPI only
when online), the same models/services here can be ported into a Dart
repository layer with minimal changes — ask if you'd like that variant.

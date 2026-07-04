# Database Schema (SQLite via SQLAlchemy)

## ER Overview

```
Semester (1)
   (independent — defines holiday rules used by all date calculations)

Subject (1) ───< ClassSlot (many)
TimetableVersion (1) ───< ClassSlot (many)
ClassSlot (1) ───< AttendanceRecord (many, one per date the slot occurred)
```

## Tables

### `semesters`
| column | type | notes |
|---|---|---|
| id | INTEGER PK | |
| name | TEXT | default "Current Semester" |
| start_date | DATE | |
| end_date | DATE | |
| saturday_enabled | BOOLEAN | default False (Sun is always holiday) |
| is_active | BOOLEAN | only one active semester at a time |
| created_at | DATETIME | |

### `subjects`
| column | type | notes |
|---|---|---|
| id | INTEGER PK | |
| name | TEXT | required |
| code | TEXT | optional |
| required_percentage | FLOAT | default 75.0 |
| color | TEXT | hex color for UI |
| is_deleted | BOOLEAN | soft-delete (preserves history) |
| created_at | DATETIME | |

### `timetable_versions`
| column | type | notes |
|---|---|---|
| id | INTEGER PK | |
| label | TEXT | e.g. "Timetable from 2026-08-01" |
| effective_from | DATE | indexed; resolves which version applies to a date |
| created_at | DATETIME | |

**Versioning rule:** the version that applies to date `D` is the one with
the **largest** `effective_from <= D`. Creating a new version never
modifies or deletes old ones, so past `AttendanceRecord`s remain correctly
tied to the slot/version that was active when they occurred.

### `class_slots`
| column | type | notes |
|---|---|---|
| id | INTEGER PK | |
| timetable_version_id | INTEGER FK → timetable_versions.id | |
| subject_id | INTEGER FK → subjects.id | |
| day_of_week | INTEGER | 0=Mon … 6=Sun |
| start_time | TIME | |
| end_time | TIME | |
| duration_hours | FLOAT | 1 hour = 1 attendance unit |

### `attendance_records`
| column | type | notes |
|---|---|---|
| id | INTEGER PK | |
| class_slot_id | INTEGER FK → class_slots.id | |
| date | DATE | indexed |
| status | ENUM(PRESENT, ABSENT, NO_CLASS) | default PRESENT |
| units | FLOAT | copied from slot's duration_hours at creation time |
| auto_marked | BOOLEAN | True until a manual override is made |
| updated_at | DATETIME | |

Unique constraint: `(class_slot_id, date)` — exactly one record per slot per
calendar date.

## Why `units` is copied onto the record (not just read from the slot)

If a subject's class duration changes in a later timetable version, past
attendance records must keep reflecting the duration that was actually
taught that day. Copying `duration_hours` into `units` at record-creation
time freezes that historical value.

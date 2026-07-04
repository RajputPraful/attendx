# API Documentation

Base URL (local dev): `http://localhost:8000`
Interactive docs: `http://localhost:8000/docs` (Swagger) once the server is running.

All dates are `YYYY-MM-DD`. All times are `HH:MM:SS`.

## Subjects

| Method | Path | Body | Description |
|---|---|---|---|
| GET | `/subjects` | — | List all (non-deleted) subjects |
| POST | `/subjects` | `{name, code?, required_percentage?, color?}` | Create subject |
| PUT | `/subjects/{id}` | partial fields | Update subject |
| DELETE | `/subjects/{id}` | — | Soft-delete subject |

## Semester

| Method | Path | Body | Description |
|---|---|---|---|
| GET | `/semester` | — | Get active semester (404 if none) |
| POST | `/semester` | `{name?, start_date, end_date, saturday_enabled}` | Create/replace active semester |
| PUT | `/semester/saturday?enabled=true` | — | Toggle Saturday holiday override |

## Timetable

| Method | Path | Body | Description |
|---|---|---|---|
| GET | `/timetable/versions` | — | List all timetable versions (oldest first) |
| POST | `/timetable/versions` | `{label?, effective_from, slots: [{subject_id, day_of_week, start_time, end_time, duration_hours}]}` | Create a new version effective from a date |
| POST | `/timetable/versions/{id}/slots` | single slot object | Add a slot to an existing version |
| PUT | `/timetable/slots/{slot_id}` | slot object | Update a slot |
| DELETE | `/timetable/slots/{slot_id}` | — | Delete a slot |

## Attendance

| Method | Path | Description |
|---|---|---|
| POST | `/attendance/auto-mark?target_date=YYYY-MM-DD` | Auto-mark PRESENT for unmarked classes on a date (defaults today) |
| POST | `/attendance/auto-mark-range?start=...&end=...` | Backfill auto-marking across a range |
| GET | `/attendance/day/{date}` | All attendance records for a date (auto-marks first) |
| GET | `/attendance/calendar?year=2026&month=6` | Per-day summary for calendar view: `ALL_PRESENT / HAS_ABSENT / MIXED / HOLIDAY / PENDING` |
| PUT | `/attendance/{record_id}` | `{status: "PRESENT"\|"ABSENT"\|"NO_CLASS"}` — manual override |

## Dashboard

| Method | Path | Description |
|---|---|---|
| GET | `/dashboard/summary` | Overall % + per-subject stats (total/attended/percentage/safe_bunks/status) |
| GET | `/dashboard/subject/{id}` | Stats for one subject |

## Analytics

| Method | Path | Description |
|---|---|---|
| GET | `/analytics/trend/{subject_id}` | Cumulative attendance % over time + recovery estimate + current safe-bunk count |
| POST | `/analytics/predict/{subject_id}` | `{future_classes_missed, future_classes_attended}` → projected percentage |

## Example: full setup flow

```bash
curl -X POST localhost:8000/semester -H "Content-Type: application/json" \
  -d '{"start_date":"2026-07-01","end_date":"2026-11-30","saturday_enabled":false}'

curl -X POST localhost:8000/subjects -H "Content-Type: application/json" \
  -d '{"name":"Data Structures","code":"CS201","required_percentage":75}'

curl -X POST localhost:8000/timetable/versions -H "Content-Type: application/json" \
  -d '{"label":"Initial Timetable","effective_from":"2026-07-01","slots":[
        {"subject_id":1,"day_of_week":0,"start_time":"09:00:00","end_time":"10:00:00","duration_hours":1.0}
      ]}'

curl -X POST "localhost:8000/attendance/auto-mark"

curl localhost:8000/dashboard/summary
```

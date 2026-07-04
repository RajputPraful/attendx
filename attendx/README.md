# AttendX — Smart Attendance Tracker

AttendX is a full-stack mobile attendance tracking app:

- **Frontend:** Flutter (Material 3, dark mode, animated UI)
- **Backend:** FastAPI (Python) + SQLite
- **Optional:** Firebase sync hook (see `docs/ARCHITECTURE.md`)

## Project layout

```
attendx/
├── backend/        FastAPI app (API, DB models, business logic)
├── frontend/       Flutter app (screens, models, services)
└── docs/           Full documentation
```

## Quick start

See `docs/INSTALLATION.md` for full setup. TL;DR:

```bash
# Backend
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload

# Frontend (in a separate terminal)
cd frontend
flutter pub get
flutter run
```

By default the Flutter app points at `http://10.0.2.2:8000` (Android emulator's
alias for your computer's `localhost`). Change `ApiService.defaultBaseUrl` in
`frontend/lib/services/api_service.dart` for iOS simulator / physical devices.

## Documentation index

- `docs/INSTALLATION.md` — environment setup, running backend & app
- `docs/DATABASE_SCHEMA.md` — full SQLite schema + ER relationships
- `docs/API_DOCUMENTATION.md` — every REST endpoint, request/response shape
- `docs/ARCHITECTURE.md` — design decisions: timetable versioning, safe-bunk
  formula, auto-marking, notifications, Firebase sync hook

# Installation Guide

## 1. Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Python | 3.10+ | for FastAPI backend |
| Flutter SDK | 3.22+ (Dart 3.3+) | `flutter doctor` should be all green |
| Android Studio / Xcode | latest | for emulator/simulator, or use a physical device |

## 2. Backend setup

```bash
cd attendx/backend
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- SQLite database file `attendx.db` is auto-created in `backend/` on first run.
- Interactive API docs: open `http://localhost:8000/docs` (Swagger UI).
- The scheduler (APScheduler) starts automatically and auto-marks the day's
  classes PRESENT at 23:55 daily if you haven't manually overridden them.

### First-time data setup order (important)

1. `POST /semester` — set semester start/end date, Saturday on/off
2. `POST /subjects` — add each subject
3. `POST /timetable/versions` — create your weekly timetable (effective from
   the semester start date, or any later date)
4. From here on, the app auto-marks attendance daily; you only need to
   override specific days via `PUT /attendance/{id}` or the Calendar screen.

If you're installing this mid-semester, call
`POST /attendance/auto-mark-range?start=...&end=...` once to backfill
PRESENT records for already-passed dates, then manually correct any days
you were actually absent.

## 3. Frontend (Flutter) setup

```bash
cd attendx/frontend
flutter pub get
```

### Point the app at your backend

Edit `lib/services/api_service.dart`:

```dart
static const String defaultBaseUrl = 'http://10.0.2.2:8000'; // Android emulator
```

| Target | baseUrl |
|---|---|
| Android emulator | `http://10.0.2.2:8000` |
| iOS simulator | `http://127.0.0.1:8000` |
| Physical device (same Wi-Fi) | `http://<your-computer-LAN-IP>:8000` |

### Run

```bash
flutter run
```

### Android notification permissions

For Android 13+, add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

## 4. Building release artifacts

```bash
# Android APK
flutter build apk --release

# iOS (requires macOS + Xcode)
flutter build ios --release
```

## 5. Optional: Firebase sync

See `docs/ARCHITECTURE.md` → "Firebase sync (optional)" for how to wire
Firestore as a secondary store, mirroring the local SQLite source of truth.

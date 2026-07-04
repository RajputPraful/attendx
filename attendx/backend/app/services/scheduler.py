"""
Background scheduler using APScheduler.
- Runs every day at 23:55 to auto-mark today's classes as PRESENT if untouched.
- Runs every day at 07:30 to (conceptually) trigger the "morning schedule reminder".
  Actual push notifications are sent client-side by the Flutter app
  (flutter_local_notifications) based on the timetable synced from this backend;
  this job exists as a hook for server-driven push (e.g. via FCM) if you wire up
  Firebase Cloud Messaging later.
"""
from apscheduler.schedulers.background import BackgroundScheduler
from datetime import date

from ..database import SessionLocal
from .attendance_engine import ensure_attendance_records_for_date

scheduler = BackgroundScheduler()


def _auto_mark_today_job():
    db = SessionLocal()
    try:
        ensure_attendance_records_for_date(db, date.today())
    finally:
        db.close()


def start_scheduler():
    scheduler.add_job(_auto_mark_today_job, "cron", hour=23, minute=55, id="auto_mark_today", replace_existing=True)
    scheduler.start()

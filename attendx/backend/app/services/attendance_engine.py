"""
Core attendance logic shared by routers:
- resolving which TimetableVersion applies on a given date
- auto-marking PRESENT for past/today's classes
- computing dashboard stats & the safe-bunk formula
- analytics / trend / prediction
"""
import math
from datetime import date, timedelta
from typing import Optional, List

from sqlalchemy.orm import Session
from sqlalchemy import asc

from .. import models


def get_active_timetable_version(db: Session, on_date: date) -> Optional[models.TimetableVersion]:
    """The active version is the most recent one with effective_from <= on_date."""
    return (
        db.query(models.TimetableVersion)
        .filter(models.TimetableVersion.effective_from <= on_date)
        .order_by(models.TimetableVersion.effective_from.desc())
        .first()
    )


def is_holiday(db: Session, on_date: date) -> bool:
    """Sunday always a holiday. Saturday holiday unless enabled on the semester."""
    weekday = on_date.weekday()  # Mon=0..Sun=6
    if weekday == 6:
        return True
    if weekday == 5:
        semester = db.query(models.Semester).filter(models.Semester.is_active == True).first()  # noqa: E712
        saturday_enabled = semester.saturday_enabled if semester else False
        return not saturday_enabled
    return False


def get_slots_for_date(db: Session, on_date: date) -> List[models.ClassSlot]:
    if is_holiday(db, on_date):
        return []
    version = get_active_timetable_version(db, on_date)
    if not version:
        return []
    weekday = on_date.weekday()
    return [s for s in version.class_slots if s.day_of_week == weekday]


def ensure_attendance_records_for_date(db: Session, on_date: date) -> List[models.AttendanceRecord]:
    """
    Auto-mark step. For every class slot scheduled on `on_date` that does not
    already have an AttendanceRecord, create one with status=PRESENT (auto_marked=True).
    Existing records (manual or previously auto-marked) are left untouched.
    """
    slots = get_slots_for_date(db, on_date)
    created = []
    for slot in slots:
        existing = (
            db.query(models.AttendanceRecord)
            .filter(models.AttendanceRecord.class_slot_id == slot.id, models.AttendanceRecord.date == on_date)
            .first()
        )
        if existing:
            continue
        record = models.AttendanceRecord(
            class_slot_id=slot.id,
            date=on_date,
            status=models.AttendanceStatus.PRESENT,
            units=slot.duration_hours,
            auto_marked=True,
        )
        db.add(record)
        created.append(record)
    if created:
        db.commit()
    return created


def auto_mark_range(db: Session, start: date, end: date):
    """Run ensure_attendance_records_for_date for every day in [start, end]."""
    d = start
    total_created = 0
    while d <= end:
        total_created += len(ensure_attendance_records_for_date(db, d))
        d += timedelta(days=1)
    return total_created


def compute_subject_stats(db: Session, subject: models.Subject, upto_date: Optional[date] = None):
    """
    total_classes  = count of records with status != NO_CLASS
    attended       = count of records with status == PRESENT (in attendance UNITS, i.e. duration weighted)
    percentage     = attended / total * 100
    safe_bunks     = floor(attended / required_fraction - total_classes)
                     (required_fraction = required_percentage / 100)
    """
    q = (
        db.query(models.AttendanceRecord)
        .join(models.ClassSlot, models.AttendanceRecord.class_slot_id == models.ClassSlot.id)
        .filter(models.ClassSlot.subject_id == subject.id)
    )
    if upto_date:
        q = q.filter(models.AttendanceRecord.date <= upto_date)
    records = q.all()

    total_classes = sum(r.units for r in records if r.status != models.AttendanceStatus.NO_CLASS)
    attended = sum(r.units for r in records if r.status == models.AttendanceStatus.PRESENT)

    percentage = (attended / total_classes * 100) if total_classes > 0 else 0.0
    required_fraction = (subject.required_percentage or 75.0) / 100.0

    if required_fraction > 0:
        safe_bunks = math.floor(attended / required_fraction - total_classes)
    else:
        safe_bunks = 0
    safe_bunks = max(safe_bunks, 0) if percentage >= subject.required_percentage else min(safe_bunks, 0)

    if percentage >= subject.required_percentage:
        status = "SAFE"
    elif percentage >= subject.required_percentage - 10:
        status = "WARNING"
    else:
        status = "CRITICAL"

    return {
        "total_classes": total_classes,
        "attended_classes": attended,
        "percentage": round(percentage, 2),
        "safe_bunks": safe_bunks,
        "status": status,
    }


def classes_needed_to_recover(attended: float, total: float, required_fraction: float) -> Optional[int]:
    """
    How many additional classes (assuming all attended) are needed for the
    percentage to reach required_fraction again. Returns None if already met.
    Derivation: (attended + x) / (total + x) >= required_fraction
                => x >= (required_fraction*total - attended) / (1 - required_fraction)
    """
    if required_fraction <= 0 or required_fraction >= 1:
        return None
    current = attended / total if total > 0 else 0
    if current >= required_fraction:
        return None
    numerator = required_fraction * total - attended
    denominator = 1 - required_fraction
    x = numerator / denominator
    return max(math.ceil(x), 0)


def build_trend(db: Session, subject: models.Subject) -> List[dict]:
    q = (
        db.query(models.AttendanceRecord)
        .join(models.ClassSlot, models.AttendanceRecord.class_slot_id == models.ClassSlot.id)
        .filter(models.ClassSlot.subject_id == subject.id)
        .order_by(asc(models.AttendanceRecord.date))
    )
    records = q.all()
    trend = []
    cum_total = 0.0
    cum_attended = 0.0
    for r in records:
        if r.status == models.AttendanceStatus.NO_CLASS:
            continue
        cum_total += r.units
        if r.status == models.AttendanceStatus.PRESENT:
            cum_attended += r.units
        pct = (cum_attended / cum_total * 100) if cum_total > 0 else 0.0
        trend.append({"date": r.date, "cumulative_percentage": round(pct, 2)})
    return trend

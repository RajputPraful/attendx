from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional

from .. import models, schemas
from ..database import get_db
from ..services.attendance_engine import ensure_attendance_records_for_date, auto_mark_range, get_slots_for_date

router = APIRouter(prefix="/attendance", tags=["Attendance"])


def _serialize(record: models.AttendanceRecord) -> dict:
    slot = record.class_slot
    return {
        "id": record.id,
        "class_slot_id": record.class_slot_id,
        "date": record.date,
        "status": record.status,
        "units": record.units,
        "auto_marked": record.auto_marked,
        "subject_id": slot.subject_id if slot else None,
        "subject_name": slot.subject.name if slot and slot.subject else None,
        "start_time": slot.start_time if slot else None,
        "end_time": slot.end_time if slot else None,
    }


@router.post("/auto-mark")
def auto_mark(target_date: Optional[date] = None, db: Session = Depends(get_db)):
    """Auto-mark PRESENT for all unmarked classes on target_date (defaults to today)."""
    target_date = target_date or date.today()
    created = ensure_attendance_records_for_date(db, target_date)
    return {"date": target_date, "created": len(created)}


@router.post("/auto-mark-range")
def auto_mark_backfill(start: date, end: date, db: Session = Depends(get_db)):
    """Backfill auto-marking for a date range, e.g. when first setting up the app mid-semester."""
    total = auto_mark_range(db, start, end)
    return {"start": start, "end": end, "records_created": total}


@router.get("/day/{target_date}", response_model=schemas.DayAttendanceOut)
def get_day(target_date: date, db: Session = Depends(get_db)):
    # Ensure today's/past classes are at least auto-marked before returning
    ensure_attendance_records_for_date(db, target_date)
    records = (
        db.query(models.AttendanceRecord)
        .filter(models.AttendanceRecord.date == target_date)
        .all()
    )
    return {"date": target_date, "records": [_serialize(r) for r in records]}


@router.get("/calendar")
def get_calendar(year: int, month: int, db: Session = Depends(get_db)):
    """
    Returns a day-by-day summary for the given month, used to render the
    calendar view (each day colored by overall status: all present / some absent / holiday / no class).
    """
    import calendar as _cal
    days_in_month = _cal.monthrange(year, month)[1]
    result = []
    for day in range(1, days_in_month + 1):
        d = date(year, month, day)
        slots = get_slots_for_date(db, d)
        if not slots:
            result.append({"date": d, "summary": "HOLIDAY"})
            continue
        records = (
            db.query(models.AttendanceRecord)
            .join(models.ClassSlot, models.AttendanceRecord.class_slot_id == models.ClassSlot.id)
            .filter(models.AttendanceRecord.date == d)
            .all()
        )
        statuses = {r.status for r in records}
        if not statuses:
            summary = "PENDING"
        elif statuses == {models.AttendanceStatus.PRESENT}:
            summary = "ALL_PRESENT"
        elif models.AttendanceStatus.ABSENT in statuses:
            summary = "HAS_ABSENT"
        else:
            summary = "MIXED"
        result.append({"date": d, "summary": summary})
    return result


@router.put("/{record_id}", response_model=schemas.AttendanceRecordOut)
def override_attendance(record_id: int, payload: schemas.AttendanceOverride, db: Session = Depends(get_db)):
    record = db.query(models.AttendanceRecord).filter(models.AttendanceRecord.id == record_id).first()
    if not record:
        raise HTTPException(404, "Attendance record not found")
    record.status = payload.status
    record.auto_marked = False
    db.commit()
    db.refresh(record)
    return _serialize(record)

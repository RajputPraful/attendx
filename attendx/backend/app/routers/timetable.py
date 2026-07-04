from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from .. import models, schemas
from ..database import get_db

router = APIRouter(prefix="/timetable", tags=["Timetable"])


@router.get("/versions", response_model=List[schemas.TimetableVersionOut])
def list_versions(db: Session = Depends(get_db)):
    return db.query(models.TimetableVersion).order_by(models.TimetableVersion.effective_from.asc()).all()


@router.post("/versions", response_model=schemas.TimetableVersionOut)
def create_version(payload: schemas.TimetableVersionCreate, db: Session = Depends(get_db)):
    """
    Create a new timetable version effective from a given date.
    Past dates keep using whichever version was active for them
    (resolved at query-time in attendance_engine.get_active_timetable_version),
    so creating a new version never rewrites history.
    """
    version = models.TimetableVersion(label=payload.label, effective_from=payload.effective_from)
    db.add(version)
    db.flush()  # get version.id without committing yet

    for slot in payload.slots:
        db.add(models.ClassSlot(timetable_version_id=version.id, **slot.model_dump()))

    db.commit()
    db.refresh(version)
    return version


@router.post("/versions/{version_id}/slots", response_model=schemas.ClassSlotOut)
def add_slot(version_id: int, payload: schemas.ClassSlotBase, db: Session = Depends(get_db)):
    version = db.query(models.TimetableVersion).filter(models.TimetableVersion.id == version_id).first()
    if not version:
        raise HTTPException(404, "Timetable version not found")
    slot = models.ClassSlot(timetable_version_id=version_id, **payload.model_dump())
    db.add(slot)
    db.commit()
    db.refresh(slot)
    return slot


@router.put("/slots/{slot_id}", response_model=schemas.ClassSlotOut)
def update_slot(slot_id: int, payload: schemas.ClassSlotBase, db: Session = Depends(get_db)):
    slot = db.query(models.ClassSlot).filter(models.ClassSlot.id == slot_id).first()
    if not slot:
        raise HTTPException(404, "Slot not found")
    for k, v in payload.model_dump().items():
        setattr(slot, k, v)
    db.commit()
    db.refresh(slot)
    return slot


@router.delete("/slots/{slot_id}")
def delete_slot(slot_id: int, db: Session = Depends(get_db)):
    slot = db.query(models.ClassSlot).filter(models.ClassSlot.id == slot_id).first()
    if not slot:
        raise HTTPException(404, "Slot not found")
    db.delete(slot)
    db.commit()
    return {"ok": True}

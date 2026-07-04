from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db

router = APIRouter(prefix="/semester", tags=["Semester"])


@router.get("", response_model=schemas.SemesterOut)
def get_semester(db: Session = Depends(get_db)):
    semester = db.query(models.Semester).filter(models.Semester.is_active == True).first()  # noqa: E712
    if not semester:
        raise HTTPException(404, "No semester configured yet")
    return semester


@router.post("", response_model=schemas.SemesterOut)
def set_semester(payload: schemas.SemesterBase, db: Session = Depends(get_db)):
    # Deactivate previous semesters (keep history for past attendance records)
    db.query(models.Semester).update({models.Semester.is_active: False})
    semester = models.Semester(**payload.model_dump(), is_active=True)
    db.add(semester)
    db.commit()
    db.refresh(semester)
    return semester


@router.put("/saturday")
def toggle_saturday(enabled: bool, db: Session = Depends(get_db)):
    semester = db.query(models.Semester).filter(models.Semester.is_active == True).first()  # noqa: E712
    if not semester:
        raise HTTPException(404, "No semester configured yet")
    semester.saturday_enabled = enabled
    db.commit()
    return {"saturday_enabled": semester.saturday_enabled}

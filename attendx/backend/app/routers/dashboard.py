from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db
from ..services.attendance_engine import compute_subject_stats

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/summary", response_model=schemas.DashboardSummary)
def dashboard_summary(db: Session = Depends(get_db)):
    subjects = db.query(models.Subject).filter(models.Subject.is_deleted == False).all()  # noqa: E712
    rows = []
    total_attended = 0.0
    total_classes = 0.0
    for subject in subjects:
        stats = compute_subject_stats(db, subject)
        rows.append(schemas.SubjectDashboard(
            subject_id=subject.id,
            name=subject.name,
            code=subject.code,
            color=subject.color,
            required_percentage=subject.required_percentage,
            **stats,
        ))
        total_attended += stats["attended_classes"]
        total_classes += stats["total_classes"]

    overall = (total_attended / total_classes * 100) if total_classes > 0 else 0.0
    return schemas.DashboardSummary(overall_percentage=round(overall, 2), subjects=rows)


@router.get("/subject/{subject_id}", response_model=schemas.SubjectDashboard)
def subject_dashboard(subject_id: int, db: Session = Depends(get_db)):
    subject = db.query(models.Subject).filter(models.Subject.id == subject_id).first()
    if not subject:
        return None
    stats = compute_subject_stats(db, subject)
    return schemas.SubjectDashboard(
        subject_id=subject.id, name=subject.name, code=subject.code,
        color=subject.color, required_percentage=subject.required_percentage, **stats,
    )

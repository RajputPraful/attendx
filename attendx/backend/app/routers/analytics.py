from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db
from ..services.attendance_engine import compute_subject_stats, build_trend, classes_needed_to_recover

router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/trend/{subject_id}", response_model=schemas.AnalyticsOut)
def trend(subject_id: int, db: Session = Depends(get_db)):
    subject = db.query(models.Subject).filter(models.Subject.id == subject_id).first()
    if not subject:
        raise HTTPException(404, "Subject not found")
    stats = compute_subject_stats(db, subject)
    trend_points = build_trend(db, subject)
    required_fraction = subject.required_percentage / 100.0
    below = stats["percentage"] < subject.required_percentage
    recover = classes_needed_to_recover(stats["attended_classes"], stats["total_classes"], required_fraction) if below else None

    return schemas.AnalyticsOut(
        subject_id=subject.id,
        trend=trend_points,
        is_below_required=below,
        classes_needed_to_recover=recover,
        max_missable_now=stats["safe_bunks"],
    )


@router.post("/predict/{subject_id}")
def predict(subject_id: int, payload: schemas.PredictionRequest, db: Session = Depends(get_db)):
    """
    'What-if' prediction: given a hypothetical number of future classes
    attended/missed (each counted as 1 unit unless you pass weighted units
    client-side), project the resulting percentage and safe-bunk count.
    """
    subject = db.query(models.Subject).filter(models.Subject.id == subject_id).first()
    if not subject:
        raise HTTPException(404, "Subject not found")
    stats = compute_subject_stats(db, subject)

    future_total = payload.future_classes_missed + payload.future_classes_attended
    projected_total = stats["total_classes"] + future_total
    projected_attended = stats["attended_classes"] + payload.future_classes_attended
    projected_pct = (projected_attended / projected_total * 100) if projected_total > 0 else 0.0

    return {
        "subject_id": subject_id,
        "current_percentage": stats["percentage"],
        "projected_percentage": round(projected_pct, 2),
        "required_percentage": subject.required_percentage,
        "will_be_below_required": projected_pct < subject.required_percentage,
    }

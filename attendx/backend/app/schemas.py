"""Pydantic schemas (request/response models)."""
from datetime import date, time, datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict
from .models import AttendanceStatus


# ---------- Subject ----------
class SubjectBase(BaseModel):
    name: str
    code: Optional[str] = None
    required_percentage: float = 75.0
    color: Optional[str] = "#6750A4"


class SubjectCreate(SubjectBase):
    pass


class SubjectUpdate(BaseModel):
    name: Optional[str] = None
    code: Optional[str] = None
    required_percentage: Optional[float] = None
    color: Optional[str] = None


class SubjectOut(SubjectBase):
    model_config = ConfigDict(from_attributes=True)
    id: int


# ---------- Semester ----------
class SemesterBase(BaseModel):
    name: Optional[str] = "Current Semester"
    start_date: date
    end_date: date
    saturday_enabled: bool = False


class SemesterOut(SemesterBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    is_active: bool


# ---------- Timetable ----------
class ClassSlotBase(BaseModel):
    subject_id: int
    day_of_week: int  # 0=Mon ... 6=Sun
    start_time: time
    end_time: time
    duration_hours: float


class ClassSlotOut(ClassSlotBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    timetable_version_id: int


class TimetableVersionCreate(BaseModel):
    label: Optional[str] = "Timetable"
    effective_from: date
    slots: List[ClassSlotBase] = []


class TimetableVersionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    label: str
    effective_from: date
    slots: List[ClassSlotOut] = []


# ---------- Attendance ----------
class AttendanceOverride(BaseModel):
    status: AttendanceStatus


class AttendanceRecordOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    class_slot_id: int
    date: date
    status: AttendanceStatus
    units: float
    auto_marked: bool
    subject_id: Optional[int] = None
    subject_name: Optional[str] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None


class DayAttendanceOut(BaseModel):
    date: date
    records: List[AttendanceRecordOut]


# ---------- Dashboard ----------
class SubjectDashboard(BaseModel):
    subject_id: int
    name: str
    code: Optional[str]
    color: str
    required_percentage: float
    total_classes: float
    attended_classes: float
    percentage: float
    safe_bunks: int
    status: str  # "SAFE" | "WARNING" | "CRITICAL"


class DashboardSummary(BaseModel):
    overall_percentage: float
    subjects: List[SubjectDashboard]


# ---------- Analytics ----------
class TrendPoint(BaseModel):
    date: date
    cumulative_percentage: float


class AnalyticsOut(BaseModel):
    subject_id: int
    trend: List[TrendPoint]
    is_below_required: bool
    classes_needed_to_recover: Optional[int] = None
    max_missable_now: int


class PredictionRequest(BaseModel):
    future_classes_missed: int = 0
    future_classes_attended: int = 0

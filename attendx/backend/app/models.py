"""
SQLAlchemy ORM models for AttendX.

Schema overview
---------------
Semester            : one active semester window (start_date -> end_date)
Subject             : a course/subject with a required attendance %
TimetableVersion    : a named timetable that becomes effective from a given date.
                      Multiple versions can exist; the version active on a given
                      date is the most recent one with effective_from <= date.
ClassSlot           : a recurring weekly slot (day_of_week + start/end time) that
                      belongs to exactly one TimetableVersion and one Subject.
AttendanceRecord    : the *actual* record of whether a specific ClassSlot occurred
                      on a specific date, and what its status was
                      (PRESENT / ABSENT / NO_CLASS).
"""
import enum
from datetime import datetime

from sqlalchemy import (
    Column, Integer, String, Float, Date, Time, Boolean, DateTime,
    ForeignKey, Enum, UniqueConstraint
)
from sqlalchemy.orm import relationship

from .database import Base


class AttendanceStatus(str, enum.Enum):
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"
    NO_CLASS = "NO_CLASS"


class DayOfWeek(int, enum.Enum):
    MONDAY = 0
    TUESDAY = 1
    WEDNESDAY = 2
    THURSDAY = 3
    FRIDAY = 4
    SATURDAY = 5
    SUNDAY = 6


class Semester(Base):
    __tablename__ = "semesters"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, default="Current Semester")
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    saturday_enabled = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class Subject(Base):
    __tablename__ = "subjects"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    code = Column(String, nullable=True)
    required_percentage = Column(Float, default=75.0)  # stored as 0-100
    color = Column(String, default="#6750A4")  # for UI charts/cards
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    class_slots = relationship("ClassSlot", back_populates="subject")


class TimetableVersion(Base):
    __tablename__ = "timetable_versions"

    id = Column(Integer, primary_key=True, index=True)
    label = Column(String, default="Timetable")
    effective_from = Column(Date, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    class_slots = relationship("ClassSlot", back_populates="timetable_version", cascade="all, delete-orphan")


class ClassSlot(Base):
    __tablename__ = "class_slots"

    id = Column(Integer, primary_key=True, index=True)
    timetable_version_id = Column(Integer, ForeignKey("timetable_versions.id"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    day_of_week = Column(Integer, nullable=False)  # 0=Mon ... 6=Sun
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    duration_hours = Column(Float, nullable=False)  # 1 hour = 1 attendance unit

    timetable_version = relationship("TimetableVersion", back_populates="class_slots")
    subject = relationship("Subject", back_populates="class_slots")
    attendance_records = relationship("AttendanceRecord", back_populates="class_slot", cascade="all, delete-orphan")


class AttendanceRecord(Base):
    __tablename__ = "attendance_records"
    __table_args__ = (UniqueConstraint("class_slot_id", "date", name="uq_slot_date"),)

    id = Column(Integer, primary_key=True, index=True)
    class_slot_id = Column(Integer, ForeignKey("class_slots.id"), nullable=False)
    date = Column(Date, nullable=False, index=True)
    status = Column(Enum(AttendanceStatus), default=AttendanceStatus.PRESENT, nullable=False)
    units = Column(Float, nullable=False, default=1.0)  # copied from slot.duration_hours
    auto_marked = Column(Boolean, default=True)  # True until user manually overrides
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    class_slot = relationship("ClassSlot", back_populates="attendance_records")

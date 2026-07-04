"""
AttendX FastAPI backend entrypoint.

Run with:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

Interactive API docs available at /docs once running.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import Base, engine
from .routers import subjects, semester, timetable, attendance, dashboard, analytics
from .services.scheduler import start_scheduler

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="AttendX API",
    description="Backend for the AttendX attendance tracking app",
    version="1.0.0",
)

# Allow the Flutter app (mobile/emulator/desktop) to call this API freely.
# Tighten allow_origins in production if exposing this publicly.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(subjects.router)
app.include_router(semester.router)
app.include_router(timetable.router)
app.include_router(attendance.router)
app.include_router(dashboard.router)
app.include_router(analytics.router)


@app.on_event("startup")
def on_startup():
    start_scheduler()


@app.get("/")
def root():
    return {"app": "AttendX", "status": "running"}

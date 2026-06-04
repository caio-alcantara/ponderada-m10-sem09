from pydantic import BaseModel
from uuid import UUID
from datetime import datetime


class AIAnalysis(BaseModel):
    score: float
    redness: str
    acne: str
    dryness: str
    oiliness: str
    observations: str
    recommendations: str


class RecordOut(BaseModel):
    id: UUID
    user_id: UUID
    photo_url: str
    photo_signed_url: str
    ai_score: float | None = None
    ai_analysis: AIAnalysis | None = None
    notes: str | None = None
    created_at: datetime


class StreakOut(BaseModel):
    streak_days: int
    last_record_date: str | None = None


class PaginatedRecordsOut(BaseModel):
    data: list[RecordOut]
    next_cursor: str | None = None
    has_more: bool


class RecordCompareIn(BaseModel):
    record_id_a: UUID
    record_id_b: UUID


class RecordCompareOut(BaseModel):
    record_a: RecordOut
    record_b: RecordOut
    score_diff: float | None = None
    days_between: int

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, Query, UploadFile, HTTPException, status
from fastapi.responses import Response
from supabase import Client

from app.clients.supabase_client import get_supabase
from app.core.security import get_current_user
from app.schemas.record import (
    AIAnalysis,
    RecordOut,
    PaginatedRecordsOut,
    RecordCompareIn,
    RecordCompareOut,
    StreakOut,
)
import app.services.records_service as records_service
import app.services.storage_service as storage_service
import app.services.ai_service as ai_service

router = APIRouter(prefix="/records", tags=["records"])


def _run_ai_analysis(record_id: str, image_bytes: bytes, mime_type: str):
    from app.clients.supabase_client import get_supabase as _get_sb
    result = ai_service.analyze_skin(image_bytes, mime_type)
    if result is None:
        return
    score = result.get("score")
    sb = _get_sb()
    sb.table("records").update({
        "ai_score": score,
        "ai_analysis": result,
    }).eq("id", record_id).execute()


def _to_record_out(row: dict, supabase: Client) -> RecordOut:
    signed_url = storage_service.get_signed_url(row["photo_url"], supabase)
    ai_analysis = None
    if row.get("ai_analysis") and row["ai_analysis"] != {}:
        try:
            ai_analysis = AIAnalysis(**row["ai_analysis"])
        except Exception:
            ai_analysis = None

    return RecordOut(
        id=row["id"],
        user_id=row["user_id"],
        photo_url=row["photo_url"],
        photo_signed_url=signed_url,
        ai_score=row.get("ai_score"),
        ai_analysis=ai_analysis,
        notes=row.get("notes"),
        created_at=row["created_at"],
    )


@router.get("/streak", response_model=StreakOut)
def streak(
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
):
    return records_service.compute_streak(current_user["user_id"], supabase)


@router.get("/latest", response_model=RecordOut | None)
def latest(
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
):
    row = records_service.get_latest(current_user["user_id"], supabase)
    if not row:
        raise HTTPException(status_code=404, detail="Nenhum registro encontrado.")
    return _to_record_out(row, supabase)


@router.get("", response_model=PaginatedRecordsOut)
def list_records(
    limit: int = Query(20, ge=1, le=100),
    cursor: str | None = Query(None),
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
):
    rows = records_service.list_records(current_user["user_id"], limit + 1, cursor, supabase)
    has_more = len(rows) > limit
    rows = rows[:limit]
    items = [_to_record_out(r, supabase) for r in rows]
    next_cursor = rows[-1]["created_at"] if has_more and rows else None
    return PaginatedRecordsOut(data=items, next_cursor=next_cursor, has_more=has_more)


@router.get("/{record_id}", response_model=RecordOut)
def get_record(
    record_id: UUID,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
):
    row = records_service.get_record(str(record_id), current_user["user_id"], supabase)
    return _to_record_out(row, supabase)


@router.post("/compare", response_model=RecordCompareOut)
def compare_records(
    data: RecordCompareIn,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
):
    user_id = current_user["user_id"]
    row_a = records_service.get_record(str(data.record_id_a), user_id, supabase)
    row_b = records_service.get_record(str(data.record_id_b), user_id, supabase)

    record_a = _to_record_out(row_a, supabase)
    record_b = _to_record_out(row_b, supabase)

    score_diff = None
    if record_a.ai_score is not None and record_b.ai_score is not None:
        score_diff = round(record_a.ai_score - record_b.ai_score, 1)

    dt_a = record_a.created_at
    dt_b = record_b.created_at
    days_between = abs((dt_a - dt_b).days)

    return RecordCompareOut(
        record_a=record_a,
        record_b=record_b,
        score_diff=score_diff,
        days_between=days_between,
    )


@router.post("", response_model=RecordOut, status_code=status.HTTP_201_CREATED)
def create_record(
    background_tasks: BackgroundTasks,
    photo: UploadFile = File(...),
    notes: str | None = Form(None),
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
):
    if photo.content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise HTTPException(status_code=400, detail="Formato de imagem não suportado. Use JPEG, PNG ou WebP.")

    file_bytes = photo.file.read()
    user_id = current_user["user_id"]

    photo_path = storage_service.upload(user_id, file_bytes, photo.content_type, supabase)

    try:
        row = records_service.create_record(user_id, photo_path, notes, supabase)
    except Exception as exc:
        storage_service.delete(photo_path, supabase)
        raise exc

    background_tasks.add_task(_run_ai_analysis, row["id"], file_bytes, photo.content_type)

    return _to_record_out(row, supabase)


@router.delete("/{record_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_record(
    record_id: UUID,
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
):
    photo_url = records_service.delete_record(str(record_id), current_user["user_id"], supabase)
    try:
        storage_service.delete(photo_url, supabase)
    except Exception:
        pass
    return Response(status_code=status.HTTP_204_NO_CONTENT)

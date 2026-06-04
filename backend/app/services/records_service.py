from datetime import datetime, date, timedelta
from uuid import UUID

from fastapi import HTTPException, status
from supabase import Client

from app.schemas.record import AIAnalysis


def create_record(
    user_id: str,
    photo_url: str,
    notes: str | None,
    supabase: Client,
    ai_score: float | None = None,
    ai_analysis: dict | None = None,
) -> dict:
    row = {
        "user_id": user_id,
        "photo_url": photo_url,
        "notes": notes,
    }
    if ai_score is not None:
        row["ai_score"] = ai_score
    if ai_analysis is not None:
        row["ai_analysis"] = ai_analysis

    result = (
        supabase.table("records")
        .insert(row)
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=500, detail="Falha ao criar registro.")
    return result.data[0]


def list_records(
    user_id: str, limit: int, cursor: str | None, supabase: Client
) -> list[dict]:
    query = (
        supabase.table("records")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .order("id", desc=True)
    )
    if cursor:
        query = query.lt("created_at", cursor)
    result = query.limit(limit).execute()
    return result.data or []


def get_record(record_id: str, user_id: str, supabase: Client) -> dict:
    result = (
        supabase.table("records")
        .select("*")
        .eq("id", record_id)
        .eq("user_id", user_id)
        .maybe_single()
        .execute()
    )
    if result is None or not result.data:
        raise HTTPException(status_code=404, detail="Registro não encontrado.")
    return result.data


def delete_record(record_id: str, user_id: str, supabase: Client) -> str:
    record = get_record(record_id, user_id, supabase)
    photo_url = record["photo_url"]

    supabase.table("records").delete().eq("id", record_id).eq("user_id", user_id).execute()
    return photo_url


def get_latest(user_id: str, supabase: Client) -> dict | None:
    result = (
        supabase.table("records")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )
    if not result.data:
        return None
    return result.data[0]


def compute_streak(user_id: str, supabase: Client) -> dict:
    result = (
        supabase.table("records")
        .select("created_at")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .execute()
    )
    if not result.data:
        return {"streak_days": 0, "last_record_date": None}

    unique_dates: list[date] = sorted(
        {
            datetime.fromisoformat(r["created_at"].replace("Z", "+00:00")).date()
            for r in result.data
        },
        reverse=True,
    )

    if not unique_dates:
        return {"streak_days": 0, "last_record_date": None}

    today = date.today()
    if unique_dates[0] == today:
        current = today
    elif unique_dates[0] == today - timedelta(days=1):
        current = today - timedelta(days=1)
    else:
        return {"streak_days": 0, "last_record_date": str(unique_dates[0])}

    streak = 0
    for d in unique_dates:
        if d == current - timedelta(days=streak):
            streak += 1
        else:
            break

    return {"streak_days": streak, "last_record_date": str(unique_dates[0])}

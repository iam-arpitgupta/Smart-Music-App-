"""Router for the search endpoint."""

import asyncio

from fastapi import APIRouter, HTTPException, Query

from app.schemas import SearchResult
from app.services import ytmusic_service

router = APIRouter()


@router.get("/search", response_model=list[SearchResult])
async def search_tracks(
    q: str = Query(..., min_length=1, description="Search term"),
    limit: int = Query(20, ge=1, le=50, description="Max results"),
):
    """
    Search YouTube Music for songs matching the query string.

    Returns a list of tracks with video_id, title, artist, thumbnail, and duration.
    """
    try:
        results = await asyncio.to_thread(ytmusic_service.search, q, limit)
        return results
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"YouTube Music search failed: {exc}")

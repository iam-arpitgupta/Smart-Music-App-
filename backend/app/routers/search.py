"""Router for the search endpoint."""

import asyncio

from fastapi import APIRouter, HTTPException, Query

from app.schemas import ArtistDetail, ArtistResult, SearchResult
from app.services import ytmusic_service

router = APIRouter()


@router.get("/search", response_model=list[SearchResult])
async def search_tracks(
    q: str = Query(..., min_length=1, description="Search term"),
    limit: int = Query(20, ge=1, le=50, description="Max results"),
    filter: str | None = Query(None, description="Optional. 'songs', 'podcasts', 'videos', etc")
):
    """
    Search YouTube Music for items matching the query string.

    Returns a list of tracks with video_id, title, artist, thumbnail, and duration.
    """
    try:
        results = await asyncio.to_thread(ytmusic_service.search, q, limit, filter)
        return results
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"YouTube Music search failed: {exc}")


@router.get("/search/artists", response_model=list[ArtistResult])
async def search_artists(
    q: str = Query(..., min_length=1, description="Artist name"),
    limit: int = Query(10, ge=1, le=30, description="Max results"),
):
    """Search YouTube Music for artists matching the query."""
    try:
        results = await asyncio.to_thread(ytmusic_service.search_artists, q, limit)
        return results
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Artist search failed: {exc}")


@router.get("/artists/{browse_id}", response_model=ArtistDetail)
async def get_artist(browse_id: str):
    """Get artist info and all their songs."""
    try:
        detail = await asyncio.to_thread(ytmusic_service.get_artist_detail, browse_id)
        return detail
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Artist lookup failed: {exc}")


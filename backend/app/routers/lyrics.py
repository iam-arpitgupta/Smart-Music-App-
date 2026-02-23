from fastapi import APIRouter, HTTPException, Query
import asyncio
import httpx

from app.services import ytmusic_service

router = APIRouter()

@router.get("/lyrics/{video_id}")
async def get_lyrics(video_id: str):
    """
    Fetch lyrics for a specific track by video_id.
    Returns 404 if no lyrics are available.
    """
    # ytmusic_service is synchronous, so we offload it to a thread
    lyrics = await asyncio.to_thread(ytmusic_service.get_lyrics, video_id)
    
    if not lyrics:
        raise HTTPException(
            status_code=404,
            detail="Lyrics not available for this track."
        )
        
    return {"lyrics": lyrics}

@router.get("/lyrics")
async def get_synced_lyrics(
    track_name: str = Query(...),
    artist_name: str = Query(...)
):
    """
    Fetch time-synced lyrics from LRCLIB using track and artist name.
    """
    url = f"https://lrclib.net/api/search"
    params = {
        "track_name": track_name,
        "artist_name": artist_name
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
        except httpx.HTTPError:
            return {"type": "error", "message": "Lyrics not found"}
            
    if not data or not isinstance(data, list):
        return {"type": "error", "message": "Lyrics not found"}
        
    top_result = data[0]
    synced_lyrics = top_result.get("syncedLyrics")
    plain_lyrics = top_result.get("plainLyrics")
    
    if synced_lyrics:
        return {"type": "synced", "lyrics": synced_lyrics}
    elif plain_lyrics:
        return {"type": "plain", "lyrics": plain_lyrics}
        
    return {"type": "error", "message": "Lyrics not found"}

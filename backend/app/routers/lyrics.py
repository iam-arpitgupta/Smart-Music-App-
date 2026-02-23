from fastapi import APIRouter, HTTPException
import asyncio

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

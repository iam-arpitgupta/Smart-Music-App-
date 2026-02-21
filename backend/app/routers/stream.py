"""Router for the stream-URL extraction endpoint."""

from fastapi import APIRouter, HTTPException

from app.schemas import StreamResponse
from app.services import stream_service

router = APIRouter()


@router.get("/stream/{video_id}", response_model=StreamResponse)
async def get_stream(video_id: str):
    """
    Extract the direct audio stream URL for a YouTube Music track.

    The returned URL points to Google's CDN and is time-limited
    (see ``expires_in``).  **No audio data is stored on this server.**
    """
    try:
        result = await stream_service.get_stream_url(video_id)

        if not result.stream_url:
            raise HTTPException(
                status_code=404,
                detail=f"Could not extract a stream URL for video_id '{video_id}'.",
            )

        return result
    except HTTPException:
        raise  # re-raise our own 404
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Stream extraction failed: {exc}",
        )

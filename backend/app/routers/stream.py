"""Router for the stream-URL extraction endpoint."""

import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse

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
@router.get("/download/{video_id}")
async def download_stream(video_id: str):
    """
    Proxy the direct audio stream from Google CDN and force a file download.

    This bypasses CORS and browser behaviors that try to autoplay audio files,
    forcing a 'Save As...' native dialog instead.
    """
    try:
        # Get the real CDN stream URL
        result = await stream_service.get_stream_url(video_id)

        if not result.stream_url:
            raise HTTPException(
                status_code=404,
                detail=f"Could not extract a stream URL for video_id '{video_id}'.",
            )

        # Stream it back chunk by chunk to avoid holding the file in memory
        client = httpx.AsyncClient()

        # We must use a background task or generator to stream httpx data and close the client
        async def _stream_generator():
            async with client.stream("GET", result.stream_url) as response:
                if response.status_code != 200:
                    yield b""
                    return
                async for chunk in response.aiter_bytes():
                    yield chunk

        headers = {
            "Content-Disposition": f'attachment; filename="{video_id}.m4a"',
            "Content-Type": "audio/mp4",
        }

        return StreamingResponse(
            _stream_generator(),
            media_type="audio/mp4",
            headers=headers
        )

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Download extraction failed: {exc}",
        )

"""Router for the stream-URL extraction endpoint."""

import httpx
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse

from app.schemas import StreamResponse
from app.services import stream_service

router = APIRouter()


@router.get("/stream/{video_id}")
async def get_stream(video_id: str, request: Request):
    """
    Extract and PROXY the direct audio stream URL for a YouTube.
    We proxy this completely to avoid CORS errors in the Flutter Chrome Web player.
    Supports HTTP Range requests for native HTML5 audio buffering.
    """
    try:
        result = await stream_service.get_stream_url(video_id, audio_only=True)

        if not result.stream_url:
            raise HTTPException(
                status_code=404,
                detail=f"Could not extract a stream URL for video_id '{video_id}'.",
            )

        client = httpx.AsyncClient()
        
        req_headers = {}
        if "range" in request.headers:
            req_headers["range"] = request.headers["range"]

        # 1. Make a preemptive stream request to capture response headers
        response = await client.send(
            client.build_request("GET", result.stream_url, headers=req_headers),
            stream=True
        )

        # 2. Extract crucial headers for HTML5 audio
        resp_headers = {
            "Accept-Ranges": "bytes",
            "Content-Type": response.headers.get("content-type", "audio/mp4"),
            "Content-Disposition": f'inline; filename="{video_id}.m4a"',
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Range",
            "Access-Control-Expose-Headers": "Content-Length, Content-Range"
        }
        
        if "content-range" in response.headers:
            resp_headers["Content-Range"] = response.headers["content-range"]
        if "content-length" in response.headers:
            resp_headers["Content-Length"] = response.headers["content-length"]

        async def _stream_generator():
            async for chunk in response.aiter_bytes():
                yield chunk
            await response.aclose()
            await client.aclose()

        return StreamingResponse(
            _stream_generator(),
            status_code=response.status_code,
            media_type=resp_headers["Content-Type"],
            headers=resp_headers
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc))
@router.get("/download/{video_id}")
async def download_stream(video_id: str):
    """
    Proxy the direct audio stream from Google CDN and force a file download.

    This bypasses CORS and browser behaviors that try to autoplay audio files,
    forcing a 'Save As...' native dialog instead.
    """
    try:
        # Get the real CDN stream URL
        result = await stream_service.get_stream_url(video_id, audio_only=True)

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

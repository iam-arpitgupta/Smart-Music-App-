"""Router for proxying thumbnail images to avoid CORS/rate-limit issues on web."""

import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

router = APIRouter()

# Reusable async client for proxying image requests.
_http_client = httpx.AsyncClient(
    follow_redirects=True,
    timeout=10.0,
    headers={
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    },
)


@router.get("/thumbnail")
async def proxy_thumbnail(url: str) -> Response:
    """
    Proxy a thumbnail image from lh3.googleusercontent.com.

    This avoids CORS issues on Flutter Web and prevents 429 rate-limiting
    by funnelling requests through a single server-side client.
    """
    if not url.startswith("https://lh3.googleusercontent.com"):
        raise HTTPException(status_code=400, detail="Only Google image URLs are supported")

    try:
        # Request a larger thumbnail by replacing size params
        proxied_url = url.replace("w120-h120", "w500-h500").replace("w60-h60", "w500-h500")
        resp = await _http_client.get(proxied_url)
        resp.raise_for_status()
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Failed to fetch thumbnail: {exc}")

    return Response(
        content=resp.content,
        media_type=resp.headers.get("content-type", "image/jpeg"),
        headers={
            "Cache-Control": "public, max-age=86400",
            "Access-Control-Allow-Origin": "*",
        },
    )

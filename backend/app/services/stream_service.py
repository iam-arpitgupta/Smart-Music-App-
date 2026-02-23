"""
Stream Extraction Service — wraps yt-dlp to get direct audio stream URLs.

CRITICAL: This service NEVER downloads files.  It only extracts metadata
and the direct Google CDN URL so the Flutter client can stream directly.
"""

import asyncio
import time
from urllib.parse import parse_qs, urlparse

import yt_dlp

from app.schemas import StreamResponse

# Dynamic yt-dlp format options are now constructed per request


def _extract_info(video_id: str, audio_only: bool = True) -> dict:
    """
    Synchronous yt-dlp extraction — meant to be called via
    ``asyncio.to_thread`` so the event loop is never blocked.
    """
    url = f"https://music.youtube.com/watch?v={video_id}"
    opts = {
        "format": "m4a/bestaudio/best" if audio_only else "best",
        "quiet": True,
        "no_warnings": True,
        "extract_flat": False,
        "skip_download": True,
    }
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
    return info


def _estimate_expiry(stream_url: str) -> int:
    """
    Parse the ``expire`` query-param from the Google CDN URL and convert
    it to a seconds-from-now value.  Falls back to 6 hours if unparseable.
    """
    try:
        parsed = urlparse(stream_url)
        qs = parse_qs(parsed.query)
        expire_ts = int(qs["expire"][0])
        return max(expire_ts - int(time.time()), 0)
    except (KeyError, IndexError, ValueError):
        return 21600  # fallback: 6 hours


async def get_stream_url(video_id: str, audio_only: bool = True) -> StreamResponse:
    """
    Extract the best direct stream URL for *video_id*.

    Runs yt-dlp in a background thread so the async event loop stays free.
    """
    info = await asyncio.to_thread(_extract_info, video_id, audio_only)

    # yt-dlp populates 'url' on the selected format
    stream_url: str = info.get("url", "")

    # If the top-level 'url' is empty, try to find it in 'formats'
    if not stream_url:
        formats = info.get("formats", [])
        # Pick the last audio-only format (yt-dlp sorts worst → best)
        audio_formats = [f for f in formats if f.get("vcodec") == "none"]
        if audio_formats:
            stream_url = audio_formats[-1].get("url", "")
        elif formats:
            stream_url = formats[-1].get("url", "")

    expires_in = _estimate_expiry(stream_url) if stream_url else 0

    return StreamResponse(
        video_id=video_id,
        stream_url=stream_url,
        expires_in=expires_in,
    )

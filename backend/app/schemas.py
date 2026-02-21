"""Pydantic response models for the Music App API."""

from pydantic import BaseModel


class SearchResult(BaseModel):
    """A single search result from YouTube Music."""

    video_id: str
    title: str
    artist: str
    thumbnail: str | None = None
    duration: str | None = None  # e.g. "3:45"


class StreamResponse(BaseModel):
    """The extracted direct stream URL for a given video."""

    video_id: str
    stream_url: str
    expires_in: int  # seconds until the URL expires

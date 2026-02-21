"""Pydantic response models for the Music App API."""

from pydantic import BaseModel


class SearchResult(BaseModel):
    """A single search result from YouTube Music."""

    video_id: str
    title: str
    artist: str
    thumbnail: str | None = None
    duration: str | None = None  # e.g. "3:45"


class ArtistResult(BaseModel):
    """An artist from YouTube Music search."""

    browse_id: str  # channelId / browseId for the artist
    name: str
    thumbnail: str | None = None
    subscribers: str | None = None  # e.g. "1.2M subscribers"


class ArtistDetail(BaseModel):
    """Detailed view of an artist with their songs."""

    browse_id: str
    name: str
    thumbnail: str | None = None
    description: str | None = None
    subscribers: str | None = None
    songs: list[SearchResult] = []


class StreamResponse(BaseModel):
    """The extracted direct stream URL for a given video."""

    video_id: str
    stream_url: str
    expires_in: int  # seconds until the URL expires


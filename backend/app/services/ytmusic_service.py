"""
YouTube Music Service — wraps ytmusicapi for search and radio queues.

Uses an unauthenticated YTMusic instance so no OAuth setup is needed.
"""

from ytmusicapi import YTMusic

from app.schemas import SearchResult

# Single shared instance (unauthenticated).
_ytm = YTMusic()


def search(query: str, limit: int = 20) -> list[SearchResult]:
    """
    Search YouTube Music for songs matching *query*.

    Returns a list of SearchResult objects with normalised fields.
    """
    raw_results = _ytm.search(query, filter="songs", limit=limit)

    results: list[SearchResult] = []
    for item in raw_results:
        # Extract the best available thumbnail URL
        thumbnails = item.get("thumbnails", [])
        thumbnail_url = thumbnails[-1]["url"] if thumbnails else None

        # Duration comes as "M:SS" or "H:MM:SS" — keep as-is
        duration_text = item.get("duration")

        # Artist(s) — join if multiple
        artists = item.get("artists", [])
        artist_name = ", ".join(a.get("name", "") for a in artists) if artists else "Unknown"

        results.append(
            SearchResult(
                video_id=item.get("videoId", ""),
                title=item.get("title", ""),
                artist=artist_name,
                thumbnail=thumbnail_url,
                duration=duration_text,
            )
        )

    return results


def get_watch_playlist(video_id: str) -> list[dict]:
    """
    Fetch the "Watch Playlist" (radio / similar songs queue) for a video.

    Returns raw track dicts — will be used in later phases for autoplay.
    """
    playlist = _ytm.get_watch_playlist(videoId=video_id)
    return playlist.get("tracks", [])

"""
YouTube Music Service — wraps ytmusicapi for search and radio queues.

Uses an unauthenticated YTMusic instance so no OAuth setup is needed.
"""

from ytmusicapi import YTMusic

from app.schemas import ArtistDetail, ArtistResult, SearchResult

# Single shared instance (unauthenticated).
_ytm = YTMusic()


def search(query: str, limit: int = 20, filter: str | None = "songs") -> list[SearchResult]:
    """
    Search YouTube Music for items matching *query* (e.g., songs, podcasts, videos).

    Returns a list of SearchResult objects with normalised fields.
    """
    if filter == "podcasts":
        filter = "episodes"

    raw_results = _ytm.search(query, filter=filter, limit=limit)

    results: list[SearchResult] = []
    for item in raw_results:
        # Extract the best available thumbnail URL
        thumbnails = item.get("thumbnails", [])
        thumbnail_url = thumbnails[-1]["url"] if thumbnails else None

        # Duration comes as "M:SS" or "H:MM:SS" — keep as-is
        duration_text = item.get("duration")

        # Artist(s) — join if multiple
        artists = item.get("artists", [])
        artist_name = "Unknown"
        if artists:
            artist_name = ", ".join(a.get("name", "") for a in artists)
        elif "podcast" in item:
            artist_name = item["podcast"].get("name", "Unknown")

        video_id = item.get("videoId")
        if not video_id:
            continue

        results.append(
            SearchResult(
                video_id=video_id,
                title=item.get("title") or "",
                artist=artist_name,
                thumbnail=thumbnail_url,
                duration=duration_text,
            )
        )

    return results


def search_artists(query: str, limit: int = 10, filter: str | None = None) -> list[ArtistResult]:
    """Search YouTube Music for artists or podcast channels matching *query*."""
    actual_filter = "podcasts" if filter == "podcasts" else "artists"
    raw_results = _ytm.search(query, filter=actual_filter, limit=limit)

    results: list[ArtistResult] = []
    for item in raw_results:
        browse_id = item.get("browseId", "")
        if not browse_id:
            continue

        # Podcasts usually use 'title' instead of 'artist'
        name = item.get("artist") or item.get("title", "Unknown")
        thumbnails = item.get("thumbnails", [])
        thumbnail_url = thumbnails[-1]["url"] if thumbnails else None
        
        # Podcasts use 'author' or have no subscribers. Artists have 'subscribers'.
        subscribers = item.get("subscribers") or item.get("author")

        results.append(
            ArtistResult(
                browse_id=browse_id,
                name=name,
                thumbnail=thumbnail_url,
                subscribers=subscribers,
            )
        )

    return results


def get_artist_detail(browse_id: str) -> ArtistDetail:
    """Get artist info and their songs from YouTube Music. Handles podcasts via get_podcast."""
    
    # Handle Podcast series/channels uniquely
    if browse_id.startswith("MPSP") or browse_id.startswith("PL"):
        podcast_data = _ytm.get_podcast(browse_id)
        name = podcast_data.get("title", "Unknown")
        description = podcast_data.get("description")
        
        author_data = podcast_data.get("author")
        if isinstance(author_data, dict):
            subscribers = author_data.get("name")
        else:
            subscribers = author_data
        
        
        thumbnails = podcast_data.get("thumbnails", [])
        thumbnail_url = thumbnails[-1]["url"] if thumbnails else None
        
        songs: list[SearchResult] = []
        episodes = podcast_data.get("episodes", [])
        for ep in episodes:
            ep_thumbnails = ep.get("thumbnails", [])
            ep_thumb = ep_thumbnails[-1]["url"] if ep_thumbnails else None
            songs.append(
                SearchResult(
                    video_id=ep.get("videoId") or "",
                    title=ep.get("title") or "",
                    artist=name,
                    thumbnail=ep_thumb,
                    duration=ep.get("duration"),
                )
            )
        
        return ArtistDetail(
            browse_id=browse_id,
            name=name,
            description=description,
            subscribers=subscribers,
            thumbnail=thumbnail_url,
            songs=songs,
        )

    # Standard Artist Handling
    try:
        artist_data = _ytm.get_artist(browse_id)

        name = artist_data.get("name", "Unknown")
        description = artist_data.get("description")
        subscribers = artist_data.get("subscribers")

        thumbnails = artist_data.get("thumbnails", [])
        thumbnail_url = thumbnails[-1]["url"] if thumbnails else None

        # Extract songs from the artist page
        songs: list[SearchResult] = []
        songs_section = artist_data.get("songs", {})
        browse_id_songs = songs_section.get("browseId")

        # Retrieve the full list if a browseId is available
        if browse_id_songs:
            try:
                full_songs = _ytm.get_playlist(browse_id_songs, limit=100)
                tracks = full_songs.get("tracks", [])
            except Exception:
                tracks = songs_section.get("results", [])
        else:
            tracks = songs_section.get("results", [])

        for track in tracks:
            video_id = track.get("videoId", "")
            if not video_id:
                continue

            track_thumbnails = track.get("thumbnails", [])
            track_thumb = track_thumbnails[-1]["url"] if track_thumbnails else None
            
            track_artists = track.get("artists", [])
            artist_name = ", ".join(t.get("name", "") for t in track_artists) if track_artists else "Unknown"

            songs.append(
                SearchResult(
                    video_id=track.get("videoId") or "",
                    title=track.get("title") or "",
                    artist=artist_name,
                    thumbnail=track_thumb,
                    duration=track.get("duration"),
                )
            )

        return ArtistDetail(
            browse_id=browse_id,
            name=name,
            thumbnail=thumbnail_url,
            description=description,
            subscribers=subscribers,
            songs=songs,
        )
    except Exception:
        # Fallback for standard YouTube Channels that aren't canonical YouTube Music Artists
        return ArtistDetail(
            browse_id=browse_id,
            name="Channel Details Unavailable",
            description="This is a standard YouTube channel without a YouTube Music artist page.",
            subscribers=None,
            thumbnail=None,
            songs=[],
        )


def get_watch_playlist(video_id: str) -> list[dict]:
    """
    Fetch the "Watch Playlist" (radio / similar songs queue) for a video.

    Returns raw track dicts — will be used in later phases for autoplay.
    """
    playlist = _ytm.get_watch_playlist(videoId=video_id)
    return playlist.get("tracks", [])


def get_trending(limit: int = 15) -> list[SearchResult]:
    """
    Fetch worldwide trending / chart songs from YouTube Music.
    Falls back to a curated search if charts are unavailable.
    """
    try:
        charts = _ytm.get_charts(country="ZZ")  # ZZ = worldwide
        tracks = charts.get("songs", {}).get("items", [])
    except Exception:
        tracks = []

    results: list[SearchResult] = []
    for item in tracks[:limit]:
        video_id = item.get("videoId", "")
        if not video_id:
            continue
        thumbnails = item.get("thumbnails", [])
        thumb = thumbnails[-1]["url"] if thumbnails else None
        artists = item.get("artists", [])
        artist_name = ", ".join(a.get("name", "") for a in artists) if artists else "Unknown"
        results.append(
            SearchResult(
                video_id=video_id,
                title=item.get("title", ""),
                artist=artist_name,
                thumbnail=thumb,
                duration=item.get("duration"),
            )
        )

    # Fallback: search for popular songs if charts returned nothing
    if not results:
        results = search("top hits 2024", limit=limit)

    return results


def get_top_artists(limit: int = 8) -> list[ArtistResult]:
    """
    Fetch top artists from YouTube Music worldwide charts.
    Falls back to searching well-known artists if charts unavailable.
    """
    try:
        charts = _ytm.get_charts(country="ZZ")
        artists_raw = charts.get("artists", {}).get("items", [])
    except Exception:
        artists_raw = []

    results: list[ArtistResult] = []
    for item in artists_raw[:limit]:
        browse_id = item.get("browseId", "")
        if not browse_id:
            continue
        thumbnails = item.get("thumbnails", [])
        thumb = thumbnails[-1]["url"] if thumbnails else None
        results.append(
            ArtistResult(
                browse_id=browse_id,
                name=item.get("title", ""),
                thumbnail=thumb,
                subscribers=item.get("subscribers"),
            )
        )

    # Fallback: search for popular artists if charts returned nothing
    if not results:
        results = search_artists("Taylor Swift", limit=limit)

    return results


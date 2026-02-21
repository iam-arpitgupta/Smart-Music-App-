# Project Plan: Lightweight Personal Music App (Android)

## 1. Project Overview
A personalized, Android-based music streaming application focused on high-quality audio, native equalizer control, and background playback. The app relies on a lightweight Flutter client and a Python/FastAPI backend that uses YouTube Music's library for an infinite catalog and built-in radio features. Playlists and favorites are managed entirely on the user's local device, removing the need for cloud database hosting.

---

## 2. Tech Stack & Architecture



### Frontend (Android Client)
* **Framework:** Flutter (Dart) - Chosen for high-performance native compilation on Android.
* **Audio Engine:** `just_audio` paired with `audio_service` (hooks natively into Android's ExoPlayer).
* **Local Database:** `sqflite` - For storing user playlists, favorites, and track metadata directly on the Android device.
* **State Management:** Riverpod or Bloc.

### Backend (API & Scraper)
* **Framework:** Python with FastAPI. The backend will heavily utilize `async` definitions for its path operations (e.g., `async def get_stream()`). This asynchronous design is critical to ensure that awaiting network responses from `ytmusicapi` and extracting streams via `yt-dlp` does not block the server, allowing it to handle multiple concurrent requests efficiently.
* **Music Metadata & "Autoplay":** `ytmusicapi` - For fetching libraries, search results, and generating "Similar Song" radio queues.
* **Stream Extraction:** `yt-dlp` (or `pytubefix`) - Used strictly to extract the raw, direct Google stream URLs (Opus/AAC) on the fly. 
* **Database:** None. The backend is entirely stateless.

---

## 3. Core Features & Implementation Guidelines

### A. Music Sourcing & Zero-Storage Streaming
* **No File Hosting:** The backend must not download or host `.mp3` or `.mp4` files. 
* **Direct Streaming:** The FastAPI backend receives a track request, uses `yt-dlp` to extract the `bestaudio` stream URL (target: Opus 160kbps or AAC 256kbps), and returns this raw URL to the Flutter app.

### B. Android Background Playback & Call Interruption

* **Foreground Service:** The app must utilize Android's `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission in the `AndroidManifest.xml`.
* **Media Notification:** `audio_service` must show an un-swipeable media notification on the lock screen and pull-down tray to prevent Android Doze from killing the app.
* **Audio Focus:** * Listen for `AUDIOFOCUS_LOSS_TRANSIENT` (Incoming call) -> Trigger `pause()`.
    * Listen for `AUDIOFOCUS_GAIN` (Call ended) -> Trigger `play()` to auto-resume.

### C. Audio DSP (Volume, Bass, EQ)
* Utilize ExoPlayer's native equalizer via the `just_audio` package.
* Expose UI sliders for specific frequency bands (e.g., 60Hz for bass boost) and feed these directly into the native Android hardware DSP.

### D. Autoplay & Similar Songs (ML-Free Approach)
* Utilize `ytmusicapi.get_watch_playlist(videoId)`. 
* When a user selects a song, the backend fetches this "Watch Playlist" (YouTube's equivalent of a radio station) and sends the queue of similar track IDs to the Flutter app to enable endless autoplay.

### E. Playlist & Favorite Management (Local Android Storage)

* **Frontend Role:** The Flutter app uses the `sqflite` package to manage an on-device SQLite database. No network requests are needed to load the user's library.
* **Database Schema (Local):**
    * `favorites` table (`video_id` PK, `title`, `artist`, `thumbnail`)
    * `playlists` table (`id` PK, `name`)
    * `playlist_items` table (`playlist_id`, `video_id`)
* **Functionality:** Users save tracks to local playlists. Tapping a saved track sends the `video_id` to the FastAPI `/stream` endpoint to initiate playback.

---

## 4. REST API Specifications (FastAPI)

### 1. Search for Tracks
* **Endpoint:** `GET /api/v1/search`
* **Query Params:** `q` (string, the search term)

### 2. Get Audio Stream URL
* **Endpoint:** `GET /api/v1/stream/{video_id}`
* **Description:** Uses `yt-dlp` to extract the direct Google media URL.
* **Response:**
```json
{
  "video_id": "dQw4w9WgXcQ",
  "stream_url": "[https://rr1---sn-nx5s...googlevideo.com/videoplayback?...&mime=audio/webm](https://rr1---sn-nx5s...googlevideo.com/videoplayback?...&mime=audio/webm)...",
  "expires_in": 21540
}
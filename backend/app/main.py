"""
Music App Backend — FastAPI Entry Point.

A stateless API that proxies search/stream requests to YouTube Music
via ytmusicapi and yt-dlp.  No audio files are ever stored.
"""

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()  # reads backend/.env into os.environ


from app.routers import dj_agent, search, stream, thumbnail, lyrics

app = FastAPI(
    title="Music App API",
    version="1.0.0",
    description="Lightweight backend for the Android Music App. "
    "Provides search and direct audio stream URL extraction.",
)

# ------------------------------------------------------------------
# CORS — allow all origins during development.
# Tighten this in production to only the Flutter client's origin.
# ------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------------------
# Register routers
# ------------------------------------------------------------------
app.include_router(search.router, prefix="/api/v1", tags=["Search"])
app.include_router(stream.router, prefix="/api/v1", tags=["Stream"])
app.include_router(thumbnail.router, prefix="/api/v1", tags=["Thumbnail"])
app.include_router(lyrics.router, prefix="/api/v1", tags=["Lyrics"])
app.include_router(dj_agent.chat_router, prefix="/api/v1", tags=["Smart DJ"])


@app.get("/", tags=["Health"])
async def health_check():
    """Simple health-check endpoint."""
    return {"status": "ok", "service": "music-app-api"}

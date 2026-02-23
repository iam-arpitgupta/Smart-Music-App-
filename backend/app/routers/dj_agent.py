"""
Smart DJ — Multi-agent chatbot router.

Uses LangGraph with a Supervisor/Router pattern:
  Supervisor ─┬─▶ Mood Agent    (playlist search by feeling / activity)
               ├─▶ Artist Agent  (top tracks by a recommended artist)
               ├─▶ Builder Agent (cross-genre / cross-region custom blend)
               └─▶ END           (just chat, no music action)

Stateless: the Flutter frontend sends the full chat history each request.
All ytmusicapi calls are wrapped in asyncio.to_thread so they never block
the event loop or other streaming endpoints.
"""

import asyncio
import json
import os
import random
import re
from typing import Any, Dict, List, TypedDict

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from ytmusicapi import YTMusic

# ─── Router & shared instances ────────────────────────────────────
chat_router = APIRouter()
_ytm = YTMusic()

# ─── Lazy LLM & Graph (deferred until first /chat call) ──────────
_llm = None
_graph = None


def _get_llm():
    """Lazy-init the ChatOpenAI client. Fails only when actually called."""
    global _llm
    if _llm is None:
        from langchain_openai import ChatOpenAI

        api_key = os.environ.get("OPENAI_API_KEY", "")
        if not api_key:
            raise RuntimeError(
                "OPENAI_API_KEY environment variable is not set. "
                "Set it before using the Smart DJ chat feature."
            )
        _llm = ChatOpenAI(model="gpt-4o-mini", temperature=0.7)
    return _llm


def _get_graph():
    """Lazy-compile the LangGraph workflow on first use."""
    global _graph
    if _graph is not None:
        return _graph

    from langgraph.graph import END, StateGraph

    workflow = StateGraph(AgentState)
    workflow.add_node("supervisor", supervisor_node)
    workflow.add_node("mood_agent", mood_node)
    workflow.add_node("artist_agent", artist_node)
    workflow.add_node("builder_agent", builder_node)
    workflow.set_entry_point("supervisor")

    def _route_logic(state: AgentState) -> str:
        return state["next_route"]

    workflow.add_conditional_edges(
        "supervisor",
        _route_logic,
        {
            "mood_agent": "mood_agent",
            "artist_agent": "artist_agent",
            "builder_agent": "builder_agent",
            "END": END,
        },
    )
    workflow.add_edge("mood_agent", END)
    workflow.add_edge("artist_agent", END)
    workflow.add_edge("builder_agent", END)

    _graph = workflow.compile()
    return _graph


# ─── Request / Response schemas ───────────────────────────────────
class ChatRequest(BaseModel):
    """Incoming chat payload from the Flutter frontend."""

    message: str
    mode: str = "music"
    history: list[dict[str, str]] = []  # [{"role":"user","content":"..."}, ...]


class ChatResponse(BaseModel):
    """Response returned to the frontend."""

    reply: str
    music_data: dict[str, Any] = {}


# ─── LangGraph State ─────────────────────────────────────────────
class AgentState(TypedDict):
    messages: List[Any]
    next_route: str
    extracted: str  # supervisor-extracted hint for worker agents
    mode: str
    music_payload: Dict[str, Any]


# ─── ytmusicapi async tool wrappers ──────────────────────────────


async def _execute_concurrent_search(queries: List[str], mode: str) -> Dict[str, Any]:
    """Execute 2-3 queries concurrently, shuffle, and return exactly 5 items."""
    filter_map = {"podcast": "episodes", "video": "videos"}
    filter_val = filter_map.get(mode, "songs")

    async def _search(q: str) -> List[dict]:
        raw = await asyncio.to_thread(_ytm.search, q, filter_val, None, 5)
        out = []
        for item in raw:
            vid = item.get("videoId", "")
            if not vid:
                continue
            artists = item.get("artists", [])
            thumbs = item.get("thumbnails", [])
            
            artist_name = "Unknown"
            if artists:
                artist_name = ", ".join(a.get("name", "") for a in artists)
            elif "podcast" in item:
                artist_name = item["podcast"].get("name", "Unknown")

            out.append(
                {
                    "video_id": vid,
                    "title": item.get("title", ""),
                    "artist": artist_name,
                    "thumbnail": thumbs[-1]["url"] if thumbs else None,
                    "duration": item.get("duration"),
                }
            )
        return out

    buckets = await asyncio.gather(*[_search(q) for q in queries])
    flat = [item for sublist in buckets for item in sublist]
    random.shuffle(flat)
    return {"type": "tracks", "data": flat[:5]}


async def _get_artist_top_tracks(artist_query: str) -> Dict[str, Any]:
    """Find an artist and return their top songs."""
    results = await asyncio.to_thread(
        _ytm.search, artist_query, "artists", None, 1
    )
    if not results:
        return {"type": "error", "message": "Artist not found."}

    artist_id = results[0].get("browseId", "")
    artist_data = await asyncio.to_thread(_ytm.get_artist, artist_id)

    songs_section = artist_data.get("songs", {})
    tracks = songs_section.get("results", [])[:5]

    songs = []
    for t in tracks:
        vid = t.get("videoId", "")
        if not vid:
            continue
        artists = t.get("artists", [])
        thumbs = t.get("thumbnails", [])
        songs.append(
            {
                "video_id": vid,
                "title": t.get("title", ""),
                "artist": ", ".join(a.get("name", "") for a in artists),
                "thumbnail": thumbs[-1]["url"] if thumbs else None,
                "duration": t.get("duration"),
            }
        )

    return {
        "type": "tracks",
        "artist_name": artist_data.get("name", artist_query),
        "data": songs,
    }


async def _build_custom_blend(genres: List[str], per_genre: int = 6) -> Dict[str, Any]:
    """
    Build a Global Blend playlist from user-specified genres / regions.

    Fires one search per genre concurrently, then interleaves results
    in round-robin order and shuffles lightly for variety.
    """

    async def _search_genre(genre: str) -> List[dict]:
        raw = await asyncio.to_thread(
            _ytm.search, f"top {genre} songs", "songs", None, per_genre
        )
        out: list[dict] = []
        for item in raw:
            vid = item.get("videoId", "")
            if not vid:
                continue
            artists = item.get("artists", [])
            thumbs = item.get("thumbnails", [])
            out.append(
                {
                    "video_id": vid,
                    "title": item.get("title", ""),
                    "artist": ", ".join(a.get("name", "") for a in artists),
                    "thumbnail": thumbs[-1]["url"] if thumbs else None,
                    "duration": item.get("duration"),
                    "genre_tag": genre,
                }
            )
        return out

    # Fire all searches concurrently
    buckets = await asyncio.gather(*[_search_genre(g) for g in genres])

    # Round-robin interleave
    blend: list[dict] = []
    max_len = max((len(b) for b in buckets), default=0)
    for i in range(max_len):
        for bucket in buckets:
            if i < len(bucket):
                blend.append(bucket[i])

    # Light shuffle to avoid strict alternation
    if len(blend) > 4:
        # Shuffle in small windows to keep diversity but break patterns
        window = 3
        for start in range(0, len(blend) - window, window):
            sub = blend[start : start + window]
            random.shuffle(sub)
            blend[start : start + window] = sub

    return {"type": "tracks", "label": "Global Blend", "data": blend}


# ─── Agent nodes ──────────────────────────────────────────────────

_SUPERVISOR_PROMPT = """\
You are the brain of the Smart DJ Chatbot for the Resonance media app.
Carefully read the full conversation and decide the user's intent. 
Keep in mind that the user is currently looking for: {mode} (this could be songs, podcasts, or videos).

ROUTING RULES (apply the FIRST rule that matches):

1. **Greeting / general chat**: The user just wants to talk, says hello,
   asks how you are, or has no media-related request.
   → route = "END", extracted = ""

2. **Mood / Topic / Theme**: The user describes a feeling, emotion,
   activity, or topic (e.g. "I'm sad", "workout time", "comedy", "tech news").
   → route = "mood_agent"
   → extracted = a concise 3-5 word YouTube search query that
     captures their mood or topic.

3. **Artist / Creator recommendation**: The user asks WHO to listen to/watch, wants
   creator suggestions, or names a specific artist/podcaster to explore.
   → route = "artist_agent"
   → extracted = the name of one renowned creator/artist that fits
     the user's request.

4. **Custom mix / blend / multi-genre**: The user asks for a
   mix, blend, mashup, or mentions multiple genres, languages, or
   topics they want combined.
   → route = "builder_agent"
   → extracted = comma-separated list of the genres/topics/styles
     they mentioned.

RESPOND WITH VALID JSON ONLY — no markdown fences, no extra text:
{{"response": "<your friendly conversational reply>", "route": "<mood_agent|artist_agent|builder_agent|END>", "extracted": "<see rules above>"}}
"""


def _parse_supervisor_json(text: str) -> dict:
    """Best-effort extraction of JSON from an LLM response."""
    # Strip markdown code fences if present
    cleaned = re.sub(r"^```(?:json)?\s*", "", text.strip())
    cleaned = re.sub(r"\s*```$", "", cleaned)

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        # Fallback: try to find the first JSON object in the response
        match = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if match:
            return json.loads(match.group(0))
        raise


async def supervisor_node(state: AgentState) -> AgentState:
    from langchain_core.messages import AIMessage, SystemMessage

    llm = _get_llm()
    prompt_text = _SUPERVISOR_PROMPT.format(mode=state.get("mode", "music"))
    response = await llm.ainvoke(
        [SystemMessage(content=prompt_text)] + state["messages"]
    )

    try:
        parsed = _parse_supervisor_json(response.content)
        state["messages"].append(AIMessage(content=parsed.get("response", "")))
        route = parsed.get("route", "END")
        if route not in ("mood_agent", "artist_agent", "builder_agent", "END"):
            route = "END"
        state["next_route"] = route
        state["extracted"] = parsed.get("extracted", "")
    except Exception:
        state["messages"].append(
            AIMessage(
                content="Hey! I'm here to help you find the perfect music. "
                "What are you in the mood for?"
            )
        )
        state["next_route"] = "END"
        state["extracted"] = ""

    return state


async def mood_node(state: AgentState) -> AgentState:
    """Fetch a mood-based playlist.

    Uses the supervisor's pre-extracted search query when available,
    otherwise falls back to an LLM call.
    """
    from langchain_core.messages import SystemMessage

    query = state.get("extracted", "").strip()
    llm = _get_llm()
    prompt = SystemMessage(
        content=f"Based on the user's intent to look for {state['mode']} content and the extracted hint '{query}', "
        "generate strictly a JSON array of 2 to 3 very diverse, sophisticated search queries. "
        "Output ONLY a raw JSON array of strings, e.g. [\"query 1\", \"query 2\"]. Nothing else."
    )
    llm_resp = await llm.ainvoke([prompt] + state["messages"])
    
    try:
        cleaned = re.sub(r"^```(?:json)?\s*", "", llm_resp.content.strip())
        cleaned = re.sub(r"\s*```$", "", cleaned)
        queries = json.loads(cleaned)
        if not isinstance(queries, list):
            queries = [str(query)]
    except Exception:
        queries = [query or "top hits"]

    payload = await _execute_concurrent_search(queries, state["mode"])
    state["music_payload"] = payload
    return state


async def artist_node(state: AgentState) -> AgentState:
    """Recommend an artist and return their top tracks.

    Uses the supervisor's pre-extracted artist name when available,
    otherwise asks the LLM for a recommendation.
    """
    from langchain_core.messages import SystemMessage

    artist_name = state.get("extracted", "").strip()
    if not artist_name:
        llm = _get_llm()
        prompt = SystemMessage(
            content="Based on the conversation, name one renowned musical "
            "artist that perfectly fits the user's vibe or request. "
            "Output ONLY the artist's full name, nothing else."
        )
        llm_resp = await llm.ainvoke([prompt] + state["messages"])
        artist_name = llm_resp.content.strip().strip('"')

    payload = await _get_artist_top_tracks(artist_name)
    state["music_payload"] = payload
    return state


async def builder_node(state: AgentState) -> AgentState:
    """Build a custom multi-genre blend playlist.

    Reads the supervisor's comma-separated genre list, fires concurrent
    searches, and interleaves results into a Global Blend.
    """
    from langchain_core.messages import SystemMessage

    raw = state.get("extracted", "").strip()
    if raw:
        genres = [g.strip() for g in raw.split(",") if g.strip()]
    else:
        # Fallback: ask the LLM to extract genres from chat history
        llm = _get_llm()
        prompt = SystemMessage(
            content="The user wants a custom music blend. List the genres, "
            "languages, or regions they want as a comma-separated string. "
            "Output ONLY the comma-separated list, nothing else. "
            "Example: Punjabi, Hindi, English pop, Spanish"
        )
        llm_resp = await llm.ainvoke([prompt] + state["messages"])
        genres = [g.strip() for g in llm_resp.content.strip().split(",") if g.strip()]

    if not genres:
        genres = ["Global hits"]  # safety net

    payload = await _build_custom_blend(genres)
    state["music_payload"] = payload
    return state


# ─── FastAPI endpoint ─────────────────────────────────────────────


def _history_to_messages(history: list[dict[str, str]]) -> list:
    """Convert the frontend's [{role, content}] into LangChain messages."""
    from langchain_core.messages import AIMessage, HumanMessage

    msgs = []
    for item in history:
        role = item.get("role", "user")
        content = item.get("content", "")
        if role == "user":
            msgs.append(HumanMessage(content=content))
        else:
            msgs.append(AIMessage(content=content))
    return msgs


@chat_router.post("/chat", response_model=ChatResponse)
async def chat_endpoint(req: ChatRequest):
    """
    Stateless chat endpoint.

    The frontend sends the current message + full chat history.  The
    supervisor analyses intent and routes to the appropriate specialist
    agent (mood / artist / builder) or just replies with text.
    """
    try:
        from langchain_core.messages import AIMessage, HumanMessage

        graph = _get_graph()
        messages = _history_to_messages(req.history)
        messages.append(HumanMessage(content=req.message))

        initial_state: AgentState = {
            "messages": messages,
            "next_route": "",
            "extracted": "",
            "mode": req.mode.lower(),
            "music_payload": {},
        }

        final_state = await graph.ainvoke(initial_state)

        reply = ""
        for msg in reversed(final_state["messages"]):
            if isinstance(msg, AIMessage):
                reply = msg.content
                break

        return ChatResponse(
            reply=reply,
            music_data=final_state.get("music_payload", {}),
        )

    except RuntimeError as exc:
        # Catches the missing OPENAI_API_KEY error gracefully
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Smart DJ error: {exc}",
        )

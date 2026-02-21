"""
Smart DJ — Multi-agent chatbot router.

Uses LangGraph with a Supervisor/Router pattern:
  Supervisor ─┬─▶ Mood Agent   (playlist search)
               ├─▶ Artist Agent (top tracks by artist)
               ├─▶ Blend Agent  (cross-cultural chart blend)
               └─▶ END          (just chat, no music action)

Stateless: the Flutter frontend sends the full chat history each request.
All ytmusicapi calls are wrapped in asyncio.to_thread so they never block
the event loop or other streaming endpoints.
"""

import asyncio
import json
import os
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
    workflow.add_node("blend_agent", blend_node)
    workflow.set_entry_point("supervisor")

    def _route_logic(state: AgentState) -> str:
        return state["next_route"]

    workflow.add_conditional_edges(
        "supervisor",
        _route_logic,
        {
            "mood_agent": "mood_agent",
            "artist_agent": "artist_agent",
            "blend_agent": "blend_agent",
            "END": END,
        },
    )
    workflow.add_edge("mood_agent", END)
    workflow.add_edge("artist_agent", END)
    workflow.add_edge("blend_agent", END)

    _graph = workflow.compile()
    return _graph


# ─── Request / Response schemas ───────────────────────────────────
class ChatRequest(BaseModel):
    """Incoming chat payload from the Flutter frontend."""

    message: str
    history: list[dict[str, str]] = []  # [{"role":"user","content":"..."}, ...]


class ChatResponse(BaseModel):
    """Response returned to the frontend."""

    reply: str
    music_data: dict[str, Any] = {}


# ─── LangGraph State ─────────────────────────────────────────────
class AgentState(TypedDict):
    messages: List[Any]
    next_route: str
    music_payload: Dict[str, Any]


# ─── ytmusicapi async tool wrappers ──────────────────────────────


async def _search_songs(query: str, limit: int = 8) -> Dict[str, Any]:
    """Search YTMusic for songs matching a mood query (returns playable tracks)."""
    raw = await asyncio.to_thread(_ytm.search, query, "songs", None, limit)
    songs = []
    for item in raw:
        vid = item.get("videoId", "")
        if not vid:
            continue
        artists = item.get("artists", [])
        thumbs = item.get("thumbnails", [])
        songs.append(
            {
                "video_id": vid,
                "title": item.get("title", ""),
                "artist": ", ".join(a.get("name", "") for a in artists),
                "thumbnail": thumbs[-1]["url"] if thumbs else None,
                "duration": item.get("duration"),
            }
        )
    return {"type": "tracks", "data": songs}


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


async def _get_blend() -> Dict[str, Any]:
    """Interleave trending tracks from India, US, and Global charts."""
    charts_in, charts_us, charts_zz = await asyncio.gather(
        asyncio.to_thread(_ytm.get_charts, "IN"),
        asyncio.to_thread(_ytm.get_charts, "US"),
        asyncio.to_thread(_ytm.get_charts, "ZZ"),
    )

    def _extract(charts: dict, n: int = 5) -> list[dict]:
        items = charts.get("videos", {}).get("items", [])[:n]
        out = []
        for t in items:
            vid = t.get("videoId", "")
            if not vid:
                continue
            artists = t.get("artists", [])
            thumbs = t.get("thumbnails", [])
            out.append(
                {
                    "video_id": vid,
                    "title": t.get("title", ""),
                    "artist": ", ".join(a.get("name", "") for a in artists),
                    "thumbnail": thumbs[-1]["url"] if thumbs else None,
                }
            )
        return out

    in_songs = _extract(charts_in)
    us_songs = _extract(charts_us)
    zz_songs = _extract(charts_zz)

    blend: list[dict] = []
    max_len = max(len(in_songs), len(us_songs), len(zz_songs), 1)
    for i in range(max_len):
        if i < len(in_songs):
            blend.append(in_songs[i])
        if i < len(us_songs):
            blend.append(us_songs[i])
        if i < len(zz_songs):
            blend.append(zz_songs[i])

    return {"type": "tracks", "data": blend}


# ─── Agent nodes ──────────────────────────────────────────────────

_SUPERVISOR_PROMPT = """\
You are a Smart DJ Chatbot for the Resonance music app.
Analyze the conversation and decide what the user needs.

Rules:
1. If the user just wants to chat or says hello, reply naturally and
   set route to "END".
2. If they want a playlist for a mood, vibe, or activity, set route
   to "mood_agent".
3. If they ask WHO to listen to or want artist recommendations, set
   route to "artist_agent".
4. If they want a mix/blend of global, Hindi, or Punjabi songs, set
   route to "blend_agent".

You MUST respond with valid JSON only — no markdown, no backticks:
{"response": "<your conversational text>", "route": "<mood_agent|artist_agent|blend_agent|END>"}
"""


def _parse_supervisor_json(text: str) -> dict:
    """Best-effort extraction of JSON from an LLM response."""
    cleaned = re.sub(r"^```(?:json)?\s*", "", text.strip())
    cleaned = re.sub(r"\s*```$", "", cleaned)
    return json.loads(cleaned)


async def supervisor_node(state: AgentState) -> AgentState:
    from langchain_core.messages import AIMessage, SystemMessage

    llm = _get_llm()
    response = await llm.ainvoke(
        [SystemMessage(content=_SUPERVISOR_PROMPT)] + state["messages"]
    )

    try:
        parsed = _parse_supervisor_json(response.content)
        state["messages"].append(AIMessage(content=parsed["response"]))
        route = parsed.get("route", "END")
        if route not in ("mood_agent", "artist_agent", "blend_agent", "END"):
            route = "END"
        state["next_route"] = route
    except Exception:
        state["messages"].append(
            AIMessage(
                content="Hey! I'm here to help you find the perfect music. "
                "What are you in the mood for?"
            )
        )
        state["next_route"] = "END"

    return state


async def mood_node(state: AgentState) -> AgentState:
    from langchain_core.messages import SystemMessage

    llm = _get_llm()
    prompt = SystemMessage(
        content="Generate a 3-5 word YouTube Music search query that "
        "captures the user's mood or activity. Output ONLY the "
        "query string, nothing else."
    )
    llm_resp = await llm.ainvoke([prompt] + state["messages"])
    payload = await _search_songs(llm_resp.content.strip().strip('"'))
    state["music_payload"] = payload
    return state


async def artist_node(state: AgentState) -> AgentState:
    from langchain_core.messages import SystemMessage

    llm = _get_llm()
    prompt = SystemMessage(
        content="Name one musical artist that perfectly fits the user's "
        "mood or request. Output ONLY the artist's name, nothing else."
    )
    llm_resp = await llm.ainvoke([prompt] + state["messages"])
    payload = await _get_artist_top_tracks(llm_resp.content.strip().strip('"'))
    state["music_payload"] = payload
    return state


async def blend_node(state: AgentState) -> AgentState:
    payload = await _get_blend()
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
    agent (mood / artist / blend) or just replies with text.
    """
    try:
        from langchain_core.messages import AIMessage, HumanMessage

        graph = _get_graph()
        messages = _history_to_messages(req.history)
        messages.append(HumanMessage(content=req.message))

        initial_state: AgentState = {
            "messages": messages,
            "next_route": "",
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

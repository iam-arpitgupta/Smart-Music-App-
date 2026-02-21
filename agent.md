# Smart DJ Agent Integration Plan

## 1. Context & Architecture
This module adds a multi-agent AI chatbot to our existing FastAPI music streaming backend. It uses a **Stateless Supervisor/Router Architecture** via LangGraph. The Flutter frontend will pass the chat history on every request. The AI will analyze the intent and trigger asynchronous `ytmusicapi` tools to return JSON data (playlists, artists, or custom blends) without requiring a backend database.

## 2. Multi-Agent Roster
1. **Supervisor Agent:** Analyzes the conversation. Replies with text if it's just chat, or routes to a specialist if the user wants music.
2. **Mood Agent:** Translates emotions into a YouTube playlist search query.
3. **Artist Agent:** Suggests a specific artist based on the vibe and fetches their top tracks.
4. **Blend Agent:** Creates a custom cross-cultural queue by fetching and interleaving trending charts (India, US, Global).

## 3. Implementation Code (FastAPI Router + LangGraph)
This code should be saved as a new module (e.g., `dj_agent.py`) and imported into the main FastAPI application.

```python
import os
import json
from typing import TypedDict, List, Dict, Any
from fastapi import APIRouter, Request, HTTPException
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, END
from ytmusicapi import YTMusic

# Initialize Router and ytmusicapi
chat_router = APIRouter()
ytmusic = YTMusic()

# ---------------------------------------------------------
# 1. State & LLM Setup
# ---------------------------------------------------------
class AgentState(TypedDict):
    messages: List[Any]
    next_route: str
    music_payload: Dict[str, Any]

# Ensure OPENAI_API_KEY is in your environment variables
llm = ChatOpenAI(model="gpt-4o-mini", temperature=0.7)

# ---------------------------------------------------------
# 2. Async Tools (ytmusicapi)
# ---------------------------------------------------------
async def search_yt_playlists(query: str) -> Dict[str, Any]:
    """Fetches top playlists based on a specific mood query."""
    results = ytmusic.search(query=query, filter="playlists", limit=3)
    return {"type": "playlists", "data": results}

async def get_yt_artist_top_tracks(artist_query: str) -> Dict[str, Any]:
    """Finds an artist and fetches their top songs."""
    search_results = ytmusic.search(query=artist_query, filter="artists", limit=1)
    if not search_results:
        return {"type": "error", "message": "Artist not found."}
    
    artist_id = search_results[0]["browseId"]
    artist_data = ytmusic.get_artist(artist_id)
    return {"type": "artist_tracks", "data": artist_data.get("songs", {}).get("results", [])[:5]}

async def get_global_hindi_punjabi_blend() -> Dict[str, Any]:
    """Fetches and interleaves trending charts from IN, US, and Global."""
    charts_in = ytmusic.get_charts(country='IN')
    charts_us = ytmusic.get_charts(country='US')
    charts_zz = ytmusic.get_charts(country='ZZ')
    
    in_songs = charts_in.get("videos", {}).get("items", [])[:5]
    us_songs = charts_us.get("videos", {}).get("items", [])[:5]
    zz_songs = charts_zz.get("videos", {}).get("items", [])[:5]
    
    blend = []
    max_len = max(len(in_songs), len(us_songs), len(zz_songs))
    for i in range(max_len):
        if i < len(in_songs): blend.append(in_songs[i])
        if i < len(us_songs): blend.append(us_songs[i])
        if i < len(zz_songs): blend.append(zz_songs[i])
        
    return {"type": "blend", "data": blend}

# ---------------------------------------------------------
# 3. Agent Nodes
# ---------------------------------------------------------
async def supervisor_node(state: AgentState):
    sys_prompt = SystemMessage(content="""
    You are a Smart DJ Chatbot. Analyze the conversation. 
    If the user just wants to chat, respond naturally and set route to 'END'.
    If they want a playlist for a mood/activity, set route to 'mood_agent'.
    If they want to know WHO to listen to, set route to 'artist_agent'.
    If they want a mix/blend of global, Hindi, or Punjabi songs, set route to 'blend_agent'.
    
    Respond strictly in JSON format: {"response": "your text", "route": "mood_agent|artist_agent|blend_agent|END"}
    """)
    
    response = await llm.ainvoke([sys_prompt] + state["messages"])
    
    try:
        # Clean the response in case the LLM wraps it in markdown code blocks
        clean_json = response.content.strip('` \njson')
        parsed = json.loads(clean_json)
        state["messages"].append(AIMessage(content=parsed["response"]))
        state["next_route"] = parsed["route"]
    except Exception as e:
        state["messages"].append(AIMessage(content="I'm vibing too hard right now. Let's just play some music!"))
        state["next_route"] = "END"
        
    return state

async def mood_node(state: AgentState):
    sys_prompt = SystemMessage(content="Generate a 3-5 word YouTube Music search query for the user's mood. Only output the query string.")
    query = await llm.ainvoke([sys_prompt] + state["messages"])
    payload = await search_yt_playlists(query.content)
    state["music_payload"] = payload
    return state

async def artist_node(state: AgentState):
    sys_prompt = SystemMessage(content="Name one musical artist that perfectly fits the user's mood/request. Only output the artist name.")
    artist = await llm.ainvoke([sys_prompt] + state["messages"])
    payload = await get_yt_artist_top_tracks(artist.content)
    state["music_payload"] = payload
    return state

async def blend_node(state: AgentState):
    payload = await get_global_hindi_punjabi_blend()
    state["music_payload"] = payload
    return state

# ---------------------------------------------------------
# 4. Graph Compilation
# ---------------------------------------------------------
workflow = StateGraph(AgentState)

workflow.add_node("supervisor", supervisor_node)
workflow.add_node("mood_agent", mood_node)
workflow.add_node("artist_agent", artist_node)
workflow.add_node("blend_agent", blend_node)

workflow.set_entry_point("supervisor")

def route_logic(state: AgentState):
    return state["next_route"]

workflow.add_conditional_edges("supervisor", route_logic, {
    "mood_agent": "mood_agent",
    "artist_agent": "artist_agent",
    "blend_agent": "blend_agent",
    "END": END
})

workflow.add_edge("mood_agent", END)
workflow.add_edge("artist_agent", END)
workflow.add_edge("blend_agent", END)

app_graph = workflow.compile()

# ---------------------------------------------------------
# 5. FastAPI Endpoint (To be included in main.py)
# ---------------------------------------------------------
@chat_router.post("/chat")
async def chat_endpoint(request: Request):
    try:
        data = await request.json()
        user_message = data.get("message")
        
        if not user_message:
            raise HTTPException(status_code=400, detail="Message is required")
            
        initial_state = {
            "messages": [HumanMessage(content=user_message)],
            "next_route": "",
            "music_payload": {}
        }
        
        # Invoke the graph
        final_state = await app_graph.ainvoke(initial_state)
        
        return {
            "reply": final_state["messages"][-1].content,
            "music_data": final_state.get("music_payload", {})
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
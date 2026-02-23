> **Role:** Expert Python Backend Developer & AI Architect
> 
> **Context:** I am expanding my existing FastAPI + LangGraph "Smart DJ" backend. I have added two new UI buttons to my Flutter frontend: "Podcast" and "Stream Video". 
> 
> **CRITICAL INSTRUCTION:** **DO NOT** rewrite the entire app from scratch. **DO NOT** output generic boilerplate. Only provide the specific, updated Python code blocks needed to implement these new features within my existing codebase.
> 
> **Requirements to Implement:**
> 
> 1. **Mode Routing (Schema Update):** Update the `ChatRequest` Pydantic schema for the `/api/v1/chat` endpoint to accept a `mode` string parameter (defaulting to `"music"`, but accepting `"podcast"` or `"video"`).
> 
> 2. **Strict API Filtering & Randomization (Tool Update):** Refactor the tool that fetches data from `ytmusicapi` to strictly enforce this mode mapping:
>    * `"podcast"` -> `filter="podcasts"`
>    * `"video"` -> `filter="videos"`
>    * `"music"` -> `filter="songs"`
>    * **The Logic:** The LLM must generate a list of 2-3 diverse search queries. You must fetch results for all queries concurrently. Flatten the resulting lists, shuffle them for serendipity/freshness, and return exactly 5 items in the JSON payload.
> 
> 3. **The `yt-dlp` Stream Endpoint:** Add a new GET endpoint: `/api/v1/stream/{video_id}`.
>    * Use the `yt-dlp` library to extract the direct `.m3u8` or `.mp4` streaming URL.
>    * Configure `ydl_opts` with `{'format': 'best', 'quiet': True, 'skip_download': True}`.
> 
> 4. **Strict Async Execution:** You MUST wrap the synchronous `yt-dlp` extraction and the `ytmusicapi.search` calls inside `await asyncio.to_thread()`. For the multiple search queries in Step 2, you must execute those threaded calls concurrently using `asyncio.gather()`. Blocking the main FastAPI event loop is strictly forbidden.
> 
> Please provide the exact Python code for the updated schema, the new async tool logic, and the streaming endpoint.
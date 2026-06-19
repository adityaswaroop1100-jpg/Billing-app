import os
import sys
from fastapi import FastAPI, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any

# Ensure parent directory is in path so we can import agent and index
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agent.claude_client import query_claude, detect_persona_type, PERSONAS
from index.db import DB_PATH, init_db, add_session, query_semantic, get_recent_sessions, delete_memory_last_hour, delete_all_memory, start_model_loading, get_setting, set_setting
from index.search import search_universal, index_directory

# Initialize Database and load embedding model in background
init_db()
start_model_loading()

app = FastAPI(title="Zenith Core Daemon")

# Enable CORS for Electron app calls
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In production we can narrow down
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatMessage(BaseModel):
    role: str # 'user' or 'assistant'
    content: str

class QueryRequest(BaseModel):
    image_base64: Optional[str] = None
    image_media_type: Optional[str] = "image/png"
    ocr_text: Optional[str] = None
    user_query: Optional[str] = None
    active_app: Optional[str] = None
    window_title: Optional[str] = None
    explain_level: str = "peer"
    chat_history: Optional[List[ChatMessage]] = None
    api_key: Optional[str] = None
    save_to_memory: bool = True
    use_screen_context: bool = False

class IndexRequest(BaseModel):
    directory_path: str

class SettingsRequest(BaseModel):
    key: str
    value: str

@app.get("/api/health")
def health_check():
    return {"status": "ok", "message": "Zenith core daemon is running"}

@app.post("/api/query")
def api_query(request: QueryRequest):
    # Convert chat history to dict format for the client
    history_dicts = None
    if request.chat_history:
        history_dicts = [{"role": h.role, "content": h.content} for h in request.chat_history]
        
    print(f"Received query request, active app: {request.active_app}, explain level: {request.explain_level}, use_screen_context: {request.use_screen_context}")
    
    # Query database for last 5 minutes of OCR text if screen context is requested
    screen_context = None
    if request.use_screen_context:
        try:
            from datetime import datetime, timedelta
            import sqlite3
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            threshold = (datetime.utcnow() - timedelta(minutes=5)).isoformat()
            cursor.execute("""
                SELECT snippet_text FROM sessions 
                WHERE timestamp >= ? AND snippet_text IS NOT NULL AND snippet_text != ''
            """, (threshold,))
            rows = cursor.fetchall()
            conn.close()
            if rows:
                # Deduplicate and join
                unique_snippets = list(dict.fromkeys([r[0].strip() for r in rows if r[0]]))
                screen_context = "\n---\n".join(unique_snippets)
        except Exception as e:
            print(f"Error fetching screen context from SQLite: {e}")

    # Query Claude
    answer = query_claude(
        api_key=request.api_key,
        image_base64=request.image_base64,
        image_media_type=request.image_media_type,
        ocr_text=request.ocr_text,
        user_query=request.user_query,
        active_app=request.active_app,
        window_title=request.window_title,
        explain_level=request.explain_level,
        chat_history=history_dicts,
        screen_context=screen_context
    )
    
    # Identify persona title
    persona_type = detect_persona_type(request.active_app)
    persona_title = PERSONAS.get(persona_type, PERSONAS["default"])["title"]
    
    # Save to local SQLite memory if requested and not an error
    if request.save_to_memory and not answer.startswith("Error"):
        # If it's a follow-up, we don't save a separate session OR we can save it.
        # Ideally, we only save the initial visual selection session or the full summary.
        # Let's save the query and answer to memory.
        # For simplicity, we save the first interaction context.
        # We can store the query or the OCR text as snippet.
        snippet = request.ocr_text or request.user_query or ""
        # If it's a screenshot, we might save a placeholder or write base64 to a local temp file.
        # We'll save a screenshot path if we decide to cache them. For now, let's keep database size small.
        try:
            add_session(
                app_name=request.active_app,
                window_title=request.window_title,
                snippet_text=snippet,
                screenshot_path=None, # In Phase 3 we can write to a thumb file if needed
                answer=answer,
                explain_level=request.explain_level
            )
        except Exception as e:
            print(f"Failed to record session in memory database: {e}")
            
    return {
        "answer": answer,
        "persona": persona_title
    }

@app.get("/api/search")
def api_search(q: str):
    if not q:
        return {"memory": [], "files": []}
    return search_universal(q)

@app.get("/api/memory")
def api_get_memory(limit: int = 20):
    return get_recent_sessions(limit)

@app.delete("/api/memory/last_hour")
def api_delete_last_hour():
    count = delete_memory_last_hour()
    return {"status": "ok", "deleted_count": count}

@app.delete("/api/memory/all")
def api_delete_all():
    delete_all_memory()
    return {"status": "ok"}

@app.post("/api/index/directory")
def api_index_directory(request: IndexRequest):
    if not os.path.exists(request.directory_path):
        raise HTTPException(status_code=400, detail="Directory path does not exist")
    # Trigger background/sync indexing (for now sync is fine or we can run a thread)
    # Since it's a local app, running it directly is okay, or we can use a simple threading lock
    index_directory(request.directory_path)
    return {"status": "ok", "message": f"Successfully indexed {request.directory_path}"}

@app.post("/api/settings")
def api_set_setting(request: SettingsRequest):
    set_setting(request.key, request.value)
    return {"status": "ok"}

@app.get("/api/settings/{key}")
def api_get_setting(key: str):
    val = get_setting(key)
    return {"key": key, "value": val}

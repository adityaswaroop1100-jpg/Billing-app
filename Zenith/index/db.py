import sqlite3
import os
import json
from datetime import datetime
import numpy as np

# Path to SQLite DB
DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "zenith.db")

import threading

# We will load the sentence transformer model asynchronously in the background
_model = None
_model_loading = False

def get_embedding_model():
    global _model
    return _model

def start_model_loading():
    global _model, _model_loading
    if _model is not None or _model_loading:
        return
        
    def load():
        global _model, _model_loading
        _model_loading = True
        try:
            print("Loading sentence-transformers model in the background...")
            from sentence_transformers import SentenceTransformer
            _model = SentenceTransformer("all-MiniLM-L6-v2")
            print("Sentence-transformers model loaded successfully!")
        except Exception as e:
            print(f"Error loading sentence-transformers model: {e}")
            _model = None
        finally:
            _model_loading = False
            
    thread = threading.Thread(target=load, daemon=True)
    thread.start()

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Create sessions table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            app_name TEXT,
            window_title TEXT,
            snippet_text TEXT,
            screenshot_path TEXT,
            answer TEXT,
            explain_level TEXT,
            embedding BLOB
        )
    """)
    
    # Create file search cache table for local file search
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS file_index (
            path TEXT PRIMARY KEY,
            filename TEXT NOT NULL,
            extension TEXT,
            content_snippet TEXT,
            last_modified REAL
        )
    """)
    
    # Create settings table for robust key storage
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    """)
    
    conn.commit()
    conn.close()
    print("Database initialized at", DB_PATH)

def add_session(app_name, window_title, snippet_text, screenshot_path, answer, explain_level):
    init_db() # ensure it exists
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    timestamp = datetime.utcnow().isoformat()
    embedding_blob = None
    
    # Compute embedding if snippet_text or answer is present
    text_to_embed = f"{snippet_text or ''} {answer or ''}".strip()
    if text_to_embed:
        model = get_embedding_model()
        if model is not None:
            try:
                # encode returns a numpy array, which we convert to float32
                embedding_arr = model.encode(text_to_embed, normalize_embeddings=True)
                embedding_blob = embedding_arr.astype(np.float32).tobytes()
            except Exception as e:
                print(f"Failed to generate embedding: {e}")

    cursor.execute("""
        INSERT INTO sessions (timestamp, app_name, window_title, snippet_text, screenshot_path, answer, explain_level, embedding)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (timestamp, app_name, window_title, snippet_text, screenshot_path, answer, explain_level, embedding_blob))
    
    conn.commit()
    conn.close()
    print("Added memory session.")

def query_semantic(query_text, limit=5):
    init_db()
    model = get_embedding_model()
    
    if model is None:
        # Fallback to simple keyword search if model fails to load
        return query_keyword(query_text, limit)
        
    try:
        query_vector = model.encode(query_text, normalize_embeddings=True).astype(np.float32)
    except Exception as e:
        print(f"Error encoding query: {e}")
        return query_keyword(query_text, limit)
        
    conn = sqlite3.connect(DB_PATH)
    # Return rows as dicts
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    cursor.execute("SELECT id, timestamp, app_name, window_title, snippet_text, screenshot_path, answer, explain_level, embedding FROM sessions")
    rows = cursor.fetchall()
    
    results = []
    for row in rows:
        similarity = 0.0
        if row['embedding']:
            try:
                db_vector = np.frombuffer(row['embedding'], dtype=np.float32)
                # Since embeddings are unit-normalized, dot product is cosine similarity
                similarity = float(np.dot(query_vector, db_vector))
            except Exception as e:
                print(f"Error computing similarity for row {row['id']}: {e}")
                
        results.append({
            "id": row['id'],
            "timestamp": row['timestamp'],
            "app_name": row['app_name'],
            "window_title": row['window_title'],
            "snippet_text": row['snippet_text'],
            "screenshot_path": row['screenshot_path'],
            "answer": row['answer'],
            "explain_level": row['explain_level'],
            "similarity": similarity
        })
    
    conn.close()
    
    # Sort by similarity descending
    results.sort(key=lambda x: x["similarity"], reverse=True)
    return results[:limit]

def query_keyword(query_text, limit=5):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    like_pat = f"%{query_text}%"
    cursor.execute("""
        SELECT id, timestamp, app_name, window_title, snippet_text, screenshot_path, answer, explain_level
        FROM sessions
        WHERE snippet_text LIKE ? OR answer LIKE ? OR app_name LIKE ?
        ORDER BY timestamp DESC
        LIMIT ?
    """, (like_pat, like_pat, like_pat, limit))
    
    rows = cursor.fetchall()
    conn.close()
    
    return [dict(row) for row in rows]

def get_recent_sessions(limit=10):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, timestamp, app_name, window_title, snippet_text, screenshot_path, answer, explain_level
        FROM sessions
        ORDER BY timestamp DESC
        LIMIT ?
    """, (limit,))
    rows = cursor.fetchall()
    conn.close()
    return [dict(row) for row in rows]

def delete_memory_last_hour():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    # Delete where timestamp is within the last 1 hour
    # We use ISO format, so we can calculate timestamp threshold in Python
    from datetime import timedelta
    threshold = (datetime.utcnow() - timedelta(hours=1)).isoformat()
    cursor.execute("DELETE FROM sessions WHERE timestamp >= ?", (threshold,))
    conn.commit()
    deleted = cursor.rowcount
    conn.close()
    return deleted

def delete_all_memory():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("DELETE FROM sessions")
    conn.commit()
    conn.close()

def get_setting(key, default=None):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT value FROM settings WHERE key = ?", (key,))
    row = cursor.fetchone()
    conn.close()
    return row[0] if row else default

def set_setting(key, value):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", (key, value))
    conn.commit()
    conn.close()

if __name__ == "__main__":
    init_db()

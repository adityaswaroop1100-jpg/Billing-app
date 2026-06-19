import sqlite3
import os
import time
from .db import DB_PATH, init_db

# Supported extensions for text indexing
TEXT_EXTENSIONS = {'.txt', '.md', '.py', '.js', '.jsx', '.json', '.html', '.css', '.csv', '.ini', '.cfg', '.yaml', '.yml'}

def index_file(conn, file_path):
    cursor = conn.cursor()
    filename = os.path.basename(file_path)
    ext = os.path.splitext(filename)[1].lower()
    
    try:
        stat = os.stat(file_path)
        last_modified = stat.st_mtime
        
        # Check if already indexed and unmodified
        cursor.execute("SELECT last_modified FROM file_index WHERE path = ?", (file_path,))
        row = cursor.fetchone()
        if row and row[0] >= last_modified:
            return # skip, already up-to-date
            
        content_snippet = ""
        # Only read content for text files
        if ext in TEXT_EXTENSIONS:
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content_snippet = f.read(1024) # index first 1KB
            except Exception as e:
                print(f"Error reading file content {file_path}: {e}")
                
        cursor.execute("""
            INSERT OR REPLACE INTO file_index (path, filename, extension, content_snippet, last_modified)
            VALUES (?, ?, ?, ?, ?)
        """, (file_path, filename, ext, content_snippet, last_modified))
        
    except Exception as e:
        print(f"Error indexing file {file_path}: {e}")

def index_directory(dir_path):
    if not os.path.exists(dir_path):
        print(f"Directory {dir_path} does not exist.")
        return
        
    init_db()
    conn = sqlite3.connect(DB_PATH)
    
    print(f"Indexing directory: {dir_path}...")
    count = 0
    for root, dirs, files in os.walk(dir_path):
        # Ignore hidden files/dirs (like .git, .env, venv)
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        if 'venv' in dirs:
            dirs.remove('venv')
        if 'node_modules' in dirs:
            dirs.remove('node_modules')
            
        for file in files:
            if file.startswith('.'):
                continue
            file_path = os.path.join(root, file)
            index_file(conn, file_path)
            count += 1
            if count % 100 == 0:
                conn.commit()
                
    conn.commit()
    conn.close()
    print(f"Indexed {count} files in {dir_path}.")

def search_files(query_str, limit=10):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    like_pat = f"%{query_str}%"
    cursor.execute("""
        SELECT path, filename, extension, content_snippet, last_modified
        FROM file_index
        WHERE filename LIKE ? OR content_snippet LIKE ?
        ORDER BY filename ASC
        LIMIT ?
    """, (like_pat, like_pat, limit))
    
    rows = cursor.fetchall()
    conn.close()
    
    return [dict(row) for row in rows]

def search_universal(query_str, limit=5):
    from .db import query_semantic
    
    # 1. Search semantic memory
    memory_results = query_semantic(query_str, limit=limit)
    
    # 2. Search local files
    file_results = search_files(query_str, limit=limit)
    
    return {
        "memory": memory_results,
        "files": file_results
    }

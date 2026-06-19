import sys
import os

# Ensure project root is in path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from index.db import init_db, add_session, query_semantic, get_recent_sessions, delete_all_memory

def test_database_flow():
    print("Running database tests...")
    
    # 1. Initialize DB
    init_db()
    
    # 2. Clear existing entries
    delete_all_memory()
    
    # 3. Add test sessions
    print("Adding sample sessions...")
    add_session(
        app_name="Google Chrome",
        window_title="Quantum Physics Wikipedia",
        snippet_text="Quantum mechanics is a fundamental theory in physics that provides a description of the physical properties of nature at the scale of atoms and subatomic particles.",
        screenshot_path=None,
        answer="This text explains quantum mechanics at the atomic level.",
        explain_level="peer"
    )
    
    add_session(
        app_name="VS Code",
        window_title="app.py",
        snippet_text="def bubble_sort(arr): n = len(arr) for i in range(n): for j in range(0, n-i-1): if arr[j] > arr[j+1]: arr[j], arr[j+1] = arr[j+1], arr[j]",
        screenshot_path=None,
        answer="This is a standard implementation of bubble sort algorithm in Python.",
        explain_level="expert"
    )
    
    # 4. Check recent sessions
    sessions = get_recent_sessions()
    assert len(sessions) == 2, f"Expected 2 sessions, got {len(sessions)}"
    print("✓ Successfully saved and retrieved recent sessions.")
    
    # 5. Test keyword/semantic queries
    print("Testing semantic search...")
    # A query about algorithms should match the bubble sort session
    results = query_semantic("sorting algorithm in python")
    assert len(results) > 0, "No results returned for sorting query"
    
    best_match = results[0]
    print(f"Query: 'sorting algorithm in python' -> Best Match App: {best_match['app_name']}, Similarity: {best_match.get('similarity', 0.0)}")
    assert "bubble_sort" in best_match["snippet_text"] or "sort" in best_match["answer"], "Best match is not bubble sort"
    
    # A query about physics should match the quantum mechanics session
    results_physics = query_semantic("atoms and subatomic particles")
    assert len(results_physics) > 0, "No results returned for physics query"
    best_match_physics = results_physics[0]
    print(f"Query: 'atoms and subatomic particles' -> Best Match App: {best_match_physics['app_name']}, Similarity: {best_match_physics.get('similarity', 0.0)}")
    assert "Quantum" in best_match_physics["snippet_text"], "Best match is not quantum physics"
    
    print("✓ All database tests passed successfully!")

if __name__ == "__main__":
    test_database_flow()

import React, { useState, useEffect } from 'react';
import { Shield, Key, FolderOpen, RefreshCw, Trash2, Eye, EyeOff, Search, BookOpen, Clock, FileText } from 'lucide-react';

export default function Settings() {
  const [apiKey, setApiKey] = useState('');
  const [showKey, setShowKey] = useState(false);
  const [indexingDir, setIndexingDir] = useState('');
  const [memorySessions, setMemorySessions] = useState([]);
  const [isIndexing, setIsIndexing] = useState(false);
  const [indexingStatus, setIndexingStatus] = useState('');
  const [screenMemoryEnabled, setScreenMemoryEnabled] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState(null);
  
  // Load API Key from DB or localStorage on mount
  useEffect(() => {
    const savedKey = localStorage.getItem('anthropic_api_key') || '';
    setApiKey(savedKey);
    fetchApiKey();
    fetchMemory();
  }, []);

  const fetchApiKey = async () => {
    try {
      const res = await fetch('http://localhost:5001/api/settings/anthropic_api_key');
      if (res.ok) {
        const data = await res.json();
        if (data.value) {
          setApiKey(data.value);
          localStorage.setItem('anthropic_api_key', data.value);
        }
      }
    } catch (e) {
      console.error("Failed to load API key from DB:", e);
    }
  };

  const handleSaveApiKey = async () => {
    try {
      const res = await fetch('http://localhost:5001/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ key: 'anthropic_api_key', value: apiKey })
      });
      if (res.ok) {
        localStorage.setItem('anthropic_api_key', apiKey);
        alert('API Key saved successfully to local database!');
      } else {
        alert('Failed to save API Key to database.');
      }
    } catch (e) {
      alert('Failed to connect to backend settings service.');
    }
  };

  const fetchMemory = async () => {
    try {
      const res = await fetch('http://localhost:5001/api/memory?limit=8');
      const data = await res.json();
      setMemorySessions(data);
    } catch (e) {
      console.error("Failed to load memory sessions:", e);
    }
  };

  const handleIndexDirectory = async () => {
    if (!indexingDir) {
      alert("Please enter a directory path first.");
      return;
    }
    setIsIndexing(true);
    setIndexingStatus('Indexing in progress...');
    try {
      const res = await fetch('http://localhost:5001/api/index/directory', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ directory_path: indexingDir })
      });
      if (res.ok) {
        setIndexingStatus('Indexing completed successfully!');
      } else {
        const error = await res.json();
        setIndexingStatus(`Error: ${error.detail || 'Failed to index'}`);
      }
    } catch (e) {
      setIndexingStatus('Failed to connect to backend indexer.');
    } finally {
      setIsIndexing(false);
    }
  };

  const handleDeleteLastHour = async () => {
    if (confirm("Are you sure you want to delete memory from the last hour?")) {
      try {
        await fetch('http://localhost:5001/api/memory/last_hour', { method: 'DELETE' });
        fetchMemory();
      } catch (e) {
        alert("Failed to delete memory.");
      }
    }
  };

  const handleDeleteAll = async () => {
    if (confirm("Are you sure you want to delete ALL Zenith memory? This cannot be undone.")) {
      try {
        await fetch('http://localhost:5001/api/memory/all', { method: 'DELETE' });
        fetchMemory();
      } catch (e) {
        alert("Failed to clear memory.");
      }
    }
  };

  const handleSearch = async (val) => {
    setSearchQuery(val);
    if (!val.trim()) {
      setSearchResults(null);
      return;
    }
    try {
      const res = await fetch(`http://localhost:5001/api/search?q=${encodeURIComponent(val)}`);
      if (res.ok) {
        const data = await res.json();
        setSearchResults(data);
      }
    } catch (e) {
      console.error("Search failed:", e);
    }
  };

  return (
    <div style={styles.container}>
      {/* Sidebar / Menu */}
      <div style={styles.sidebar}>
        <div style={styles.brandContainer}>
          <div style={styles.brandLogo}>Z</div>
          <span style={styles.brandTitle}>Zenith OS</span>
        </div>
        <div style={styles.sidebarSection}>
          <h3 style={styles.sidebarHeader}>Navigation</h3>
          <div style={{ ...styles.sidebarItem, ...styles.sidebarActive }}>
            <Shield size={16} />
            <span>Control Center</span>
          </div>
        </div>
        <div style={styles.shortcutGuide}>
          <div style={{ fontWeight: '600', marginBottom: '4px', fontSize: '0.75rem' }}>Overlay Hotkey:</div>
          <kbd style={styles.kbd}>
            {navigator.platform.toUpperCase().indexOf('MAC') >= 0 ? '⌥ + ⌘ + Space' : 'Ctrl + Space'}
          </kbd>
        </div>
      </div>

      {/* Main Settings Panel */}
      <div style={styles.mainContent}>
        <header style={styles.header}>
          <h2>Control Center</h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>Configure API keys, local indexing scopes, and privacy settings.</p>
        </header>

        <div style={styles.scrollArea}>
          {/* 1. API Configuration */}
          <section style={styles.sectionCard}>
            <div style={styles.sectionTitle}>
              <Key size={18} color="var(--color-primary)" />
              <h3>Claude LLM API Configuration</h3>
            </div>
            <div style={styles.inputGroup}>
              <label style={styles.label}>Anthropic API Key</label>
              <div style={styles.passwordContainer}>
                <input
                  type={showKey ? "text" : "password"}
                  value={apiKey}
                  onChange={(e) => setApiKey(e.target.value)}
                  placeholder="sk-ant-..."
                  style={styles.inputField}
                />
                <button onClick={() => setShowKey(!showKey)} style={styles.iconBtn}>
                  {showKey ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
              <button onClick={handleSaveApiKey} className="btn-primary" style={{ marginTop: '12px', width: 'fit-content' }}>
                Save API Key
              </button>
            </div>
          </section>

          {/* 2. Privacy & Permission Center */}
          <section style={styles.sectionCard}>
            <div style={styles.sectionTitle}>
              <Shield size={18} color="var(--color-accent)" />
              <h3>Permission & Privacy Center</h3>
            </div>
            
            <div style={styles.permissionList}>
              <div style={styles.permissionRow}>
                <div>
                  <div style={styles.permissionLabel}>Screen Capture Permission</div>
                  <div style={styles.permissionDesc}>Required to capture marquee selections for AI vision analysis.</div>
                </div>
                <span style={{ ...styles.badge, ...styles.badgeActive }}>Granted</span>
              </div>

              <div style={styles.permissionRow}>
                <div>
                  <div style={styles.permissionLabel}>Active App Detection</div>
                  <div style={styles.permissionDesc}>Reads process metadata on capture to adjust assistant personas.</div>
                </div>
                <span style={{ ...styles.badge, ...styles.badgeActive }}>Active</span>
              </div>

              <div style={styles.permissionRow}>
                <div>
                  <div style={styles.permissionLabel}>Continuous Screen Memory (Timeline)</div>
                  <div style={styles.permissionDesc}>Opt-in to log all screenshots and history locally in an encrypted DB.</div>
                </div>
                <label style={styles.switch}>
                  <input 
                    type="checkbox" 
                    checked={screenMemoryEnabled} 
                    onChange={(e) => setScreenMemoryEnabled(e.target.checked)} 
                  />
                  <span style={styles.slider}></span>
                </label>
              </div>
              
              {screenMemoryEnabled && (
                <div style={styles.recordingAlert}>
                  <span style={styles.recordingDot}></span>
                  <span style={{ fontSize: '0.8rem', color: 'var(--color-secondary)' }}>Timeline logging is enabled. Logs are strictly stored locally.</span>
                </div>
              )}
            </div>
          </section>

          {/* 3. Local Machine File Indexing */}
          <section style={styles.sectionCard}>
            <div style={styles.sectionTitle}>
              <FolderOpen size={18} color="var(--color-warning)" />
              <h3>Universal Search Directory Indexer</h3>
            </div>
            <div style={styles.inputGroup}>
              <label style={styles.label}>Absolute Path to index files</label>
              <input
                type="text"
                value={indexingDir}
                onChange={(e) => setIndexingDir(e.target.value)}
                placeholder="/Users/username/Documents/Project"
                style={{ ...styles.inputField, width: '100%' }}
              />
              <button 
                onClick={handleIndexDirectory} 
                disabled={isIndexing}
                className="btn-secondary" 
                style={{ marginTop: '12px', display: 'flex', alignItems: 'center', gap: '8px', width: 'fit-content' }}
              >
                {isIndexing ? <RefreshCw size={14} className="spin-animation" /> : <FolderOpen size={14} />}
                {isIndexing ? 'Indexing...' : 'Index Folder'}
              </button>
              {indexingStatus && <div style={styles.statusText}>{indexingStatus}</div>}
            </div>
          </section>

          {/* 4. Local Database Activity Log / Memory deletion */}
          <section style={styles.sectionCard}>
            <div style={styles.sectionTitle}>
              <Clock size={18} color="var(--color-secondary)" />
              <h3>Local AI Memory Log & Universal Search</h3>
            </div>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.8rem', marginBottom: '12px' }}>
              Search across your semantic memory logs and indexed workspace files, or manage database storage.
            </p>

            {/* Universal Search Bar */}
            <div style={{ position: 'relative', marginBottom: '16px' }}>
              <input 
                type="text" 
                value={searchQuery}
                onChange={(e) => handleSearch(e.target.value)}
                placeholder="Type to search memory (semantic) & files (content)..."
                style={{ ...styles.inputField, width: '100%', paddingLeft: '38px' }}
              />
              <Search size={16} color="var(--text-muted)" style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)' }} />
            </div>

            {searchResults ? (
              <div style={styles.searchResultsContainer}>
                {/* Memory Matches */}
                <h4 style={styles.searchSubheader}>Memory Matches ({searchResults.memory.length})</h4>
                <div style={{ ...styles.logList, marginBottom: '20px' }}>
                  {searchResults.memory.length === 0 ? (
                    <div style={styles.emptyLogs}>No matching memory logs.</div>
                  ) : (
                    searchResults.memory.map((session) => (
                      <div key={session.id} style={styles.logItem}>
                        <div style={styles.logMeta}>
                          <span style={styles.logApp}>{session.app_name || 'General'}</span>
                          <span style={styles.logTime}>{new Date(session.timestamp).toLocaleDateString()}</span>
                        </div>
                        <div style={styles.logSnippet}>{session.snippet_text || 'Visual capture'}</div>
                        <div style={styles.logAnswer}>{session.answer}</div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--color-primary)', marginTop: '6px', fontWeight: '600' }}>
                          Match Confidence: {Math.round((session.similarity || 0) * 100)}%
                        </div>
                      </div>
                    ))
                  )}
                </div>

                {/* File Matches */}
                <h4 style={styles.searchSubheader}>Workspace File Matches ({searchResults.files.length})</h4>
                <div style={styles.fileList}>
                  {searchResults.files.length === 0 ? (
                    <div style={styles.emptyLogs}>No matching indexed files found.</div>
                  ) : (
                    searchResults.files.map((file) => (
                      <div key={file.path} style={styles.fileItem}>
                        <div style={styles.fileHeader}>
                          <FileText size={14} color="var(--color-warning)" style={{ marginRight: '6px' }} />
                          <span style={styles.fileName}>{file.filename}</span>
                        </div>
                        <div style={styles.filePath}>{file.path}</div>
                        {file.content_snippet && (
                          <pre style={styles.fileSnippet}>
                            <code>{file.content_snippet}</code>
                          </pre>
                        )}
                      </div>
                    ))
                  )}
                </div>
              </div>
            ) : (
              <>
                <div style={styles.memoryControls}>
                  <button onClick={handleDeleteLastHour} style={styles.deleteBtn}>
                    <Trash2 size={12} />
                    <span>Delete Last Hour</span>
                  </button>
                  <button onClick={handleDeleteAll} style={styles.clearBtn}>
                    <Trash2 size={12} />
                    <span>Clear All Memory</span>
                  </button>
                  <button onClick={fetchMemory} style={styles.refreshBtn}>
                    <RefreshCw size={12} />
                    <span>Refresh Log</span>
                  </button>
                </div>

                <div style={styles.logList}>
                  {memorySessions.length === 0 ? (
                    <div style={styles.emptyLogs}>No visual logs captured yet. Press the hotkey to start!</div>
                  ) : (
                    memorySessions.map((session) => (
                      <div key={session.id} style={styles.logItem}>
                        <div style={styles.logMeta}>
                          <span style={styles.logApp}>{session.app_name || 'General'}</span>
                          <span style={styles.logTime}>{new Date(session.timestamp).toLocaleTimeString()}</span>
                        </div>
                        <div style={styles.logSnippet}>{session.snippet_text || 'Visual capture'}</div>
                        <div style={styles.logAnswer}>{session.answer?.substring(0, 100)}...</div>
                      </div>
                    ))
                  )}
                </div>
              </>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}

const styles = {
  container: {
    display: 'flex',
    height: '100vh',
    background: '#07070A',
    color: 'var(--text-main)',
  },
  sidebar: {
    width: '240px',
    background: '#0B0B0F',
    borderRight: '1px solid var(--border-subtle)',
    display: 'flex',
    flexDirection: 'column',
    padding: '24px 16px',
    justifyContent: 'space-between',
  },
  brandContainer: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    marginBottom: '32px',
  },
  brandLogo: {
    width: '32px',
    height: '32px',
    borderRadius: '8px',
    background: 'linear-gradient(135deg, var(--color-primary), var(--color-secondary))',
    color: 'white',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontWeight: '700',
    fontSize: '1.2rem',
  },
  brandTitle: {
    fontWeight: '700',
    fontSize: '1.1rem',
    letterSpacing: '-0.02em',
  },
  sidebarSection: {
    flexGrow: 1,
  },
  sidebarHeader: {
    fontSize: '0.75rem',
    textTransform: 'uppercase',
    letterSpacing: '0.05em',
    color: 'var(--text-muted)',
    marginBottom: '12px',
    paddingLeft: '8px',
  },
  sidebarItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    padding: '10px 12px',
    borderRadius: '8px',
    fontSize: '0.9rem',
    fontWeight: '500',
    color: 'var(--text-muted)',
    cursor: 'pointer',
    transition: 'var(--transition-smooth)',
  },
  sidebarActive: {
    background: 'rgba(99, 102, 241, 0.1)',
    color: 'var(--color-primary)',
  },
  shortcutGuide: {
    padding: '12px',
    borderRadius: '8px',
    background: 'rgba(255,255,255,0.02)',
    border: '1px solid var(--border-subtle)',
  },
  kbd: {
    fontFamily: 'var(--font-mono)',
    fontSize: '0.75rem',
    background: 'rgba(0,0,0,0.5)',
    padding: '4px 8px',
    borderRadius: '4px',
    color: 'white',
    border: '1px solid rgba(255,255,255,0.1)',
  },
  mainContent: {
    flexGrow: 1,
    display: 'flex',
    flexDirection: 'column',
    padding: '32px',
    overflow: 'hidden',
  },
  header: {
    marginBottom: '24px',
  },
  scrollArea: {
    flexGrow: 1,
    overflowY: 'auto',
    display: 'flex',
    flexDirection: 'column',
    gap: '24px',
    paddingRight: '6px',
  },
  sectionCard: {
    background: 'rgba(18, 18, 24, 0.5)',
    border: '1px solid var(--border-subtle)',
    borderRadius: '12px',
    padding: '20px',
  },
  sectionTitle: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    marginBottom: '16px',
  },
  inputGroup: {
    display: 'flex',
    flexDirection: 'column',
  },
  label: {
    fontSize: '0.85rem',
    color: 'var(--text-muted)',
    marginBottom: '6px',
  },
  passwordContainer: {
    display: 'flex',
    position: 'relative',
    width: '100%',
  },
  inputField: {
    flexGrow: 1,
    paddingRight: '40px',
  },
  iconBtn: {
    position: 'absolute',
    right: '12px',
    top: '50%',
    transform: 'translateY(-50%)',
    color: 'var(--text-muted)',
  },
  permissionList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '14px',
  },
  permissionRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingBottom: '12px',
    borderBottom: '1px solid rgba(255, 255, 255, 0.04)',
  },
  permissionLabel: {
    fontWeight: '600',
    fontSize: '0.9rem',
  },
  permissionDesc: {
    fontSize: '0.8rem',
    color: 'var(--text-muted)',
    marginTop: '2px',
  },
  badge: {
    fontSize: '0.75rem',
    padding: '4px 8px',
    borderRadius: '4px',
    fontWeight: '600',
  },
  badgeActive: {
    background: 'rgba(16, 185, 129, 0.1)',
    color: 'var(--color-accent)',
  },
  switch: {
    position: 'relative',
    display: 'inline-block',
    width: '40px',
    height: '22px',
  },
  slider: {
    position: 'absolute',
    cursor: 'pointer',
    top: 0, left: 0, right: 0, bottom: 0,
    backgroundColor: '#374151',
    transition: '.4s',
    borderRadius: '34px',
  },
  statusText: {
    marginTop: '8px',
    fontSize: '0.85rem',
    color: 'var(--color-primary)',
  },
  recordingAlert: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    marginTop: '6px',
  },
  recordingDot: {
    width: '8px',
    height: '8px',
    borderRadius: '50%',
    backgroundColor: 'var(--color-secondary)',
    animation: 'pulse-glow 1.5s infinite',
  },
  memoryControls: {
    display: 'flex',
    gap: '10px',
    marginBottom: '16px',
  },
  deleteBtn: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    fontSize: '0.75rem',
    color: 'var(--color-error)',
    padding: '6px 12px',
    borderRadius: '6px',
    border: '1px solid rgba(239, 68, 68, 0.2)',
    background: 'rgba(239, 68, 68, 0.05)',
  },
  clearBtn: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    fontSize: '0.75rem',
    color: 'var(--color-error)',
    padding: '6px 12px',
    borderRadius: '6px',
    background: 'rgba(239, 68, 68, 0.1)',
  },
  refreshBtn: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    fontSize: '0.75rem',
    color: 'var(--text-muted)',
    padding: '6px 12px',
    borderRadius: '6px',
    border: '1px solid var(--border-subtle)',
    marginLeft: 'auto',
  },
  logList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '10px',
    maxHeight: '300px',
    overflowY: 'auto',
  },
  logItem: {
    background: 'rgba(0, 0, 0, 0.2)',
    border: '1px solid var(--border-subtle)',
    borderRadius: '8px',
    padding: '12px',
  },
  logMeta: {
    display: 'flex',
    justifyContent: 'space-between',
    fontSize: '0.75rem',
    marginBottom: '4px',
  },
  logApp: {
    color: 'var(--color-primary)',
    fontWeight: '600',
  },
  logTime: {
    color: 'var(--text-muted)',
  },
  logSnippet: {
    fontSize: '0.85rem',
    fontWeight: '500',
    color: 'var(--text-main)',
    marginBottom: '4px',
  },
  logAnswer: {
    fontSize: '0.8rem',
    color: 'var(--text-muted)',
  },
  emptyLogs: {
    textAlign: 'center',
    color: 'var(--text-muted)',
    padding: '24px',
    fontSize: '0.85rem',
  },
  searchResultsContainer: {
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
  },
  searchSubheader: {
    fontSize: '0.8rem',
    textTransform: 'uppercase',
    letterSpacing: '0.05em',
    color: 'var(--text-muted)',
    marginTop: '10px',
    borderBottom: '1px solid rgba(255, 255, 255, 0.04)',
    paddingBottom: '4px',
  },
  fileList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
    maxHeight: '300px',
    overflowY: 'auto',
  },
  fileItem: {
    background: 'rgba(255, 255, 255, 0.02)',
    border: '1px solid var(--border-subtle)',
    borderRadius: '8px',
    padding: '10px 12px',
  },
  fileHeader: {
    display: 'flex',
    alignItems: 'center',
    marginBottom: '4px',
  },
  fileName: {
    fontWeight: '600',
    fontSize: '0.85rem',
    color: 'var(--text-main)',
  },
  filePath: {
    fontSize: '0.75rem',
    color: 'var(--text-muted)',
    wordBreak: 'break-all',
  },
  fileSnippet: {
    marginTop: '6px',
    fontSize: '0.75rem',
    color: 'var(--text-muted)',
    background: 'rgba(0,0,0,0.2)',
    border: '1px solid var(--border-subtle)',
    borderRadius: '6px',
    padding: '6px 8px',
    overflowX: 'auto',
    fontFamily: 'var(--font-mono)',
  }
};

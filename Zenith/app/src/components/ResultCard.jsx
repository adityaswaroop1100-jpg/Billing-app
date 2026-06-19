import React, { useState, useEffect, useRef } from 'react';
import { X, Send, Sparkles, BookOpen, FileText, Globe, Search, RefreshCw, CornerDownRight } from 'lucide-react';

export default function ResultCard({ initialData }) {
  const [activeTab, setActiveTab] = useState('explain');
  const [explainLevel, setExplainLevel] = useState('peer'); // 'new' | 'peer' | 'expert'
  const [isLoading, setIsLoading] = useState(false);
  const [answer, setAnswer] = useState('');
  const [chatInput, setChatInput] = useState('');
  const [chatHistory, setChatHistory] = useState([]); // Array of { role, content }
  const [persona, setPersona] = useState('General Assistant');
  const [useScreenContext, setUseScreenContext] = useState(false);

  const chatEndRef = useRef(null);

  // Load API key from shared localStorage
  const apiKey = localStorage.getItem('anthropic_api_key') || '';

  // Trigger query on mount, tab change, explainLevel change, or useScreenContext toggle
  useEffect(() => {
    if (initialData) {
      handleQuery(activeTab, explainLevel);
    }
  }, [activeTab, explainLevel, useScreenContext]);

  // Scroll to bottom of chat thread on new messages
  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chatHistory, isLoading]);

  const getQueryForTab = (tab) => {
    switch (tab) {
      case 'summarize':
        return "Summarize this selection concisely in a few bullet points, highlighting key takeaways.";
      case 'translate':
        return "Translate the text in this selection to English. If it's already in English, translate it to Spanish.";
      case 'search':
        return "Analyze this selection and provide related context, external resources, or search terms to find more information.";
      case 'explain':
      default:
        return "Explain this selection in detail. Break down any complex elements.";
    }
  };

  const handleQuery = async (tab, level, history = []) => {
    if (!initialData) return;
    
    setIsLoading(true);
    if (history.length === 0) {
      setAnswer(''); // Clear main answer for a fresh tab/level query
    }

    const queryText = history.length > 0 
      ? history[history.length - 1].content 
      : getQueryForTab(tab);

    try {
      const response = await fetch('http://localhost:5001/api/query', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          image_base64: initialData.image_base64,
          ocr_text: initialData.ocr_text,
          user_query: queryText,
          active_app: initialData.active_app,
          window_title: initialData.window_title,
          explain_level: level,
          chat_history: history.slice(0, -1), // Send previous messages
          api_key: apiKey,
          save_to_memory: history.length === 0, // Only save initial queries to memory
          use_screen_context: useScreenContext
        })
      });

      if (response.ok) {
        const data = await response.json();
        setPersona(data.persona);
        
        if (history.length > 0) {
          // If follow-up chat, append AI reply to history
          setChatHistory(prev => [...prev, { role: 'assistant', content: data.answer }]);
        } else {
          // Main tab answer
          setAnswer(data.answer);
        }
      } else {
        const err = await response.json();
        const msg = `Error: ${err.detail || 'Failed to get answer'}`;
        if (history.length > 0) {
          setChatHistory(prev => [...prev, { role: 'assistant', content: msg }]);
        } else {
          setAnswer(msg);
        }
      }
    } catch (e) {
      const msg = "Failed to connect to Zenith backend service.";
      if (history.length > 0) {
        setChatHistory(prev => [...prev, { role: 'assistant', content: msg }]);
      } else {
        setAnswer(msg);
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleSendChat = (e) => {
    e.preventDefault();
    if (!chatInput.trim() || isLoading) return;

    const newHistory = [...chatHistory, { role: 'user', content: chatInput }];
    setChatHistory(newHistory);
    setChatInput('');
    
    // Trigger follow-up query
    handleQuery(activeTab, explainLevel, newHistory);
  };

  const handleClose = () => {
    window.zenithAPI.closeCard();
  };

  const getPersonaColor = (pers) => {
    if (pers.includes('Coding')) return 'var(--color-primary)';
    if (pers.includes('Financial')) return 'var(--color-accent)';
    if (pers.includes('Design')) return 'var(--color-secondary)';
    return '#3B82F6';
  };

  return (
    <div className="glass-panel animate-slide" style={styles.cardContainer}>
      {/* 1. Header with Persona and Thumbnail */}
      <div style={styles.header}>
        <div style={styles.headerLeft}>
          {initialData?.image_base64 && (
            <img 
              src={`data:image/png;base64,${initialData.image_base64}`} 
              alt="Crop" 
              style={styles.thumbnail}
            />
          )}
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: '600' }}>
              CONTEXT: {initialData?.active_app || 'System'}
            </div>
            <span style={{ 
              ...styles.personaBadge, 
              backgroundColor: `${getPersonaColor(persona)}15`, 
              color: getPersonaColor(persona),
              borderColor: `${getPersonaColor(persona)}30`
            }}>
              {persona}
            </span>
          </div>
        </div>
        <button onClick={handleClose} style={styles.closeBtn}>
          <X size={16} />
        </button>
      </div>

      {/* 2. Tabs */}
      <div style={styles.tabsContainer}>
        <button 
          onClick={() => { setActiveTab('explain'); setChatHistory([]); }} 
          style={{ ...styles.tabItem, ...(activeTab === 'explain' ? styles.tabItemActive : {}) }}
        >
          <BookOpen size={14} />
          <span>Explain</span>
        </button>
        <button 
          onClick={() => { setActiveTab('summarize'); setChatHistory([]); }} 
          style={{ ...styles.tabItem, ...(activeTab === 'summarize' ? styles.tabItemActive : {}) }}
        >
          <FileText size={14} />
          <span>Summarize</span>
        </button>
        <button 
          onClick={() => { setActiveTab('translate'); setChatHistory([]); }} 
          style={{ ...styles.tabItem, ...(activeTab === 'translate' ? styles.tabItemActive : {}) }}
        >
          <Globe size={14} />
          <span>Translate</span>
        </button>
        <button 
          onClick={() => { setActiveTab('search'); setChatHistory([]); }} 
          style={{ ...styles.tabItem, ...(activeTab === 'search' ? styles.tabItemActive : {}) }}
        >
          <Search size={14} />
          <span>Search</span>
        </button>
      </div>

      {/* 3. Explain Level Slider */}
      <div style={styles.sliderContainer}>
        <span style={styles.sliderLabel}>Depth:</span>
        <div style={styles.sliderOptions}>
          {['new', 'peer', 'expert'].map((lvl) => (
            <button
              key={lvl}
              onClick={() => { setExplainLevel(lvl); setChatHistory([]); }}
              style={{
                ...styles.sliderOptBtn,
                ...(explainLevel === lvl ? styles.sliderOptBtnActive : {})
              }}
            >
              {lvl.toUpperCase()}
            </button>
          ))}
        </div>
      </div>

      {/* 3b. Use Screen Context Toggle */}
      <div style={styles.contextContainer}>
        <span style={styles.contextLabel}>Use what's on my screen</span>
        <div 
          onClick={() => {
            setUseScreenContext(!useScreenContext);
            setChatHistory([]);
          }}
          style={{
            width: '34px',
            height: '20px',
            borderRadius: '10px',
            backgroundColor: useScreenContext ? 'var(--color-primary)' : '#374151',
            position: 'relative',
            cursor: 'pointer',
            transition: 'background-color 0.2s',
          }}
        >
          <div style={{
            width: '16px',
            height: '16px',
            borderRadius: '50%',
            backgroundColor: 'white',
            position: 'absolute',
            top: '2px',
            left: useScreenContext ? '16px' : '2px',
            transition: 'left 0.2s',
          }} />
        </div>
      </div>

      {/* 4. Response Content Area */}
      <div style={styles.contentBody}>
        {chatHistory.length === 0 ? (
          /* Main Tab Response */
          isLoading && !answer ? (
            <div style={styles.loaderContainer}>
              <RefreshCw size={24} className="spin-animation" color="var(--color-primary)" />
              <div style={{ marginTop: '8px', fontSize: '0.85rem', color: 'var(--text-muted)' }}>Claude is thinking...</div>
            </div>
          ) : (
            <div style={styles.answerText}>
              {answer.split('\n').map((para, idx) => {
                if (para.startsWith('```')) return null; // Simple formatting
                return <p key={idx} style={{ marginBottom: '10px', lineHeight: '1.45' }}>{para}</p>;
              })}
            </div>
          )
        ) : (
          /* Chat History Thread */
          <div style={styles.chatThread}>
            {chatHistory.map((chat, idx) => (
              <div key={idx} style={{
                ...styles.chatBubble,
                alignSelf: chat.role === 'user' ? 'flex-end' : 'flex-start',
                background: chat.role === 'user' ? 'rgba(99, 102, 241, 0.15)' : 'rgba(255, 255, 255, 0.04)',
                border: chat.role === 'user' ? '1px solid rgba(99, 102, 241, 0.25)' : '1px solid var(--border-subtle)',
              }}>
                <div style={styles.chatRole}>{chat.role === 'user' ? 'You' : 'Zenith'}</div>
                <div style={styles.chatContent}>{chat.content}</div>
              </div>
            ))}
            {isLoading && (
              <div style={{ ...styles.chatBubble, alignSelf: 'flex-start', background: 'rgba(255, 255, 255, 0.02)' }}>
                <RefreshCw size={14} className="spin-animation" color="var(--color-primary)" />
              </div>
            )}
            <div ref={chatEndRef} />
          </div>
        )}
      </div>

      {/* 5. Follow-up Chat Input */}
      <form onSubmit={handleSendChat} style={styles.chatForm}>
        <input 
          type="text" 
          value={chatInput} 
          onChange={(e) => setChatInput(e.target.value)} 
          placeholder="Ask a follow-up..." 
          style={styles.chatInput}
          disabled={isLoading}
        />
        <button type="submit" style={styles.sendBtn} disabled={isLoading || !chatInput.trim()}>
          <Send size={14} />
        </button>
      </form>
    </div>
  );
}

const styles = {
  cardContainer: {
    width: '100%',
    height: '100%',
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden',
    border: '1px solid rgba(255, 255, 255, 0.1)',
  },
  header: {
    padding: '12px 14px',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderBottom: '1px solid var(--border-subtle)',
    background: 'rgba(0, 0, 0, 0.15)',
  },
  headerLeft: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
  },
  thumbnail: {
    width: '36px',
    height: '36px',
    objectFit: 'cover',
    borderRadius: '6px',
    border: '1px solid var(--border-subtle)',
  },
  personaBadge: {
    fontSize: '0.75rem',
    fontWeight: '700',
    padding: '2px 8px',
    borderRadius: '12px',
    border: '1px solid transparent',
    display: 'inline-block',
    marginTop: '2px',
  },
  closeBtn: {
    width: '24px',
    height: '24px',
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: 'var(--text-muted)',
    background: 'rgba(255, 255, 255, 0.05)',
  },
  tabsContainer: {
    display: 'flex',
    justifyContent: 'space-between',
    padding: '6px 10px',
    borderBottom: '1px solid var(--border-subtle)',
    background: 'rgba(0, 0, 0, 0.1)',
  },
  tabItem: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: '2px',
    fontSize: '0.65rem',
    color: 'var(--text-muted)',
    padding: '6px 8px',
    borderRadius: '6px',
    flexGrow: 1,
    transition: 'var(--transition-smooth)',
  },
  tabItemActive: {
    color: 'var(--color-primary)',
    background: 'rgba(99, 102, 241, 0.08)',
  },
  sliderContainer: {
    padding: '8px 14px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    background: 'rgba(255, 255, 255, 0.02)',
    borderBottom: '1px solid var(--border-subtle)',
  },
  sliderLabel: {
    fontSize: '0.75rem',
    color: 'var(--text-muted)',
    fontWeight: '600',
  },
  contextContainer: {
    padding: '8px 14px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    background: 'rgba(255, 255, 255, 0.01)',
    borderBottom: '1px solid var(--border-subtle)',
  },
  contextLabel: {
    fontSize: '0.75rem',
    color: 'var(--text-muted)',
    fontWeight: '600',
  },
  sliderOptions: {
    display: 'flex',
    background: 'rgba(0, 0, 0, 0.3)',
    borderRadius: '6px',
    padding: '2px',
  },
  sliderOptBtn: {
    fontSize: '0.65rem',
    fontWeight: '700',
    padding: '4px 8px',
    borderRadius: '4px',
    color: 'var(--text-muted)',
  },
  sliderOptBtnActive: {
    background: 'var(--color-primary)',
    color: 'white',
  },
  contentBody: {
    flexGrow: 1,
    padding: '14px',
    overflowY: 'auto',
    display: 'flex',
    flexDirection: 'column',
    background: 'rgba(0, 0, 0, 0.05)',
  },
  loaderContainer: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    flexGrow: 1,
  },
  answerText: {
    fontSize: '0.85rem',
    color: '#E5E7EB',
  },
  chatThread: {
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
  },
  chatBubble: {
    maxWidth: '85%',
    padding: '10px 12px',
    borderRadius: '10px',
  },
  chatRole: {
    fontSize: '0.65rem',
    fontWeight: '700',
    color: 'var(--text-muted)',
    marginBottom: '2px',
  },
  chatContent: {
    fontSize: '0.85rem',
    color: 'var(--text-main)',
  },
  chatForm: {
    padding: '10px 12px',
    display: 'flex',
    gap: '8px',
    background: 'rgba(0, 0, 0, 0.25)',
    borderTop: '1px solid var(--border-subtle)',
  },
  chatInput: {
    flexGrow: 1,
    background: 'rgba(0, 0, 0, 0.3)',
    padding: '8px 12px',
    fontSize: '0.85rem',
    borderRadius: '8px',
  },
  sendBtn: {
    width: '32px',
    height: '32px',
    borderRadius: '8px',
    background: 'var(--color-primary)',
    color: 'white',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  }
};

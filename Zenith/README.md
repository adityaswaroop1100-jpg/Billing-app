# Zenith — AI Operating System Assistant

Zenith is a desktop AI overlay companion designed for instant context-aware reasoning on top of any active application. By pressing a global hotkey, you can marquee-select any region of your screen (charts, code blocks, documents, interfaces) and instantly get targeted AI explanations, summaries, translations, or search terms, without breaking your workflow.

---

## 🚀 Product Pillars

1. **Instant Selection Loop:** Hotkey (`Cmd+Alt+Space` on macOS, `Ctrl+Space` on Windows) triggers a full-screen translucent overlay, crop box, and immediate inline answers.
2. **Context Persona-Aware:** Identifies the active foreground application (e.g., VS Code, Excel, Photoshop) and formats system prompts to frame Claude's responses with professional expertise.
3. **General-Purpose Brain:** Powered by the frontier-grade **Claude 3.5 Sonnet** model, capable of detailed step-by-step reasoning on any topic.
4. **Local-First & Consensual:** All captures, session histories, and local file index records live in a secure, local SQLite database on your machine. Screen recording and history timelines are strictly opt-in and off by default.
5. **Universal Workspace Search:** Search both your semantic visual session memory (using vector-based cosine similarity) and local files (indexed by file content) in one interface.

---

## 🛠️ Tech Stack & Architecture

- **Shell / UI Window:** Electron + React (Vite) + Vanilla CSS (Custom Glassmorphism and Animations)
- **OCR Engine:** Tesseract.js (Offline local character recognition)
- **Local Database & Vector Search:** SQLite + numpy (local float32 unit-normalized cosine similarity embeddings)
- **Active App Detector:** Native platform commands (`osascript` on macOS, `PowerShell` on Windows) providing zero-dependency frontmost window tracking.
- **LLM Reasoning Engine:** Anthropic Messages API client (`claude-3-5-sonnet-20240620`)
- **Concurrently Runner:** Runs both the Electron client and local FastAPI background daemon simultaneously.

---

## 📦 Project Structure

```
/Zenith
├── app/                 # Electron + React Client App
│   ├── main.js          # Electron Main Process (Hotkeys, Window managers)
│   ├── preload.js       # Secure IPC Bridge
│   ├── src/             # React Renderer App
│   │   ├── components/  # Overlay Crop, Floating Result Card, Settings
│   │   └── index.css    # Premium custom styling design tokens
├── core/                # Python Core Backend Daemon (FastAPI)
│   ├── main.py          # API route controllers
│   └── requirements.txt # Version-locked pip dependencies
├── agent/               # LLM Orchestrator
│   └── claude_client.py # Claude API wrapper & application persona mapping
├── index/               # SQLite Storage and Local Machine File Indexer
│   ├── db.py            # SQLite schema and numpy cosine similarity
│   └── search.py        # File walker, first-1KB content indexer, search aggregator
└── zenith.db            # Local SQLite database (Generated on first run)
```

---

## 🚦 Getting Started

### 1. Prerequisites
- **Node.js** (v18.0.0 or higher)
- **Python 3.9** or higher

### 2. Configure Environment
1. Copy the `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Open `.env` and fill in your Anthropic API Key:
   ```env
   ANTHROPIC_API_KEY=sk-ant-your-actual-key-here
   ```

### 3. Installation
Run the root setup command to install Node dependencies and construct the Python virtual environment:
```bash
npm run setup
```

### 4. Running the Application
Launch both the Electron UI shell and the Python backend daemon concurrently:
```bash
npm start
```

---

## 🛡️ Privacy & Permission Center

Access the **Permission Center** directly inside the primary Settings dashboard:
- **Screen Capture / OCR Permission:** Shows capture status.
- **Active App Detection:** Shows active state.
- **Timeline / Continuous Screen Memory:** Toggle **off by default** to protect user privacy. Enable this to keep an active log of screen text, displaying a visual pulse recording indicator.
- **Memory Controls:** Clear logs, or "Delete Last Hour" with a single click.

---

## 📈 Roadmap & Post-MVP Scope

- **Floating Orb UI (Phase 4):** Swap the static trigger flow with a floating dashboard orb that suggests context-aware tasks based on passive changes.
- **Local Speech-to-Text (Phase 4):** Trigger marquee workflows using local wake words and voice triggers.
- **Agent Marketplace Plugin SDK:** Define manifest specifications allowing third-party automation agents to integrate into the Zenith workspace safely.

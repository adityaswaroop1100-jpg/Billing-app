import os
import json
import anthropic
from dotenv import load_dotenv

# Load env variables from the root .env or core/.env
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "core", ".env"))
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

# Personas mappings based on process names
PERSONAS = {
    "default": {
        "title": "General Assistant",
        "system": (
            "You are Zenith, a helpful, highly capable general-purpose AI desktop assistant. "
            "You answer questions concisely, with precise reasoning, and adapt to any topic. "
            "Your tone is professional and friendly."
        )
    },
    "coding": {
        "title": "Coding Assistant",
        "system": (
            "You are Zenith, a specialized coding and developer assistant. "
            "You provide clean, optimized code snippets in your explanations, structure responses clearly "
            "with markdown code blocks, and help debug errors step-by-step. "
            "Focus on technical accuracy, efficiency, and clear variable naming."
        )
    },
    "financial": {
        "title": "Financial Analyst",
        "system": (
            "You are Zenith, a senior financial analyst and spreadsheet specialist. "
            "When answering questions, write Excel/Google Sheets formulas in UPPERCASE (e.g., VLOOKUP, SUMIFS), "
            "describe data trends, analyze numbers critically, and explain financial principles clearly."
        )
    },
    "design": {
        "title": "Design Assistant",
        "system": (
            "You are Zenith, a professional UI/UX and visual design critique companion. "
            "When looking at screenshots/interfaces, analyze composition, typography, color harmony, "
            "alignment, and user experience. Offer actionable feedback to improve visual polish."
        )
    }
}

# Simple active app process name mapping
def detect_persona_type(app_name):
    if not app_name:
        return "default"
    
    app_lower = app_name.lower()
    
    # Coding apps
    if any(k in app_lower for k in ["code", "vscode", "cursor", "sublime", "atom", "terminal", "iterm", "cmd", "powershell", "xcode", "intellij", "pycharm", "eclipse"]):
        return "coding"
    
    # Financial apps
    if any(k in app_lower for k in ["excel", "sheets", "numbers", "finance", "ledger"]):
        return "financial"
        
    # Design apps
    if any(k in app_lower for k in ["photoshop", "figma", "illustrator", "sketch", "gimp", "canva", "indesign", "paint"]):
        return "design"
        
    return "default"

def get_system_prompt(app_name, explain_level):
    persona_type = detect_persona_type(app_name)
    persona = PERSONAS.get(persona_type, PERSONAS["default"])
    
    system_prompt = persona["system"]
    
    # Inject explain level directions
    if explain_level == "new":
        system_prompt += (
            "\n\nCRITICAL: The user is new to this topic. Explain concepts simply, using everyday analogies "
            "where possible, and strictly avoid complex technical jargon unless you define it first."
        )
    elif explain_level == "expert":
        system_prompt += (
            "\n\nCRITICAL: The user is an expert. Provide a deep, highly detailed explanation, analyzing "
            "underlying mechanics, advanced mathematical/logic concepts, edge cases, and architectural trade-offs."
        )
    else: # peer
        system_prompt += (
            "\n\nCRITICAL: Explain like a professional peer. Use standard industry terminology "
            "without over-explaining basic terms, and jump straight to the core solution."
        )
        
    return system_prompt

def query_claude(
    api_key=None,
    image_base64=None,
    image_media_type=None,
    ocr_text=None,
    user_query=None,
    active_app=None,
    window_title=None,
    explain_level="peer",
    chat_history=None,
    screen_context=None
):
    """
    Sends query to Anthropic Messages API.
    chat_history: List of dicts [{"role": "user"|"assistant", "content": "..."}]
    """
    # Resolve API Key from parameter, database setting, or environment variables
    from index.db import get_setting
    resolved_api_key = api_key or get_setting("anthropic_api_key") or os.environ.get("ANTHROPIC_API_KEY")
    if not resolved_api_key:
        return "Error: ANTHROPIC_API_KEY is not set. Please set it in your environment or via settings."
        
    client = anthropic.Anthropic(api_key=resolved_api_key)
    system_prompt = get_system_prompt(active_app, explain_level)
    
    # Model to use: Claude 3.5 Sonnet is frontier-grade
    model = "claude-3-5-sonnet-20240620"
    
    messages = []
    
    # If there is chat history, we reconstruct the chat context
    if chat_history and len(chat_history) > 0:
        # Append historical messages
        # Note: If the first historical message is a user message, we must format it properly
        for idx, msg in enumerate(chat_history):
            role = msg["role"]
            content = msg["content"]
            messages.append({"role": role, "content": content})
            
        # Add the new user query as the last message
        prompt_text = ""
        if user_query:
            prompt_text = user_query
        else:
            prompt_text = "Please continue analyzing the selection."
            
        messages.append({"role": "user", "content": prompt_text})
    else:
        # Initial query: package the crop and screenshot metadata
        content_blocks = []
        
        # 1. Add Image if available
        if image_base64 and image_media_type:
            content_blocks.append({
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": image_media_type,
                    "data": image_base64
                }
            })
            
        # 2. Add prompt context and query
        prompt_text = ""
        if active_app:
            prompt_text += f"[Active Application Context: Process: {active_app}, Window Title: '{window_title or 'Unknown'}']\n"
        if ocr_text:
            prompt_text += f"[Detected text from screen region]:\n{ocr_text}\n\n"
        if screen_context:
            prompt_text += f"[Recent Screen Context (Last 5 mins of OCR activity)]:\n{screen_context}\n\n"
            
        if user_query:
            prompt_text += f"User query: {user_query}"
        else:
            prompt_text += "Explain the selected screen region."
            
        content_blocks.append({
            "type": "text",
            "text": prompt_text
        })
        
        messages.append({
            "role": "user",
            "content": content_blocks
        })
        
    try:
        response = client.messages.create(
            model=model,
            max_tokens=1500,
            system=system_prompt,
            messages=messages
        )
        return response.content[0].text
    except Exception as e:
        print(f"Anthropic API Error: {e}")
        return f"Error calling Claude API: {str(e)}"

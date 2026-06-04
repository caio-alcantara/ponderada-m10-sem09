import json
import logging

import google.generativeai as genai
from app.config import settings

logger = logging.getLogger(__name__)

_configured = False

PROMPT = (
    "You are a dermatology assistant. Analyze this skin photo and return ONLY "
    "a valid JSON object (no markdown, no extra text) with exactly these keys:\n"
    "{\n"
    '  "score": <float 0.0-10.0, overall skin health where 10 is perfect>,\n'
    '  "redness": "<low|moderate|high>",\n'
    '  "acne": "<none|mild|moderate|severe>",\n'
    '  "dryness": "<low|moderate|high>",\n'
    '  "oiliness": "<low|moderate|high>",\n'
    '  "observations": "<2 sentences max, in Portuguese>",\n'
    '  "recommendations": "<2 sentences max, in Portuguese>"\n'
    "}"
)


def _ensure_configured():
    global _configured
    if not _configured:
        genai.configure(api_key=settings.gemini_api_key)
        _configured = True


def analyze_skin(image_bytes: bytes, mime_type: str) -> dict | None:
    if not settings.gemini_api_key:
        return None

    _ensure_configured()

    try:
        model = genai.GenerativeModel(settings.gemini_model)
        response = model.generate_content([
            PROMPT,
            {"mime_type": mime_type, "data": image_bytes},
        ])

        text = response.text.strip()
        if text.startswith("```"):
            text = text.split("\n", 1)[1].rsplit("```", 1)[0].strip()

        return json.loads(text)
    except Exception as exc:
        logger.warning("Gemini analysis failed: %s", exc)
        return None

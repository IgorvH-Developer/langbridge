# backend/app/routers/translate.py
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from googletrans import Translator, LANGUAGES
from ..logger import logger

router = APIRouter(prefix="/api/translate", tags=["translate"])

# Используем одного и того же переводчика
translator = Translator()

class TranslationRequest(BaseModel):
    text: str
    target_lang: str # Например, 'en', 'ru'

class TranslationResponse(BaseModel):
    translated_text: str
    source_lang: str

@router.post("/", response_model=TranslationResponse)
async def translate_text(request: TranslationRequest):
    """
    Переводит предоставленный текст на указанный язык.
    """
    if not request.text.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Text to translate cannot be empty.")

    if request.target_lang not in LANGUAGES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid target language code: {request.target_lang}")

    try:
        logger.info(f"Translating text to '{request.target_lang}': '{request.text[:30]}...'")
        translation = translator.translate(request.text, dest=request.target_lang)

        response = TranslationResponse(
            translated_text=translation.text,
            source_lang=translation.src
        )
        logger.info(f"Translation successful. Source: {response.source_lang}, Result: '{response.translated_text[:30]}...'")

        return response
    except Exception as e:
        logger.error(f"Error during translation: {e}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Translation failed: {e}")


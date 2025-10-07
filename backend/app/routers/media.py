import uuid
import os
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status
from pydub import AudioSegment
from sqlalchemy.orm import Session
import json
import stable_whisper # ИМПОРТИРУЕМ новую библиотеку

from .. import database, models, schemas
from ..websocket_manager import ConnectionManager
from ..logger import logger

from .ws import manager

router = APIRouter(prefix="/api/media", tags=["Media"])

UPLOAD_DIR = "/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload/video")
async def upload_video(
        chat_id: str,
        sender_id: str,
        file: UploadFile = File(...),
        db: Session = Depends(database.get_db)
):
    logger.info(f"uploading video: {chat_id}, {sender_id}, {file.filename}")
    try:
        chat_uuid = uuid.UUID(chat_id)
        sender_uuid = uuid.UUID(sender_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid UUID format")

    chat_db = db.query(models.Chat).filter(models.Chat.id == chat_uuid).first()
    user_db = db.query(models.User).filter(models.User.id == sender_uuid).first()
    if not chat_db or not user_db:
        raise HTTPException(status_code=404, detail="Chat or User not found")

    file_extension = file.filename.split('.')[-1] if '.' in file.filename else 'mp4'
    video_filename = f"{uuid.uuid4()}.{file_extension}"
    video_path = os.path.join(UPLOAD_DIR, video_filename)

    with open(video_path, "wb") as buffer:
        buffer.write(await file.read())
    logger.info(f"Video saved to {video_path}")

    # Важно: URL для клиента должен быть полным. Nginx настроен правильно,
    # он будет раздавать файлы из /uploads/.
    video_url = f"/uploads/{video_filename}"

    # Это словарь, который мы сохраним в БД как JSON-строку
    message_content_dict = {
        "video_url": video_url,
        "transcription": None
    }

    db_message = models.Message(
        chat_id=chat_uuid,
        sender_id=sender_uuid,
        content=json.dumps(message_content_dict), # Сохраняем как строку
        type="video"
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)

    # --- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
    # Для WebSocket мы отправляем словарь, где `content` - это тоже словарь (не строка!)
    message_to_broadcast = {
        "id": str(db_message.id),
        "chat_id": str(db_message.chat_id),
        "sender_id": str(db_message.sender_id),
        "content": message_content_dict,  # <<< ИСПОЛЬЗУЕМ СЛОВАРЬ, А НЕ СТРОКУ
        "type": db_message.type,
        "timestamp": db_message.timestamp.isoformat()
    }
    await manager.broadcast(chat_id, message_to_broadcast)

    return {"filename": video_filename, "url": video_url, "message_id": str(db_message.id)}

@router.post("/transcribe/{message_id_str}")
async def transcribe_video_message(
        message_id_str: str,
        db: Session = Depends(database.get_db)
):
    logger.info(f"Transcribing video: {message_id_str}")
    try:
        message_uuid = uuid.UUID(message_id_str)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid message_id format")

    db_message = db.query(models.Message).filter(models.Message.id == message_uuid).first()
    if not db_message or db_message.type != "video":
        raise HTTPException(status_code=404, detail="Video message not found")

    content_data = json.loads(db_message.content)
    if content_data.get("transcription"):
        logger.info(f"Returning existing transcription for message {message_id_str}")
        return content_data["transcription"] # Возвращаем уже сохраненный объект

    video_url = content_data.get("video_url")
    if not video_url:
        raise HTTPException(status_code=404, detail="Video URL not found in message content")

    logger.info(f"looking for video with url: {video_url}")
    if not os.path.exists(video_url):
        raise HTTPException(status_code=404, detail="Video file not found on server")

    logger.info(f"Starting transcription for {video_url}")
    transcription_result = None
    try:
        # stable-ts может работать напрямую с видео/аудио файлами
        model = stable_whisper.load_model('base') # или 'tiny', 'small', 'medium'
        result = model.transcribe(video_url, language="ru") # Указываем язык

        # Преобразуем результат в нужную нам структуру
        words_data = []
        for segment in result.segments:
            for word in segment.words:
                words_data.append({
                    "word": word.word,
                    "start": word.start,
                    "end": word.end,
                    "id": str(uuid.uuid4()) # Уникальный ID для каждого слова, чтобы его можно было редактировать
                })

        transcription_result = {
            "full_text": result.text,
            "words": words_data
        }

        logger.info(f"Successfully transcribed. First few words: {words_data[:5]}")

        # Обновляем JSON в БД с новой структурой
        content_data["transcription"] = transcription_result
        db_message.content = json.dumps(content_data)
        db.commit()

    except Exception as e:
        logger.error(f"Could not transcribe video {video_url}: {e}", exc_info=True)
        # В случае ошибки вернем пустую структуру
        transcription_result = {
            "full_text": "[Не удалось распознать речь]",
            "words": []
        }

    return transcription_result


# НОВЫЙ ЭНДПОИНТ для обновления транскрипции
@router.put("/transcribe/{message_id_str}")
async def update_video_transcription(
        message_id_str: str,
        transcription_data: dict, # Pydantic схема была бы лучше, но для простоты dict
        db: Session = Depends(database.get_db)
):
    logger.info(f"Updating transcription for message: {message_id_str}")
    try:
        message_uuid = uuid.UUID(message_id_str)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid message_id format")

    db_message = db.query(models.Message).filter(models.Message.id == message_uuid).first()
    if not db_message or db_message.type != "video":
        raise HTTPException(status_code=404, detail="Video message not found")

    content_data = json.loads(db_message.content)
    # Просто заменяем объект транскрипции на новый, присланный с клиента
    content_data["transcription"] = transcription_data
    db_message.content = json.dumps(content_data)
    db.commit()
    logger.info(f"Successfully updated transcription for message {message_id_str}")

    # Здесь можно также отправить WebSocket уведомление всем участникам чата
    # о том, что транскрипция обновилась, чтобы у них тоже все поменялось.
    # (пропущено для краткости)

    return {"status": "success", "message_id": message_id_str}


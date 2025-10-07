import uuid
import os
import speech_recognition as sr
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status
from pydub import AudioSegment
from sqlalchemy.orm import Session
import json # Добавлен импорт

from .. import database, models, schemas
from ..websocket_manager import ConnectionManager
from ..logger import logger

from .ws import manager

router = APIRouter(prefix="/api/media", tags=["Media"])

UPLOAD_DIR = "/app/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload/video")
async def upload_video(
        chat_id: str,
        sender_id: str,
        file: UploadFile = File(...),
        db: Session = Depends(database.get_db)
):
    logger.info(f"uploading video: {chat_id}, {sender_id}, {file}, {db}")
    try:
        chat_uuid = uuid.UUID(chat_id)
        sender_uuid = uuid.UUID(sender_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid UUID format")

    chat_db = db.query(models.Chat).filter(models.Chat.id == chat_uuid).first()
    user_db = db.query(models.User).filter(models.User.id == sender_uuid).first()
    if not chat_db or not user_db:
        raise HTTPException(status_code=404, detail="Chat or User not found")

    file_extension = file.filename.split('.')[-1]
    video_filename = f"{uuid.uuid4()}.{file_extension}"
    video_path = os.path.join(UPLOAD_DIR, video_filename)

    with open(video_path, "wb") as buffer:
        buffer.write(await file.read())
    logger.info(f"Video saved to {video_path}")

    video_url = f"/uploads/{video_filename}"

    # Теперь в content только URL. Транскрипция будет null.
    message_content = {
        "video_url": video_url,
        "transcription": None
    }

    db_message = models.Message(
        chat_id=chat_uuid,
        sender_id=sender_uuid,
        content=json.dumps(message_content),
        type="video"
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)

    message_to_broadcast = {
        "id": str(db_message.id),
        "chat_id": str(db_message.chat_id),
        "sender_id": str(db_message.sender_id),
        "content": db_message.content,
        "type": db_message.type,
        "timestamp": db_message.timestamp.isoformat()
    }
    await manager.broadcast(chat_id, message_to_broadcast)

    # Ответ теперь не содержит транскрипцию
    return {"filename": video_filename, "url": video_url, "message_id": str(db_message.id)}

# получение транскрипции по требованию
@router.post("/transcribe/{message_id_str}")
async def transcribe_video_message(
        message_id_str: str,
        db: Session = Depends(database.get_db)
):
    logger.info(f"transcribing video: {message_id_str}, {db}")
    try:
        message_uuid = uuid.UUID(message_id_str)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid message_id format")

    db_message = db.query(models.Message).filter(models.Message.id == message_uuid).first()
    if not db_message or db_message.type != "video":
        raise HTTPException(status_code=404, detail="Video message not found")

    content_data = json.loads(db_message.content)
    # Если транскрипция уже есть, возвращаем ее, чтобы не делать работу дважды
    if content_data.get("transcription"):
        logger.info(f"Returning existing transcription for message {message_id_str}")
        return {"transcription": content_data["transcription"]}

    video_url = content_data.get("video_url")
    if not video_url:
        raise HTTPException(status_code=404, detail="Video URL not found in message content")

    # Путь к файлу на сервере (убираем первый слэш)
    video_path = os.path.join(UPLOAD_DIR, video_url.lstrip('/uploads/'))
    if not os.path.exists(video_path):
        raise HTTPException(status_code=404, detail="Video file not found on server")

    logger.info(f"Starting transcription for {video_path}")
    transcribed_text = ""
    try:
        audio = AudioSegment.from_file(video_path)
        # Временный аудиофайл
        audio_path = os.path.join(UPLOAD_DIR, f"{uuid.uuid4()}.wav")
        audio.export(audio_path, format="wav")

        recognizer = sr.Recognizer()
        with sr.AudioFile(audio_path) as source:
            audio_data = recognizer.record(source)
            # Укажите язык, который будет использоваться для распознавания
            transcribed_text = recognizer.recognize_google(audio_data, language="ru-RU")

        os.remove(audio_path) # Удаляем временный аудиофайл
        logger.info(f"Successfully transcribed text: {transcribed_text}")

        # Обновляем JSON в БД с новым текстом
        content_data["transcription"] = transcribed_text
        db_message.content = json.dumps(content_data)
        db.commit()

    except Exception as e:
        logger.error(f"Could not transcribe video {video_path}: {e}")
        transcribed_text = "[Не удалось распознать речь]"

    return {"transcription": transcribed_text}


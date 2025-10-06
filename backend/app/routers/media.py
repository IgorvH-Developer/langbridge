import uuid
import os
import speech_recognition as sr
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status
from pydub import AudioSegment
from sqlalchemy.orm import Session

from .. import database, models, schemas
from ..websocket_manager import ConnectionManager
from ..logger import logger

# Предполагаем, что у нас есть ws.py с инстансом manager
from .ws import manager

router = APIRouter(prefix="/api/media", tags=["Media"])

# Папка для сохранения загруженных файлов
UPLOAD_DIR = "/app/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload/video")
async def upload_video_and_transcribe(
        chat_id: str,
        sender_id: str,
        file: UploadFile = File(...),
        db: Session = Depends(database.get_db)
):
    # 1. Проверка существования чата и пользователя
    try:
        chat_uuid = uuid.UUID(chat_id)
        sender_uuid = uuid.UUID(sender_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid UUID format")

    chat_db = db.query(models.Chat).filter(models.Chat.id == chat_uuid).first()
    user_db = db.query(models.User).filter(models.User.id == sender_uuid).first()
    if not chat_db or not user_db:
        raise HTTPException(status_code=404, detail="Chat or User not found")

    # 2. Сохранение видеофайла
    file_extension = file.filename.split('.')[-1]
    video_filename = f"{uuid.uuid4()}.{file_extension}"
    video_path = os.path.join(UPLOAD_DIR, video_filename)

    with open(video_path, "wb") as buffer:
        buffer.write(await file.read())
    logger.info(f"Video saved to {video_path}")

    # 3. Извлечение аудио и распознавание текста
    transcribed_text = ""
    try:
        # Конвертируем видео в аудио
        audio = AudioSegment.from_file(video_path)
        audio_path = os.path.join(UPLOAD_DIR, f"{uuid.uuid4()}.wav")
        audio.export(audio_path, format="wav")

        # Распознаем речь из аудио
        recognizer = sr.Recognizer()
        with sr.AudioFile(audio_path) as source:
            audio_data = recognizer.record(source)
            # Используем Google Web Speech API (не требует ключа)
            # Указываем язык, например, 'ru-RU' или 'en-US'. Можно передавать с клиента.
            transcribed_text = recognizer.recognize_google(audio_data, language="ru-RU")
            logger.info(f"Transcribed text: {transcribed_text}")

        os.remove(audio_path) # Удаляем временный аудиофайл

    except Exception as e:
        logger.error(f"Could not process audio or transcribe text: {e}")
        transcribed_text = "[Не удалось распознать речь]"

    # 4. Создание URL для доступа к видео
    # Важно: /uploads/ должен раздаваться Nginx'ом
    video_url = f"/uploads/{video_filename}"

    # 5. Сохранение сообщения в БД
    # В content сохраняем JSON-строку с URL и текстом
    message_content = {
        "video_url": video_url,
        "transcription": transcribed_text
    }

    import json
    db_message = models.Message(
        chat_id=chat_uuid,
        sender_id=sender_uuid,
        content=json.dumps(message_content),
        type="video"
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)

    # 6. Отправка сообщения через WebSocket
    message_to_broadcast = {
        "id": str(db_message.id),
        "chat_id": str(db_message.chat_id),
        "sender_id": str(db_message.sender_id),
        "content": db_message.content, # Отправляем JSON-строку
        "type": db_message.type,
        "timestamp": db_message.timestamp.isoformat()
    }
    await manager.broadcast(chat_id, message_to_broadcast)

    return {"filename": video_filename, "url": video_url, "transcription": transcribed_text}

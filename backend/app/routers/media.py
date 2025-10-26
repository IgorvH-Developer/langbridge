import uuid
import os
from fastapi import APIRouter, UploadFile, File, Depends, Form, HTTPException, status
from uuid import UUID as PyUUID
from pydub import AudioSegment
from sqlalchemy.orm import Session
import json
import stable_whisper
import subprocess
from typing import List

from .users import get_current_user
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
        files: List[UploadFile] = File(...),
        rotations: str = Form(...), # <<< ПРИНИМАЕМ JSON-СТРОКУ С ПОВОРОТАМИ
        reply_to_message_id: str | None = None,
        db: Session = Depends(database.get_db)
):
    logger.info(f"uploading {len(files)} video segments for chat: {chat_id}")

    try:
        chat_uuid = uuid.UUID(chat_id)
        sender_uuid = uuid.UUID(sender_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid UUID format")

    chat_db = db.query(models.Chat).filter(models.Chat.id == chat_uuid).first()
    user_db = db.query(models.User).filter(models.User.id == sender_uuid).first()
    if not chat_db or not user_db:
        raise HTTPException(status_code=404, detail="Chat or User not found")

    reply_to_uuid_obj = None
    if reply_to_message_id:
        try:
            reply_to_uuid_obj = PyUUID(reply_to_message_id)
        except ValueError:
            logger.warning(f"Invalid reply_to_message_id format: {reply_to_message_id}")

    if not files:
        raise HTTPException(status_code=400, detail="No video files uploaded.")

    try:
        rotation_values = json.loads(rotations)
        if len(files) != len(rotation_values):
            raise HTTPException(status_code=400, detail="Mismatch between number of files and rotations.")

        processed_segment_paths = []
        temp_files_to_clean = [] # Список всех временных файлов для очистки

        processed_segment_paths = []
        temp_files_to_clean = [] # Список всех временных файлов для очистки

        for i, (file, rotation) in enumerate(zip(files, rotation_values)):
            # 1. Сохраняем оригинальный сегмент
            original_segment_path = os.path.join(UPLOAD_DIR, f"temp_orig_{uuid.uuid4()}_{i}.mp4")
            with open(original_segment_path, "wb") as buffer:
                buffer.write(await file.read())
            temp_files_to_clean.append(original_segment_path)

            # 2. ВСЕГДА ПОЛНОСТЬЮ ПЕРЕКОДИРУЕМ каждый сегмент.
            processed_segment_path = os.path.join(UPLOAD_DIR, f"temp_proc_{uuid.uuid4()}_{i}.mp4")

            # Формируем базовую команду FFmpeg для перекодирования
            ffmpeg_process_command = [
                "ffmpeg",
                "-i", original_segment_path,
                "-y", # Перезаписывать, если файл существует
            ]

            # сбросить метатег, чтобы он не попал в финальный файл.
            ffmpeg_process_command.extend([
                "-metadata:s:v:0", "rotate=0"
            ])

            ffmpeg_process_command.append(processed_segment_path)

            logger.info(f"Processing and re-encoding segment {i}: {' '.join(ffmpeg_process_command)}")
            subprocess.run(ffmpeg_process_command, check=True)

            processed_segment_paths.append(processed_segment_path)
            temp_files_to_clean.append(processed_segment_path)

        logger.info(f"Processed {len(processed_segment_paths)} segments.")

        # 3. Создаем файл для FFmpeg со списком ОБРАБОТАННЫХ сегментов
        concat_list_path = os.path.join(UPLOAD_DIR, f"concat_list_{uuid.uuid4()}.txt")

        logger.info(f"Processed {len(processed_segment_paths)} segments.")

        # 3. Создаем файл для FFmpeg со списком ОБРАБОТАННЫХ сегментов
        concat_list_path = os.path.join(UPLOAD_DIR, f"concat_list_{uuid.uuid4()}.txt")
        temp_files_to_clean.append(concat_list_path)
        with open(concat_list_path, "w") as f:
            for path in processed_segment_paths:
                f.write(f"file '{path}'\n")

        # 4. Вызываем FFmpeg для БЫСТРОЙ склейки БЕЗ перекодирования
        final_video_filename = f"{uuid.uuid4()}.mp4"
        final_video_path = os.path.join(UPLOAD_DIR, final_video_filename)
        ffmpeg_concat_command = [
            "ffmpeg",
            "-f", "concat",
            "-safe", "0",
            "-i", concat_list_path,
            "-bsf:a", "aac_adtstoasc",
            "-y",
            final_video_path
        ]
        logger.info(f"Concatenating segments: {' '.join(ffmpeg_concat_command)}")
        subprocess.run(ffmpeg_concat_command, check=True)

    except Exception as e:
        logger.error(f"Error during video processing: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to process video segments.")
    finally:
        # 5. Очищаем ВСЕ временные файлы
        if 'temp_files_to_clean' in locals():
            for path in temp_files_to_clean:
                if os.path.exists(path):
                    os.remove(path)
            logger.info("Cleaned up temporary segment files.")

    video_url = f"/uploads/{final_video_filename}"
    duration_ms = get_video_duration(final_video_path) # Предполагаем, что у вас есть такая функция
    message_content_dict = {"video_url": video_url, "transcription": None, "duration_ms": duration_ms}

    db_message = models.Message(
        chat_id=chat_uuid,
        sender_id=sender_uuid,
        content=json.dumps(message_content_dict), # Контент должен быть строкой JSON
        type="video", # Указываем тип
        reply_to_message_id=reply_to_uuid_obj
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    # Загружаем связанный объект, если он есть, для корректной сериализации
    db.refresh(db_message, ['reply_to_message'])

    # 4. Готовим сообщение для отправки по WebSocket
    message_data_str = schemas.MessageResponse.model_validate(db_message).model_dump_json()
    message_to_broadcast = json.loads(message_data_str)

    # 5. Отправляем сообщение всем в чате
    await manager.broadcast(chat_id, message_to_broadcast)

    return {"filename": final_video_filename, "url": video_url, "message_id": str(db_message.id)}

def get_video_duration(video_path: str) -> int:
    try:
        result = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", video_path],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, text=True
        )
        return int(float(result.stdout) * 1000)
    except Exception as e:
        logger.error(f"Could not get video duration for {video_path}: {e}")
        return 0

@router.post("/upload/audio")
async def upload_audio(
        chat_id: str,
        sender_id: str,
        reply_to_message_id: str | None = None,
        file: UploadFile = File(...),
        db: Session = Depends(database.get_db)
):
    logger.info(f"Uploading audio: {chat_id}, {sender_id}, {file.filename}")
    try:
        chat_uuid = uuid.UUID(chat_id)
        sender_uuid = uuid.UUID(sender_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid UUID format")

    chat_db = db.query(models.Chat).filter(models.Chat.id == chat_uuid).first()
    user_db = db.query(models.User).filter(models.User.id == sender_uuid).first()
    if not chat_db or not user_db:
        raise HTTPException(status_code=404, detail="Chat or User not found")

    reply_to_uuid_obj = None
    if reply_to_message_id:
        try:
            reply_to_uuid_obj = PyUUID(reply_to_message_id)
        except ValueError:
            logger.warning(f"Invalid reply_to_message_id format: {reply_to_message_id}")


    file_extension = file.filename.split('.')[-1] if '.' in file.filename else 'm4a'
    audio_filename = f"{uuid.uuid4()}.{file_extension}"
    audio_path = os.path.join(UPLOAD_DIR, audio_filename)

    file_content = await file.read()
    with open(audio_path, "wb") as buffer:
        buffer.write(file_content)
    logger.info(f"Audio saved to {audio_path}")

    duration_ms = 0
    try:
        audio_segment = AudioSegment.from_file(audio_path)
        duration_ms = len(audio_segment)
        logger.info(f"Audio duration: {duration_ms} ms")
    except Exception as e:
        logger.error(f"Could not get audio duration for {audio_path}: {e}")

    audio_url = f"/uploads/{audio_filename}"

    message_content_dict = {
        "audio_url": audio_url,
        "transcription": None,
        "duration_ms": duration_ms
    }

    db_message = models.Message(
        chat_id=chat_uuid,
        sender_id=sender_uuid,
        content=json.dumps(message_content_dict),
        type="audio",
        reply_to_message_id=reply_to_uuid_obj
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    db.refresh(db_message, ['reply_to_message'])

    # Валидируем через Pydantic, чтобы получить правильную структуру JSON
    message_data_str = schemas.MessageResponse.model_validate(db_message).model_dump_json()
    message_to_broadcast = json.loads(message_data_str)

    await manager.broadcast(chat_id, message_to_broadcast)

    return {"filename": audio_filename, "url": audio_url, "message_id": str(db_message.id)}


# --- ДЕЛАЕМ ЭНДПОИНТ ТРАНСКРИПЦИИ УНИВЕРСАЛЬНЫМ ---
@router.post("/transcribe/{message_id_str}")
async def transcribe_media_message(  # Переименовываем функцию
        message_id_str: str,
        db: Session = Depends(database.get_db)
):
    logger.info(f"Transcribing media message: {message_id_str}")
    try:
        message_uuid = uuid.UUID(message_id_str)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid message_id format")

    db_message = db.query(models.Message).filter(models.Message.id == message_uuid).first()

    if not db_message or db_message.type not in ["video", "audio"]:
        raise HTTPException(status_code=404, detail="Media message not found")

    content_data = json.loads(db_message.content)
    if content_data.get("transcription"):
        logger.info(f"Returning existing transcription for message {message_id_str}")
        return content_data["transcription"]

    media_url_relative = content_data.get("video_url") or content_data.get("audio_url")
    if not media_url_relative:
        raise HTTPException(status_code=404, detail="Media URL not found in message content")

    # Преобразуем в абсолютный путь внутри контейнера
    media_path_absolute = os.path.join(UPLOAD_DIR, os.path.basename(media_url_relative))
    logger.info(f"looking for media file at: {media_path_absolute}")

    if not os.path.exists(media_path_absolute):
        raise HTTPException(status_code=404, detail="Media file not found on server")

    logger.info(f"Starting transcription for {media_path_absolute}")
    transcription_result = None
    try:
        model = stable_whisper.load_model('base')
        result = model.transcribe(media_path_absolute, language="ru")

        words_data = []
        for segment in result.segments:
            for word in segment.words:
                words_data.append({
                    "word": word.word,
                    "start": word.start,
                    "end": word.end,
                    "id": str(uuid.uuid4())
                })
        transcription_result = {
            "full_text": result.text,
            "words": words_data
        }

        logger.info(f"Successfully transcribed. First few words: {words_data[:5]}")
        content_data["transcription"] = transcription_result
        db_message.content = json.dumps(content_data)
        db.commit()

    except Exception as e:
        # ... (обработка ошибок)
        logger.error(f"Could not transcribe media {media_path_absolute}: {e}", exc_info=True)
        transcription_result = {"full_text": "[Не удалось распознать речь]", "words": []}

    return transcription_result

# Аналогично делаем универсальным эндпоинт обновления
@router.put("/transcribe/{message_id_str}")
async def update_media_transcription( # Переименовываем
        message_id_str: str,
        transcription_data: dict,
        db: Session = Depends(database.get_db)
):
    logger.info(f"Updating transcription for message: {message_id_str}")
    try:
        message_uuid = uuid.UUID(message_id_str)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid message_id format")

    db_message = db.query(models.Message).filter(models.Message.id == message_uuid).first()
    if not db_message or db_message.type not in ["video", "audio"]:
        raise HTTPException(status_code=404, detail="Media message not found")

    content_data = json.loads(db_message.content)
    content_data["transcription"] = transcription_data
    db_message.content = json.dumps(content_data)
    db.commit()
    return {"status": "success", "message_id": message_id_str}


@router.post("/upload/avatar/{user_id_str}")
async def upload_avatar(
        user_id_str: str,
        file: UploadFile = File(...),
        current_user: models.User = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    """
    Загружает аватар для пользователя. Пользователь может загружать аватар только для себя.
    """
    if str(current_user.id) != user_id_str:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not allowed to upload an avatar for another user"
        )

    # Проверяем, что это изображение
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Invalid file type. Only images are allowed.")

    file_extension = file.filename.split('.')[-1] if '.' in file.filename else 'jpg'
    avatar_filename = f"avatar_{current_user.id}_{uuid.uuid4()}.{file_extension}"
    avatar_path = os.path.join(UPLOAD_DIR, avatar_filename)

    # Сохраняем файл
    with open(avatar_path, "wb") as buffer:
        buffer.write(await file.read())
    logger.info(f"Avatar for user {current_user.username} saved to {avatar_path}")

    # Формируем URL, который будет доступен через Nginx
    avatar_url = f"/uploads/{avatar_filename}"

    # Обновляем профиль пользователя в БД
    current_user.avatar_url = avatar_url
    db.add(current_user)
    db.commit()
    # db.refresh(current_user) # refresh не обязателен, т.к. мы возвращаем только URL

    return {"avatar_url": avatar_url}


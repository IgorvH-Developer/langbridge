from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List # Added for List type hint
from .. import models, database, schemas
from uuid import UUID as PyUUID

from ..logger import logger

router = APIRouter(prefix="/chats", tags=["chats"])

# --- Эндпоинт для создания нового чата ---
@router.post("/", response_model=schemas.ChatResponse, status_code=status.HTTP_201_CREATED)
async def create_chat(
        chat_data: schemas.ChatCreate, # Данные от клиента, валидируются Pydantic
        db: Session = Depends(database.get_db)
):
    logger.info(f"Attempting to create chat with title: '{chat_data.title}'")
    # Проверка, если нужно (например, на уникальность названия, хотя обычно не делают)

    # Создаем новый объект чата SQLAlchemy
    # id будет сгенерирован автоматически моделью (default=uuid.uuid4)
    new_chat = models.Chat(title=chat_data.title)

    try:
        db.add(new_chat)
        db.commit()
        db.refresh(new_chat) # Чтобы получить сгенерированный id и timestamp из БД
        logger.info(f"Successfully created chat '{new_chat.title}' with ID: {new_chat.id}")
        return new_chat
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to create chat '{chat_data.title}': {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not create chat."
        )

# --- Существующий эндпоинт для получения сообщений чата (можно оставить здесь же) ---
@router.get(
    "/{chat_id_str}/messages",
    response_model=List[schemas.MessageResponse] # Updated to use Pydantic schema
)
async def get_chat_messages(
        chat_id_str: str,
        db: Session = Depends(database.get_db)
):
    logger.info(f"Request for messages from chat_id: {chat_id_str}")
    try:
        chat_uuid = PyUUID(chat_id_str)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid chat_id format")

    chat = db.query(models.Chat).filter(models.Chat.id == chat_uuid).first()
    if not chat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat not found")

    messages = db.query(models.Message).filter(models.Message.chat_id == chat_uuid).order_by(models.Message.timestamp).all()
    return messages

@router.get("/", response_model=List[schemas.ChatResponse])
async def get_all_chats(skip: int = 0, limit: int = 100, db: Session = Depends(database.get_db)):
    logger.info(f"Request for all chats")
    chats = db.query(models.Chat).order_by(models.Chat.timestamp.desc()).offset(skip).limit(limit).all()
    return chats
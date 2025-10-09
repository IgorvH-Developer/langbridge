from typing import List
from uuid import UUID as PyUUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_
from sqlalchemy.orm import Session, aliased

from .users import get_current_user
from .. import models, database, schemas
from ..logger import logger

router = APIRouter(prefix="/api/chats", tags=["chats"])

# --- НАЙТИ ИЛИ СОЗДАТЬ ЛИЧНЫЙ ЧАТ ---
@router.post("/get-or-create/private", response_model=schemas.ChatResponse, status_code=status.HTTP_200_OK)
def get_or_create_private_chat(
        partner_id: PyUUID,
        current_user: models.User = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    """
    Ищет существующий личный чат между текущим пользователем и partner_id.
    Если чат не найден, создает новый. Возвращает найденный или созданный чат.
    """
    if current_user.id == partner_id:
        raise HTTPException(status_code=400, detail="Cannot create a chat with yourself.")

    # --- ИСПРАВЛЕННАЯ ЛОГИКА ЗАПРОСА ---
    # 2. Создаем псевдоним для таблицы участников для второго пользователя
    partner_participant = aliased(models.chat_participants)
    logger.info(f"creating chat with partner_id: {partner_id} with partner: {partner_participant.c.user_id}")

    # 3. Строим запрос с двумя разными join'ами
    chat = db.query(models.Chat).join(
        models.chat_participants, # Первый join для текущего пользователя
        and_(
            models.Chat.id == models.chat_participants.c.chat_id,
            models.chat_participants.c.user_id == current_user.id
        )
    ).join(
        partner_participant, # Второй join (с псевдонимом) для партнера
        and_(
            models.Chat.id == partner_participant.c.chat_id,
            partner_participant.c.user_id == partner_id
        )
    ).filter(
        models.Chat.title.is_(None) # Фильтр для личных чатов (без названия)
    ).first()

    # --- КОНЕЦ ИСПРАВЛЕННОЙ ЛОГИКИ ЗАПРОСА ---

    if chat:
        logger.info(f"Found existing private chat between {current_user.id} and {partner_id}")
        return chat

    # Если чат не найден, создаем новый
    logger.info(f"Creating new private chat between {current_user.id} and {partner_id}")

    partner = db.query(models.User).filter(models.User.id == partner_id).first()
    if not partner:
        raise HTTPException(status_code=404, detail="Partner user not found.")

    new_chat = models.Chat() # title остается None
    new_chat.participants.append(current_user)
    new_chat.participants.append(partner)

    db.add(new_chat)
    db.commit()
    db.refresh(new_chat)

    return new_chat

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

# --- ЛОГИКА ПОЛУЧЕНИЯ ВСЕХ ЧАТОВ ---
@router.get("/", response_model=List[schemas.ChatResponse])
async def get_user_chats(
        current_user: models.User = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    """
    Возвращает список чатов, в которых состоит текущий пользователь И в которых есть хотя бы одно сообщение.
    """
    chats = db.query(models.Chat).join(
        models.chat_participants
    ).filter(
        models.chat_participants.c.user_id == current_user.id
    ).join( # Добавляем join к сообщениям, чтобы отфильтровать пустые чаты
        models.Message, models.Message.chat_id == models.Chat.id
    ).distinct().order_by(models.Chat.timestamp.desc()).all() # distinct() чтобы не было дублей

    return chats
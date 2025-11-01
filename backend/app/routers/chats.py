from typing import List
from uuid import UUID as PyUUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_, select, func, desc, join
from sqlalchemy.orm import Session, aliased, joinedload, contains_eager
import json

from ..fcm_service import send_push_notification
from pydantic import BaseModel
from .users import get_current_user
from .. import models, database, schemas
from ..logger import logger

router = APIRouter(prefix="/api/chats", tags=["chats"])

class CallNotificationPayload(BaseModel):
    is_video: bool
    offer_sdp: dict # Клиент будет присылать offer прямо сюда

@router.post("/{chat_id_str}/notify-call", status_code=status.HTTP_204_NO_CONTENT)
async def notify_call(
        chat_id_str: str,
        payload: CallNotificationPayload,
        current_user: models.User = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    """Отправляет push-уведомление о входящем звонке другим участникам чата."""
    try:
        chat_uuid = PyUUID(chat_id_str)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid chat ID format")

    # Находим всех участников чата, кроме звонящего
    participants_to_notify = db.query(models.User).join(models.chat_participants).filter(
        models.chat_participants.c.chat_id == chat_uuid,
        models.User.id != current_user.id
    ).all()

    fcm_tokens = [p.fcm_token for p in participants_to_notify if p.fcm_token]

    if not fcm_tokens:
        logger.warning(f"User {current_user.id} is calling in chat {chat_id_str}, but no users with FCM tokens found to notify.")
        return

    call_type_str = "Видеозвонок" if payload.is_video else "Аудиозвонок"

    notification_payload = {
        "title": f"Входящий {call_type_str}",
        "body": f"От {current_user.username}",
    }

    data_payload = {
        "type": "incoming_call",
        "chat_id": chat_id_str,
        "caller_name": current_user.username,
        "caller_id": str(current_user.id),
        "is_video": str(payload.is_video).lower(),
        "offer_sdp": json.dumps(payload.offer_sdp)
    }

    await send_push_notification(fcm_tokens, notification_payload, data_payload)
    logger.info(f"Sent call notification to {len(fcm_tokens)} users for chat {chat_id_str}.")


@router.post("/get-or-create/private", response_model=schemas.ChatWithParticipantsResponse, status_code=status.HTTP_200_OK)
def get_or_create_private_chat(
        partner_id: PyUUID,
        current_user: models.User = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    if current_user.id == partner_id:
        raise HTTPException(status_code=400, detail="Cannot create a chat with yourself.")

    partner_participant = aliased(models.chat_participants)

    chat = db.query(models.Chat).join(
        models.chat_participants,
        and_(
            models.Chat.id == models.chat_participants.c.chat_id,
            models.chat_participants.c.user_id == current_user.id
        )
    ).join(
        partner_participant,
        and_(
            models.Chat.id == partner_participant.c.chat_id,
            partner_participant.c.user_id == partner_id
        )
    ).options(
        joinedload(models.Chat.participants).subqueryload(models.User.language_associations).joinedload(models.UserLanguageAssociation.language)
    ).filter(
        models.Chat.title.is_(None)
    ).first()

    if chat:
        logger.info(f"Found existing private chat between {current_user.id} and {partner_id}")
        return schemas.ChatWithParticipantsResponse.model_validate(chat)

    logger.info(f"Creating new private chat between {current_user.id} and {partner_id}")
    partner = db.query(models.User).filter(models.User.id == partner_id).first()
    if not partner:
        raise HTTPException(status_code=404, detail="Partner user not found.")

    new_chat = models.Chat()
    new_chat.participants.append(current_user)
    new_chat.participants.append(partner)

    db.add(new_chat)
    db.commit()
    db.refresh(new_chat)

    return schemas.ChatWithParticipantsResponse.model_validate(new_chat)


@router.post("/", response_model=schemas.ChatWithParticipantsResponse, status_code=status.HTTP_201_CREATED)
async def create_chat(
        chat_data: schemas.ChatCreate,
        current_user: models.User = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    logger.info(f"User '{current_user.username}' creating chat with title: '{chat_data.title}'")

    new_chat = models.Chat(title=chat_data.title)
    new_chat.participants.append(current_user)

    try:
        db.add(new_chat)
        db.commit()
        db.refresh(new_chat)
        logger.info(f"Successfully created chat '{new_chat.title}' with ID: {new_chat.id}")
        return schemas.ChatWithParticipantsResponse.model_validate(new_chat)
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to create chat '{chat_data.title}': {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not create chat."
        )


@router.get("/{chat_id_str}/messages", response_model=List[schemas.MessageResponse])
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

    RepliedMessage = aliased(models.Message)

    stmt = (
        select(models.Message)
        .outerjoin(RepliedMessage, models.Message.reply_to_message_id == RepliedMessage.id)
        .options(
            contains_eager(models.Message.reply_to_message.of_type(RepliedMessage))
        )
        .filter(models.Message.chat_id == chat_uuid)
        .order_by(models.Message.timestamp)
    )

    messages = db.execute(stmt).scalars().all()

    logger.info(f"Found {len(messages)} messages for chat {chat_uuid}")
    return messages


@router.get("/", response_model=List[schemas.ChatResponse])
async def get_user_chats(
        current_user: models.User = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    """
    Возвращает список чатов, в которых состоит ТЕКУЩИЙ пользователь,
    с подсчетом непрочитанных сообщений и последним сообщением.
    """
    logger.info(f"Fetching chats for user {current_user.id} ({current_user.username})")

    # 1. Правильно получаем все чаты, в которых состоит текущий пользователь
    user_chats_query = db.query(models.Chat).join(
        models.chat_participants,
        models.Chat.id == models.chat_participants.c.chat_id
    ).filter(
        models.chat_participants.c.user_id == current_user.id
    ).options(
        # Предзагружаем участников, чтобы избежать N+1 запросов позже
        joinedload(models.Chat.participants)
    )

    user_chats = user_chats_query.all()

    if not user_chats:
        logger.info(f"No chats found for user {current_user.id}")
        return []

    chat_ids = [chat.id for chat in user_chats]
    logger.info(f"User {current_user.id} is a participant of {len(chat_ids)} chats. Fetching details.")

    # 2. Оптимизированный запрос для получения последних сообщений
    last_message_subquery = select(
        models.Message.chat_id,
        func.max(models.Message.timestamp).label('max_ts')
    ).where(models.Message.chat_id.in_(chat_ids)).group_by(models.Message.chat_id).subquery('last_msg_sq')

    last_messages_q = select(models.Message).join(
        last_message_subquery,
        and_(
            models.Message.chat_id == last_message_subquery.c.chat_id,
            models.Message.timestamp == last_message_subquery.c.max_ts
        )
    )
    last_messages = db.execute(last_messages_q).scalars().all()
    last_messages_map = {msg.chat_id: msg for msg in last_messages}

    # 3. Оптимизированный запрос для подсчета непрочитанных сообщений
    unread_counts_q = select(
        models.Message.chat_id,
        func.count().label('unread_count')
    ).where(
        models.Message.chat_id.in_(chat_ids),
        models.Message.is_read == False,
        models.Message.sender_id != current_user.id # Считаем только чужие непрочитанные
    ).group_by(models.Message.chat_id)

    unread_counts_result = db.execute(unread_counts_q).all()
    unread_counts_map = {chat_id: count for chat_id, count in unread_counts_result}

    # 4. Собираем ответ
    response_chats = []
    for chat in user_chats:
        chat_data = schemas.ChatResponse.model_validate(chat)
        chat_data.last_message = last_messages_map.get(chat.id)
        chat_data.unread_count = unread_counts_map.get(chat.id, 0)
        response_chats.append(chat_data)

    # 5. Сортировка
    response_chats.sort(
        key=lambda c: c.last_message.timestamp if c.last_message else c.timestamp,
        reverse=True
    )
    logger.info(f"Returning {len(response_chats)} chats for user {current_user.id}")
    return response_chats

@router.post("/{chat_id_str}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_chat_as_read(
        chat_id_str: str,
        current_user: models.User = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    """Помечает все сообщения в чате как прочитанные для текущего пользователя."""
    try:
        chat_uuid = PyUUID(chat_id_str)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid chat ID format")

    # Обновляем все сообщения в чате, которые не от текущего пользователя
    db.query(models.Message).filter(
        models.Message.chat_id == chat_uuid,
        models.Message.sender_id != current_user.id
    ).update({"is_read": True}, synchronize_session=False)

    db.commit()
    logger.info(f"User {current_user.id} marked chat {chat_id_str} as read.")

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.orm import Session
from uuid import UUID as PyUUID
from datetime import datetime
import json

from starlette.websockets import WebSocketState

from .. import database, models
from ..schemas import MessageResponse
from ..websocket_manager import ConnectionManager
from ..logger import logger # Предполагаем, что у вас есть logger

router = APIRouter(prefix="/ws", tags=["websocket"])

manager = ConnectionManager()

@router.websocket("/{chat_id_str}")
async def websocket_endpoint(
        websocket: WebSocket, chat_id_str: str, db: Session = Depends(database.get_db)
):
    logger.info(f"WebSocket connection attempt for chat_id_str: {chat_id_str}")

    try:
        chat_uuid_obj = PyUUID(chat_id_str)
    except ValueError:
        logger.error(f"Invalid UUID format for chat_id_str: '{chat_id_str}'. Closing WebSocket.")
        await websocket.close(code=1008)
        return

    chat_db_entry = db.query(models.Chat).filter(models.Chat.id == chat_uuid_obj).first()
    if not chat_db_entry:
        logger.warning(f"Chat with UUID '{chat_uuid_obj}' not found in database. Closing WebSocket.")
        await websocket.close(code=1003)
        return

    # Получаем user_id из query-параметров для идентификации сокета
    user_id = websocket.query_params.get("user_id")
    if not user_id:
        logger.error("User ID not provided in query params. Closing connection.")
        await websocket.close(code=1008)
        return

    logger.info(f"Chat '{chat_db_entry.title}' (UUID: {chat_uuid_obj}) found. Accepting WebSocket connection for user {user_id}.")
    await manager.connect(chat_id_str, user_id, websocket)

    try:
        while True:
            data_str = await websocket.receive_text()
            data = json.loads(data_str)
            logger.debug(f"Received data from user '{user_id}' in chat '{chat_id_str}': {data}")

            message_type = data.get("type", "text")
            sender_id = data.get("sender_id")
            client_message_id = data.get("client_message_id")

            # 1. Сигнальные сообщения WebRTC пересылаются напрямую другому участнику
            if message_type in ["call_offer", "call_answer", "ice_candidate", "call_end"]:
                await manager.broadcast_to_others(chat_id_str, user_id, data)
                logger.info(f"Broadcasted WebRTC signal '{message_type}' from {user_id} in chat {chat_id_str}")
                continue # Переходим к следующему сообщению

            # 2. Обработка обычных текстовых сообщений
            try:
                sender_uuid_obj = PyUUID(sender_id)
            except (ValueError, KeyError, TypeError) as e:
                logger.error(f"Invalid or missing sender_id: {sender_id}. Error: {e}")
                await websocket.send_json({"error": "Invalid or missing sender_id"})
                continue

            content = data.get("content")
            if not content:
                logger.warning(f"Empty content received for chat '{chat_id_str}'.")
                await websocket.send_json({"error": "Content cannot be empty"})
                continue

            reply_to_id_str = data.get("reply_to_message_id")
            reply_to_uuid_obj = None
            if reply_to_id_str:
                try:
                    reply_to_uuid_obj = PyUUID(reply_to_id_str)
                except (ValueError, TypeError):
                    logger.warning(f"Invalid reply_to_message_id format: {reply_to_id_str}")

            db_message = models.Message(
                chat_id=chat_uuid_obj,
                sender_id=sender_uuid_obj,
                content=content,
                type=message_type,
                timestamp=data.get("timestamp", datetime.now()),
                reply_to_message_id=reply_to_uuid_obj
            )
            db.add(db_message)
            db.commit()
            db.refresh(db_message)
            logger.info(f"Message (ID: {db_message.id}) saved to DB for chat (UUID: {chat_uuid_obj})")

            db.refresh(db_message, ['reply_to_message'])

            # Преобразуем сообщение из БД в Pydantic-схему
            response_model = MessageResponse.model_validate(db_message)

            # Добавляем временный ID в модель ответа, если он был
            if client_message_id:
                response_model.client_message_id = client_message_id

            # Сериализуем и отправляем
            message_to_broadcast = json.loads(response_model.model_dump_json())
            await manager.broadcast(chat_id_str, message_to_broadcast)

    except WebSocketDisconnect:
        logger.info(f"User {user_id} disconnected from chat: {chat_id_str}")
    except Exception as e:
        logger.error(f"Unexpected error in WebSocket for user {user_id} in chat {chat_id_str}: {e}", exc_info=True)
    finally:
        manager.disconnect(chat_id_str, user_id)
        logger.info(f"WebSocket connection for user {user_id} in chat {chat_id_str} fully closed.")


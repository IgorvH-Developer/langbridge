from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.orm import Session
from uuid import UUID as PyUUID # Импортируем для преобразования и проверки типа
from datetime import datetime # Для форматирования created_at

from starlette.websockets import WebSocketState

from .. import database, models
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
        await websocket.close(code=1008) # Policy Violation (неверный формат ID)
        return

    # 2. Проверить, существует ли чат с таким UUID в базе данных
    chat_db_entry = db.query(models.Chat).filter(models.Chat.id == chat_uuid_obj).first()
    if not chat_db_entry:
        logger.warning(f"Chat with UUID '{chat_uuid_obj}' not found in database. Closing WebSocket.")
        await websocket.close(code=1003) # Cannot Accept Data (или другой подходящий код, например, 1011 - Internal Error, если чат должен быть)
        return

    logger.info(f"Chat '{chat_db_entry.title}' (UUID: {chat_uuid_obj}) found. Accepting WebSocket connection.")
    # Только если чат существует, продолжаем и подключаем к менеджеру
    await manager.connect(chat_id_str, websocket) # ConnectionManager может использовать строку как ключ

    try:
        while True:
            data = await websocket.receive_json()
            logger.debug(f"Received data from chat '{chat_id_str}': {data}")

            # Валидация sender_id (предполагаем, что клиент шлет UUID строку)
            try:
                sender_uuid_obj = PyUUID(data["sender_id"])
            except (ValueError, KeyError, TypeError) as e:
                logger.error(f"Invalid or missing sender_id: {data.get('sender_id')}. Error: {e}")
                await websocket.send_json({"error": "Invalid or missing sender_id"})
                continue

            content = data.get("content")
            if not content: # Простая проверка на пустой контент
                logger.warning(f"Empty content received for chat '{chat_id_str}'.")
                await websocket.send_json({"error": "Content cannot be empty"})
                continue

            # Создание сообщения в БД
            db_message = models.Message(
                # id будет сгенерирован БД или default в модели, если не uuid.uuid4()
                chat_id=chat_uuid_obj,  # <--- Используем проверенный объект UUID чата
                sender_id=sender_uuid_obj, # Используем проверенный объект UUID отправителя
                content=content,
                type=data.get("type", "text")
                # created_at будет установлен БД по server_default
            )
            db.add(db_message)
            db.commit()
            db.refresh(db_message)

            logger.info(f"Message (ID: {db_message.id}) saved to DB for chat (UUID: {chat_uuid_obj})")

            # Формирование ответа для рассылки
            message_to_broadcast = {
                "id": str(db_message.id),
                "chat_id": str(db_message.chat_id), # = chat_id_str
                "sender_id": str(db_message.sender_id),
                "content": db_message.content,
                "type": db_message.type,
                "timestamp": db_message.created_at.isoformat() # Используем ISO формат для datetime
            }
            await manager.broadcast(chat_id_str, message_to_broadcast)

    except WebSocketDisconnect:
        logger.info(f"Client disconnected from chat: {chat_id_str}")
    except Exception as e:
        logger.error(f"Unexpected error in WebSocket for chat {chat_id_str}: {e}", exc_info=True)
        # exc_info=True добавит traceback в лог
    finally:
        # Убедимся, что соединение удалено из менеджера в любом случае (кроме успешного disconnect)
        # Если WebSocketDisconnect уже обработан, manager.disconnect там уже вызван.
        # Этот блок finally полезен для неожиданных исключений.
        if websocket.client_state != WebSocketState.DISCONNECTED: # Проверка состояния, чтобы не вызывать disconnect дважды
            manager.disconnect(chat_id_str, websocket)
        logger.info(f"WebSocket connection for chat {chat_id_str} fully closed.")


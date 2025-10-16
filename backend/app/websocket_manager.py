from typing import Dict, List
from fastapi import WebSocket
from starlette.websockets import WebSocketState
from .logger import logger

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, chat_id: str, websocket: WebSocket):
        logger.info(f"Got connection request from {chat_id}")
        await websocket.accept()
        if chat_id not in self.active_connections:
            self.active_connections[chat_id] = []
        self.active_connections[chat_id].append(websocket)

    def disconnect(self, chat_id: str, websocket: WebSocket):
        logger.info(f"Got disconnect request from {chat_id}")
        if chat_id in self.active_connections:
            if websocket in self.active_connections[chat_id]:
                self.active_connections[chat_id].remove(websocket)
            if not self.active_connections[chat_id]:
                del self.active_connections[chat_id]

    async def broadcast(self, chat_id: str, message: dict):
        logger.info(f"Got broadcast for chat {chat_id}")
        if chat_id in self.active_connections:
            # Создаем копию списка, чтобы безопасно удалять из него "мертвые" соединения
            connections_to_iterate = self.active_connections[chat_id][:]

            for connection in connections_to_iterate:
                # 2. Проверяем состояние соединения перед отправкой
                if connection.client_state == WebSocketState.CONNECTED:
                    try:
                        await connection.send_json(message)
                        logger.debug(f"Broadcasted to a client in chat {chat_id}")
                    except RuntimeError as e:
                        logger.warning(f"RuntimeError during broadcast to chat {chat_id}: {e}. Removing connection.")
                        self.disconnect(chat_id, connection)
                else:
                    # 3. Если соединение уже не активно, удаляем его
                    logger.warning(f"Found stale connection in chat {chat_id}. Removing.")
                    self.disconnect(chat_id, connection)

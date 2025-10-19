from typing import Dict, List, Any
from fastapi import WebSocket
from starlette.websockets import WebSocketState
from .logger import logger

class ConnectionManager:
    def __init__(self):
        # Структура: { "chat_id": { "user_id": WebSocket } }
        self.active_connections: Dict[str, Dict[str, WebSocket]] = {}

    async def connect(self, chat_id: str, user_id: str, websocket: WebSocket):
        logger.info(f"Got connection request from {chat_id}")
        await websocket.accept()
        if chat_id not in self.active_connections:
            self.active_connections[chat_id] = {}
        self.active_connections[chat_id][user_id] = websocket
        logger.info(f"User {user_id} connected to chat {chat_id}")

    def disconnect(self, chat_id: str, user_id: str):
        logger.info(f"Got disconnect request from {chat_id}")
        if chat_id in self.active_connections and user_id in self.active_connections[chat_id]:
            del self.active_connections[chat_id][user_id]
            if not self.active_connections[chat_id]:
                del self.active_connections[chat_id]
            logger.info(f"User {user_id} disconnected from chat {chat_id}")

    async def broadcast(self, chat_id: str, message: Any):
        logger.info(f"Got broadcast for chat {chat_id}")
        if chat_id in self.active_connections:
            for user_id, connection in self.active_connections[chat_id].items():
                if connection.client_state == WebSocketState.CONNECTED:
                    try:
                        await connection.send_json(message)
                        logger.debug(f"Broadcasted to a client in chat {chat_id}")
                    except Exception as e:
                        logger.error(f"Error broadcasting to {user_id} in chat {chat_id}: {e}")

    async def broadcast_to_others(self, chat_id: str, sender_id: str, message: Any):
        """Отправляет сообщение всем в чате, кроме отправителя."""
        if chat_id in self.active_connections:
            for user_id, connection in self.active_connections[chat_id].items():
                if user_id != sender_id: # Ключевое условие
                    if connection.client_state == WebSocketState.CONNECTED:
                        try:
                            await connection.send_json(message)
                            logger.info(f"Sent signal from {sender_id} to {user_id} in chat {chat_id}")
                        except Exception as e:
                            logger.error(f"Error sending signal to {user_id} in chat {chat_id}: {e}")


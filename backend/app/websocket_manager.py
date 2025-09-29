from typing import Dict, List
from fastapi import WebSocket
from .logger import logger

class ConnectionManager:
    def __init__(self):
        # ключ = chat_id, значение = список соединений
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
            self.active_connections[chat_id].remove(websocket)

    async def broadcast(self, chat_id: str, message: dict):
        logger.info(f"Got broadcast from {chat_id}")
        if chat_id in self.active_connections:
            for connection in self.active_connections[chat_id]:
                await connection.send_json(message)

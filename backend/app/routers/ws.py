from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.orm import Session
from .. import database, models
from ..websocket_manager import ConnectionManager
import uuid

router = APIRouter(tags=["websocket"])

manager = ConnectionManager()

@router.websocket("/ws/{chat_id}")
async def websocket_endpoint(websocket: WebSocket, chat_id: str, db: Session = Depends(database.get_db)):
    await manager.connect(chat_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            # Клиент прислал новое сообщение
            message = models.Message(
                id=uuid.uuid4(),
                chat_id=chat_id,
                sender_id=data["sender_id"],
                content=data["content"],
                type=data.get("type", "text")
            )
            db.add(message)
            db.commit()
            db.refresh(message)

            # Отправляем всем подписчикам чата
            await manager.broadcast(chat_id, {
                "id": str(message.id),
                "chat_id": str(message.chat_id),
                "sender_id": str(message.sender_id),
                "content": message.content,
                "type": message.type,
                "created_at": str(message.created_at)
            })
    except WebSocketDisconnect:
        manager.disconnect(chat_id, websocket)
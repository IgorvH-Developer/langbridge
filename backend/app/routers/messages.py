import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from .. import models, database
from ..logger import logger

router = APIRouter(prefix="/messages", tags=["messages"])

@router.post("/")
def send_message(chat_id: str, sender_id: str, content: str, type: str = "text", db: Session = Depends(database.get_db)):
    logger.info(f"Got request to send message {chat_id}")
    message = models.Message(
        id=uuid.uuid4(),
        chat_id=chat_id,
        sender_id=sender_id,
        content=content,
        type=type,
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    return message
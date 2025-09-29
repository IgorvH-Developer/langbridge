from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from .. import models, database

router = APIRouter(prefix="/chats", tags=["chats"])

@router.get("/{chat_id}/messages")
def get_messages(chat_id: str, db: Session = Depends(database.get_db)):
    print(f"Got request for messages from {chat_id}")
    messages = db.query(models.Message).filter(models.Message.chat_id == chat_id).order_by(models.Message.created_at).all()
    print(f"Returned {len(messages)} messages")
    return messages
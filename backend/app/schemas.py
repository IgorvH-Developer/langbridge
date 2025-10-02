from pydantic import BaseModel, Field
from uuid import UUID as PyUUID # Используем PyUUID, чтобы не путать с полем модели
from datetime import datetime

# Схема для создания чата (что клиент должен отправить)
class ChatCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=100, examples=["Обсуждение проекта X"])
    # Можно добавить сюда user_ids для начальных участников, если нужно

# Схема для ответа с информацией о чате (что сервер вернет)
class ChatResponse(BaseModel):
    id: PyUUID
    title: str
    created_at: datetime

    class Config:
        orm_mode = True # Позволяет создавать схему из объекта SQLAlchemy
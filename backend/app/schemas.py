from pydantic import BaseModel, Field
from uuid import UUID as PyUUID # Используем PyUUID, чтобы не путать с полем модели
from datetime import datetime
from typing import Optional

# --- Языки ---
class LanguageBase(BaseModel):    name: str
code: str

class LanguageInDB(LanguageBase):
    id: int
    class Config:
        orm_mode = True

class UserLanguageLink(BaseModel):
    id: int
    name: str
    code: str
    level: str

# --- Пользователи ---
class UserCreate(BaseModel):
    username: str
    password: str

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    age: Optional[int] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    interests: Optional[str] = None

class UserResponse(BaseModel):
    id: PyUUID
    username: str
    full_name: Optional[str] = None
    age: Optional[int] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    interests: Optional[str] = None
    # languages: List[UserLanguageLink] # Это более сложная схема, пока оставим

    class Config:
        orm_mode = True

# --- Токены для аутентификации ---
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

# Схема для создания чата (что клиент должен отправить)
class ChatCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=100, examples=["Обсуждение проекта X"])
    # Можно добавить сюда user_ids для начальных участников, если нужно

# Схема для ответа с информацией о чате (что сервер вернет)
class ChatResponse(BaseModel):
    id: PyUUID
    title: str
    timestamp: datetime

    class Config:
        orm_mode = True # Позволяет создавать схему из объекта SQLAlchemy

# Схема для ответа с информацией о сообщении
class MessageResponse(BaseModel):
    id: PyUUID
    chat_id: PyUUID
    sender_id: PyUUID
    content: str
    type: str
    timestamp: datetime

    class Config:
        orm_mode = True

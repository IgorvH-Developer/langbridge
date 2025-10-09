from pydantic import BaseModel, Field
from uuid import UUID as PyUUID
from datetime import datetime
from typing import Optional, List

# --- Языки ---
class LanguageBase(BaseModel):
    name: str
    code: str

class LanguageInDB(LanguageBase):
    id: int
    class Config:
        from_attributes = True # <--- ИЗМЕНЕНИЕ

class UserLanguageLink(BaseModel):
    id: int
    name: str
    code: str
    level: str
    type: str

    class Config:
        from_attributes = True

# Схема для обновления информации о языке пользователя
class LanguageUpdate(BaseModel):
    language_id: int
    level: str
    type: str

# --- Пользователи ---
class UserCreate(BaseModel):
    username: str
    password: str

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    gender: Optional[str] = None
    age: Optional[int] = None
    country: Optional[str] = None
    height: Optional[int] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    interests: Optional[str] = None

class UserProfileResponse(BaseModel):
    id: PyUUID
    username: str
    full_name: Optional[str] = None
    gender: Optional[str] = None
    age: Optional[int] = None
    country: Optional[str] = None
    height: Optional[int] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    interests: Optional[str] = None
    languages: List[UserLanguageLink] = []

    class Config:
        from_attributes = True

# Добавим простую схему для участника чата
class ParticipantResponse(BaseModel):
    id: PyUUID
    username: str
    avatar_url: Optional[str] = None

    class Config:
        from_attributes = True

# Упрощенная схема для списков пользователей
class UserInListResponse(BaseModel):
    id: PyUUID
    username: str
    avatar_url: Optional[str] = None
    country: Optional[str] = None
    languages: List[UserLanguageLink] = []

    class Config:
        from_attributes = True

# --- Токены для аутентификации ---
class Token(BaseModel):
    access_token: str
    token_type: str
    user_id: PyUUID

class TokenData(BaseModel):
    username: Optional[str] = None

# Схема для создания чата
class ChatCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=100, examples=["Обсуждение проекта X"])

# Схема для ответа с информацией о чате
class ChatResponse(BaseModel):
    id: PyUUID
    title: Optional[str] = None
    timestamp: datetime
    participants: List[ParticipantResponse] = []

    class Config:
        from_attributes = True

# Схема для ответа с информацией о сообщении
class MessageResponse(BaseModel):
    id: PyUUID
    chat_id: PyUUID
    sender_id: PyUUID
    content: str
    type: str
    timestamp: datetime

    class Config:
        from_attributes = True

import uuid
from sqlalchemy import Column, String, Text, ForeignKey, TIMESTAMP, func, Integer, Table
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .database import Base

# --- Таблица для связи "многие ко многим" между пользователями и языками ---
user_languages = Table('user_languages', Base.metadata,
                       Column('user_id', UUID(as_uuid=True), ForeignKey('users.id', ondelete="CASCADE"), primary_key=True),
                       Column('language_id', Integer, ForeignKey('languages.id', ondelete="CASCADE"), primary_key=True),
                       Column('level', String(50)) # Например, 'A1', 'B2', 'Native'
                       )

# --- Таблица для хранения языков ---
class Language(Base):
    __tablename__ = "languages"
    id = Column(Integer, primary_key=True)
    name = Column(String(100), unique=True, nullable=False) # 'English', 'Russian'
    code = Column(String(10), unique=True, nullable=False) # 'en', 'ru'

# --- Новая модель пользователя ---
class User(Base):
    __tablename__ = "users"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Для аутентификации (в реальном приложении пароль нужно хешировать!)
    username = Column(String(100), unique=True, index=True, nullable=False)
    # email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False) # Храним только хеш

    # Личная информация
    full_name = Column(String(150))
    age = Column(Integer)
    bio = Column(Text)
    avatar_url = Column(String) # URL на фото профиля
    interests = Column(Text) # Можно хранить как строку с разделителями-запятыми

    # Связи
    messages_sent = relationship("Message", back_populates="sender")

    # Связь с языками (многие ко многим)
    languages = relationship("Language", secondary=user_languages, back_populates="users")

# Добавим обратную связь в Language, если нужно
Language.users = relationship("User", secondary=user_languages, back_populates="languages")


# --- Существующие модели с обновлением ---
class Chat(Base):
    __tablename__ = "chats"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String, nullable=False)
    timestamp = Column(TIMESTAMP, server_default=func.now())
    messages = relationship("Message", back_populates="chat")

class Message(Base):
    __tablename__ = "messages"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chat_id = Column(UUID(as_uuid=True), ForeignKey("chats.id", ondelete="CASCADE"))
    sender_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    content = Column(Text)
    type = Column(String, default="text")
    timestamp = Column(TIMESTAMP, server_default=func.now())
    chat = relationship("Chat", back_populates="messages")
    sender = relationship("User", back_populates="messages_sent") # <--- Связь с User

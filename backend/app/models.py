import uuid
from sqlalchemy import Column, String, Text, ForeignKey, TIMESTAMP, func, Integer, Table, types
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from .database import Base

# --- Custom UUID Type for cross-dialect compatibility (the correct way) ---
class GUID(types.TypeDecorator):
    """Platform-independent GUID type.

    Uses PostgreSQL's UUID type, otherwise uses
    CHAR(32) for other dialects.
    """
    impl = types.CHAR
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == 'postgresql':
            return dialect.type_descriptor(PG_UUID(as_uuid=True))
        else:
            return dialect.type_descriptor(types.CHAR(32))

    def process_bind_param(self, value, dialect):
        if value is None:
            return value
        elif dialect.name == 'postgresql':
            return str(value)
        else:
            if not isinstance(value, uuid.UUID):
                return "%.32x" % uuid.UUID(value).int
            else:
                return "%.32x" % value.int

    def process_result_value(self, value, dialect):
        if value is None:
            return value
        else:
            if not isinstance(value, uuid.UUID):
                value = uuid.UUID(value)
            return value

# --- Таблица для связи "многие ко многим" между пользователями и языками ---
user_languages = Table('user_languages', Base.metadata,
                       Column('user_id', GUID(), ForeignKey('users.id', ondelete="CASCADE"), primary_key=True),
                       Column('language_id', Integer, ForeignKey('languages.id', ondelete="CASCADE"), primary_key=True),
                       Column('level', String(50))
                       )

# --- Таблица для хранения языков ---
class Language(Base):
    __tablename__ = "languages"
    id = Column(Integer, primary_key=True)
    name = Column(String(100), unique=True, nullable=False)
    code = Column(String(10), unique=True, nullable=False)

# --- Новая модель пользователя ---
class User(Base):
    __tablename__ = "users"
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    username = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    full_name = Column(String(150))
    age = Column(Integer)
    bio = Column(Text)
    avatar_url = Column(String)
    interests = Column(Text)
    messages_sent = relationship("Message", back_populates="sender")
    languages = relationship("Language", secondary=user_languages, back_populates="users")

Language.users = relationship("User", secondary=user_languages, back_populates="languages")

# --- Существующие модели с обновлением ---
class Chat(Base):
    __tablename__ = "chats"
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    title = Column(String, nullable=False)
    timestamp = Column(TIMESTAMP, server_default=func.now())
    messages = relationship("Message", back_populates="chat")

class Message(Base):
    __tablename__ = "messages"
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    chat_id = Column(GUID(), ForeignKey("chats.id", ondelete="CASCADE"))
    sender_id = Column(GUID(), ForeignKey("users.id"))
    content = Column(Text)
    type = Column(String, default="text")
    timestamp = Column(TIMESTAMP, server_default=func.now())
    chat = relationship("Chat", back_populates="messages")
    sender = relationship("User", back_populates="messages_sent")

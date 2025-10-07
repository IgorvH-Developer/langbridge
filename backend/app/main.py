from fastapi import FastAPI
from .routers import chats, messages, ws, users, media
from .logger import logger

# УБИРАЕМ ЭТУ СТРОКУ. ОНА ЯВЛЯЕТСЯ ПРИЧИНОЙ ОШИБКИ.
# Base.metadata.create_all(bind=engine)

app = FastAPI(title="Chat Backend")

# Можно добавить обработчики событий для создания таблиц при старте (хорошая практика)
@app.on_event("startup")
def on_startup():
    from .database import Base, engine # Импортируем здесь, чтобы избежать циклических зависимостей
    logger.info("Creating all database tables...")
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables created.")

app.include_router(users.router)
app.include_router(chats.router)
app.include_router(messages.router)
app.include_router(media.router)
app.include_router(ws.router)

logger.info("Application startup configuration complete.")

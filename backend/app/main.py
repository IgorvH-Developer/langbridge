import os

from fastapi import FastAPI

from . import models
from .database import SessionLocal, Base, engine
from .routers import chats, messages, ws, users, media, translate
from .logger import logger

# УБИРАЕМ ЭТУ СТРОКУ. ОНА ЯВЛЯЕТСЯ ПРИЧИНОЙ ОШИБКИ.
# Base.metadata.create_all(bind=engine)

app = FastAPI(title="Chat Backend")

@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables created.")

    # --- ИЗМЕНЕННЫЙ БЛОК ---
    # Наполняем БД языками, только если это НЕ тестовый режим
    if os.getenv("TESTING") != "1": # <<< Оборачиваем в это условие
        db = SessionLocal()
        try:
            if db.query(models.Language).count() == 0:
                logger.info("Languages table is empty. Populating with initial data...")
                languages_to_add = [
                    models.Language(name="English", code="en"),
                    models.Language(name="Русский", code="ru"),
                    models.Language(name="Español", code="es"),
                    models.Language(name="Français", code="fr"),
                    models.Language(name="Deutsch", code="de"),
                    models.Language(name="中文", code="zh"),
                    # Добавьте другие языки по необходимости
                ]
                db.add_all(languages_to_add)
                db.commit()
                logger.info("Languages table populated.")
        finally:
            db.close()

app.include_router(users.router)
app.include_router(chats.router)
app.include_router(messages.router)
app.include_router(media.router)
app.include_router(ws.router)
app.include_router(translate.router)

logger.info("Application startup configuration complete.")

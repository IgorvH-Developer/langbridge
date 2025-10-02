from fastapi import FastAPI
from .database import Base, engine
from .routers import chats, messages, ws
from .logger import logger

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Chat Backend")

app.include_router(chats.router)
app.include_router(messages.router)
app.include_router(ws.router)

logger.info("Application startup complete.")
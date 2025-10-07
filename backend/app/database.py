import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# Теперь URL базы данных читается из переменной окружения.
# Если она не установлена, используется значение по умолчанию для работы с docker-compose.
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://chat_user:secret@db:5432/chat_db")

# Если используется SQLite, нужно добавить специальный аргумент для совместимости с потоками.
if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        DATABASE_URL, connect_args={"check_same_thread": False}
    )
else:
    engine = create_engine(DATABASE_URL)


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

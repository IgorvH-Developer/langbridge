import pytest
from fastapi.testclient import TestClient
import os

# Импортируем engine и Base ИЗ app.database, который теперь настроен через переменные окружения
from app.database import Base, get_db, engine, SessionLocal
from app.main import app

os.environ['TESTING'] = '1'

def override_get_db():
    """Подменяет зависимость get_db для использования тестовой БД."""
    db = SessionLocal() # SessionLocal уже настроен на тестовый engine
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

@pytest.fixture(scope="session", autouse=True)
def setup_test_database():
    """
    (autouse=True) Гарантирует, что эта фикстура запускается один раз за сессию
    ДО всех тестов. Она создает чистую базу данных.
    """
    # Файл test.db будет создан в корне контейнера, где запускается pytest
    if os.path.exists("./test.db"):
        os.remove("./test.db")
    # Используем импортированный engine, который теперь указывает на sqlite
    Base.metadata.create_all(bind=engine)
    yield
    if os.path.exists("./test.db"):
        os.remove("./test.db")

@pytest.fixture(scope="module")
def client():
    """
    Предоставляет экземпляр TestClient.
    """
    with TestClient(app) as c:
        yield c

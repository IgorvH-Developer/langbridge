import pytest
from fastapi.testclient import TestClient
import io

# Импортируем engine и override_get_db из test_main, чтобы использовать общую тестовую БД
from .test_main import app, override_get_db

# Импортируем сессию и модели напрямую для подготовки данных
from app.database import SessionLocal
from app.models import Language

# Используем тот же клиент, что и в других тестах
client = TestClient(app)

@pytest.fixture(scope="module", autouse=True)
def setup_and_seed_languages():
    """
    Фикстура, которая выполняется один раз для этого модуля.
    Она наполняет тестовую базу данных языками перед запуском тестов профиля.
    """
    db = SessionLocal()
    seed_languages(db)
    db.close()

def seed_languages(db_session):
    """Наполняет базу данных начальным списком языков, если их там нет."""
    if db_session.query(Language).count() == 0:
        languages_to_add = [
            Language(name='Russian', code='ru'),
            Language(name='English', code='en'),
            Language(name='Spanish', code='es'),
            Language(name='German', code='de'),
            Language(name='French', code='fr'),
            Language(name='Chinese', code='zh'),
        ]
        db_session.add_all(languages_to_add)
        db_session.commit()
        print("Languages have been seeded.")

def create_user_and_get_token(username, password):
    """Вспомогательная функция для создания пользователя и получения токена."""
    # Регистрация
    response = client.post("/api/users/register", json={"username": username, "password": password})
    assert response.status_code == 201
    user_id = response.json()["id"]

    # Логин
    token_response = client.post(
        "/api/users/token",
        data={"username": username, "password": password},
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    assert token_response.status_code == 200
    token = token_response.json()["access_token"]

    return user_id, f"Bearer {token}"

# --- Тесты для профиля и языков ---

def test_get_user_profile():
    """Тест: Получение профиля пользователя по ID."""
    user_id, token = create_user_and_get_token("profileuser", "pass123")

    response = client.get(f"/api/users/{user_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["username"] == "profileuser"
    assert data["id"] == user_id
    assert "languages" in data
    assert isinstance(data["languages"], list)

def test_update_user_profile():
    """Тест: Обновление текстовых полей профиля."""
    user_id, token = create_user_and_get_token("updateuser", "pass123")

    update_data = {
        "full_name": "Test User Name",
        "bio": "This is my test bio.",
        "country": "Testland",
        "age": 30
    }

    response = client.put(
        f"/api/users/{user_id}",
        json=update_data,
        headers={"Authorization": token}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["full_name"] == "Test User Name"
    assert data["bio"] == "This is my test bio."
    assert data["age"] == 30

    # Проверяем, что данные действительно сохранились, запросив профиль снова
    get_response = client.get(f"/api/users/{user_id}")
    assert get_response.status_code == 200
    get_data = get_response.json()
    assert get_data["full_name"] == "Test User Name"

def test_update_other_user_profile_fails():
    """Тест: Попытка обновить чужой профиль должна провалиться (403)."""
    user_one_id, token_one = create_user_and_get_token("userone", "pass1")
    user_two_id, _ = create_user_and_get_token("usertwo", "pass2")

    update_data = {"full_name": "Should Not Update"}

    response = client.put(
        f"/api/users/{user_two_id}",
        json=update_data,
        headers={"Authorization": token_one} # Используем токен первого юзера
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "Not allowed to update another user's profile"

def test_update_user_languages():
    """Тест: Успешное добавление/изменение языков пользователя."""
    user_id, token = create_user_and_get_token("languser", "pass123")

    # Получаем ID языков из БД для теста
    db = SessionLocal()
    ru_lang = db.query(Language).filter(Language.code == 'ru').first()
    en_lang = db.query(Language).filter(Language.code == 'en').first()
    es_lang = db.query(Language).filter(Language.code == 'es').first()
    db.close()

    assert ru_lang is not None
    assert en_lang is not None
    assert es_lang is not None

    # 1. Добавляем родной и один изучаемый
    languages_to_set = [
        {"language_id": ru_lang.id, "level": "Native", "type": "native"},
        {"language_id": en_lang.id, "level": "B2", "type": "learning"}
    ]

    response = client.put(
        f"/api/users/{user_id}/languages",
        json=languages_to_set,
        headers={"Authorization": token}
    )
    assert response.status_code == 204 # No Content

    # 2. Проверяем, что языки сохранились
    profile_response = client.get(f"/api/users/{user_id}")
    profile_data = profile_response.json()
    assert len(profile_data["languages"]) == 2

    native_langs = [lang for lang in profile_data["languages"] if lang["type"] == "native"]
    learning_langs = [lang for lang in profile_data["languages"] if lang["type"] == "learning"]

    assert len(native_langs) == 1
    assert native_langs[0]["name"] == "Russian"

    assert len(learning_langs) == 1
    assert learning_langs[0]["name"] == "English"
    assert learning_langs[0]["level"] == "B2"

    # 3. Полностью меняем набор языков (симуляция редактирования)
    languages_to_update = [
        {"language_id": en_lang.id, "level": "Native", "type": "native"},
        {"language_id": es_lang.id, "level": "A1", "type": "learning"}
    ]

    update_response = client.put(
        f"/api/users/{user_id}/languages",
        json=languages_to_update,
        headers={"Authorization": token}
    )
    assert update_response.status_code == 204

    # 4. Проверяем, что изменения применились
    updated_profile_response = client.get(f"/api/users/{user_id}")
    updated_profile_data = updated_profile_response.json()

    new_native_langs = [lang for lang in updated_profile_data["languages"] if lang["type"] == "native"]
    new_learning_langs = [lang for lang in updated_profile_data["languages"] if lang["type"] == "learning"]

    assert len(new_native_langs) == 1
    assert new_native_langs[0]["name"] == "English"

    assert len(new_learning_langs) == 1
    assert new_learning_langs[0]["name"] == "Spanish"
    assert new_learning_langs[0]["level"] == "A1"


# --- Тесты для поиска ---

def test_find_users_by_language():
    """Тест: Поиск пользователей по родному и изучаемому языкам."""
    # 1. Создаем пользователей с уникальными языками для этого теста
    # User C: native DE (German), learning FR (French)
    user_c_id, token_c = create_user_and_get_token("user_c_german", "pass")
    db = SessionLocal()
    # Используем языки, которые не задействованы в других тестах
    de_id = db.query(Language.id).filter(Language.code == 'de').scalar()
    fr_id = db.query(Language.id).filter(Language.code == 'fr').scalar()
    zh_id = db.query(Language.id).filter(Language.code == 'zh').scalar()
    db.close()

    assert de_id is not None
    assert fr_id is not None
    assert zh_id is not None

    client.put(f"/api/users/{user_c_id}/languages", json=[
        {"language_id": de_id, "type": "native", "level": "Native"},
        {"language_id": fr_id, "type": "learning", "level": "B1"}
    ], headers={"Authorization": token_c})

    # User D: native FR (French), learning ZH (Chinese)
    user_d_id, token_d = create_user_and_get_token("user_d_french", "pass")
    client.put(f"/api/users/{user_d_id}/languages", json=[
        {"language_id": fr_id, "type": "native", "level": "Native"},
        {"language_id": zh_id, "type": "learning", "level": "A1"}
    ], headers={"Authorization": token_d})

    # 2. Ищем носителей французского (FR), которые учат китайский (ZH) -> должен найти ТОЛЬКО User D
    response = client.get("/api/users/?native_lang_code=fr&learning_lang_code=zh")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["username"] == "user_d_french"

    # 3. Ищем носителей немецкого (DE) -> должен найти ТОЛЬКО User C
    response_de = client.get("/api/users/?native_lang_code=de")
    assert response_de.status_code == 200
    data_de = response_de.json()
    assert len(data_de) == 1
    assert data_de[0]["username"] == "user_c_german"

    # 4. Ищем тех, кто учит французский (FR) -> должен найти ТОЛЬКО User C
    response_fr_learn = client.get("/api/users/?learning_lang_code=fr")
    assert response_fr_learn.status_code == 200
    data_fr = response_fr_learn.json()
    assert len(data_fr) == 1
    assert data_fr[0]["username"] == "user_c_german"

# --- Тест для загрузки аватара ---
def test_upload_avatar():
    """Тест: Успешная загрузка файла аватара."""
    user_id, token = create_user_and_get_token("avataruser", "pass123")

    avatar_content = b"fake_image_bytes"

    response = client.post(
        f"/api/media/upload/avatar/{user_id}", # <<< ИЗМЕНЕН URL
        files={"file": ("avatar.jpg", io.BytesIO(avatar_content), "image/jpeg")},
        headers={"Authorization": token}
    )

    assert response.status_code == 200
    data = response.json()
    assert "avatar_url" in data
    assert data["avatar_url"].startswith("/uploads/avatar_")

    # Проверяем, что URL сохранился в профиле
    profile_response = client.get(f"/api/users/{user_id}")
    profile_data = profile_response.json()
    assert profile_data["avatar_url"] == data["avatar_url"]


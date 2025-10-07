# backend/tests/test_media.py
import os

import pytest
from unittest.mock import patch, MagicMock
import io
from tests.test_main import client

# Глобальные переменные для передачи данных между тестами
created_user_id = None
created_chat_id = None
created_message_id = None
auth_token = None

@pytest.fixture(scope="module", autouse=True)
def setup_for_media_tests(client): # Зависимость от фикстуры client
    """Создает пользователя и чат один раз для всех тестов в этом модуле."""
    global created_user_id, created_chat_id, auth_token
    # 1. Создаем пользователя
    user_response = client.post("/api/users/register", json={"username": "mediauser", "password": "mediapass"})
    assert user_response.status_code == 201
    created_user_id = user_response.json()["id"]

    # 2. Логинимся для получения токена
    token_response = client.post(
        "/api/users/token",
        data={"username": "mediauser", "password": "mediapass"},
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    assert token_response.status_code == 200
    auth_token = token_response.json()["access_token"]

    # 3. Создаем чат от имени этого пользователя
    chat_response = client.post("/api/chats/", json={"title": "Media Test Chat"}, headers={"Authorization": f"Bearer {auth_token}"})
    assert chat_response.status_code == 201
    created_chat_id = chat_response.json()["id"]

def test_upload_video(client):
    """Тест: Успешная загрузка видео (без транскрипции)."""
    global created_message_id
    video_content = b"fake video bytes"
    # Для теста создаем файл на диске, чтобы os.path.exists работал
    os.makedirs("/uploads", exist_ok=True)
    with open("/uploads/test_video.mp4", "wb") as f:
        f.write(video_content)

    response = client.post(
        f"/api/media/upload/video?chat_id={created_chat_id}&sender_id={created_user_id}",
        files={"file": ("test_video.mp4", io.BytesIO(video_content), "video/mp4")},
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["url"].startswith("/uploads/")
    created_message_id = data["message_id"]

@patch('app.routers.media.os.path.exists')
@patch('app.routers.media.stable_whisper.load_model')
@patch('app.routers.media.uuid.uuid4')
def test_transcribe_video_on_demand(mock_uuid4, mock_load_model, mock_os_path_exists, client):
    """
    Тест: Запрос транскрипции с использованием stable-whisper и проверкой кеширования.
    """
    assert created_message_id is not None, "Требуется ID сообщения из теста test_upload_video"

    # 1. Настраиваем моки
    mock_os_path_exists.return_value = True

    # Настройка мока для stable_whisper
    mock_model = MagicMock()
    mock_load_model.return_value = mock_model

    # Создаем мок-объекты для слов и сегментов
    mock_word1 = MagicMock()
    mock_word1.word = "Это"
    mock_word1.start = 0.1
    mock_word1.end = 0.5

    mock_word2 = MagicMock()
    mock_word2.word = "тест."
    mock_word2.start = 0.6
    mock_word2.end = 1.0

    mock_segment = MagicMock()
    mock_segment.words = [mock_word1, mock_word2]

    # Настройка результата транскрипции
    mock_transcribe_result = MagicMock()
    mock_transcribe_result.text = "Это тест."
    mock_transcribe_result.segments = [mock_segment]
    mock_model.transcribe.return_value = mock_transcribe_result

    # Настройка мока для uuid
    mock_uuid4.side_effect = ['uuid-word-1', 'uuid-word-2']

    # --- ПЕРВЫЙ ЗАПРОС: Транскрипция и сохранение в БД ---
    response = client.post(f"/api/media/transcribe/{created_message_id}", headers={"Authorization": f"Bearer {auth_token}"})

    # Проверяем успешный ответ
    assert response.status_code == 200

    # Проверяем структуру и данные ответа
    response_data = response.json()
    expected_data = {
        "full_text": "Это тест.",
        "words": [
            {"word": "Это", "start": 0.1, "end": 0.5, "id": "uuid-word-1"},
            {"word": "тест.", "start": 0.6, "end": 1.0, "id": "uuid-word-2"}
        ]
    }
    assert response_data == expected_data

    # Проверяем, что все "обманки" были вызваны ровно один раз
    mock_os_path_exists.assert_called_once()
    mock_load_model.assert_called_once()
    mock_model.transcribe.assert_called_once()
    assert mock_uuid4.call_count == 2

    # --- ВТОРОЙ ЗАПРОС: Результат должен браться из кеша (БД) ---
    response_again = client.post(f"/api/media/transcribe/{created_message_id}", headers={"Authorization": f"Bearer {auth_token}"})

    # Проверяем, что ответ все еще успешный и данные те же
    assert response_again.status_code == 200
    assert response_again.json() == expected_data

    # САМОЕ ГЛАВНОЕ: Проверяем, что "обманки" НЕ были вызваны снова.
    mock_os_path_exists.assert_called_once()
    mock_load_model.assert_called_once()
    mock_model.transcribe.assert_called_once()
    assert mock_uuid4.call_count == 2 # Количество вызовов не изменилось

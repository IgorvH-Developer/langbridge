# backend/tests/test_media.py

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
    response = client.post(
        f"/api/media/upload/video?chat_id={created_chat_id}&sender_id={created_user_id}",
        files={"file": ("test.mp4", io.BytesIO(video_content), "video/mp4")},
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["url"].startswith("/uploads/")
    created_message_id = data["message_id"]

# Патчим os.remove, т.к. временный .wav файл в тесте реально не создается
@patch('app.routers.media.os.remove')
@patch('speech_recognition.AudioFile')
@patch('speech_recognition.Recognizer.record')
@patch('speech_recognition.Recognizer.recognize_google')
@patch('pydub.AudioSegment.from_file')
def test_transcribe_video_on_demand(mock_from_file, mock_recognize_google, mock_record, mock_audio_file, mock_os_remove, client):
    """
    Тест: Запрос транскрипции с полной подменой всех зависимостей и проверкой кеширования.
    """
    assert created_message_id is not None, "Требуется ID сообщения из предыдущего теста"

    # 1. Настраиваем моки
    mock_audio_segment = MagicMock()
    mock_audio_segment.export.return_value = None # Мокаем метод export
    mock_from_file.return_value = mock_audio_segment

    mock_recognize_google.return_value = "Это распознанный текст."
    mock_audio_file.return_value.__enter__.return_value = MagicMock() # Для 'with' statement
    mock_record.return_value = MagicMock() # 'record' теперь тоже подменен

    # --- ПЕРВЫЙ ЗАПРОС: Транскрипция и сохранение в БД ---
    response = client.post(f"/api/media/transcribe/{created_message_id}", headers={"Authorization": f"Bearer {auth_token}"})

    # Проверяем успешный ответ и правильный текст
    assert response.status_code == 200
    assert response.json()["transcription"] == "Это распознанный текст."

    # Проверяем, что все "обманки" были вызваны ровно один раз
    mock_from_file.assert_called_once()
    mock_recognize_google.assert_called_once()
    mock_audio_file.assert_called_once()
    mock_record.assert_called_once()
    mock_os_remove.assert_called_once() # Проверяем, что была попытка удалить временный файл

    # --- ВТОРОЙ ЗАПРОС: Результат должен браться из кеша (БД) ---
    response_again = client.post(f"/api/media/transcribe/{created_message_id}", headers={"Authorization": f"Bearer {auth_token}"})

    # Проверяем, что ответ все еще успешный и текст тот же
    assert response_again.status_code == 200
    assert response_again.json()["transcription"] == "Это распознанный текст."

    # САМОЕ ГЛАВНОЕ: Проверяем, что "обманки" НЕ были вызваны снова.
    # Все они должны были быть вызваны только один раз в рамках первого запроса.
    mock_from_file.assert_called_once()
    mock_recognize_google.assert_called_once()
    mock_audio_file.assert_called_once()
    mock_record.assert_called_once()
    mock_os_remove.assert_called_once()

import pytest
from tests.test_main import client  # Импортируем наш настроенный клиент

def test_register_user(client):
    """Тест: Успешная регистрация нового пользователя."""
    response = client.post(
        "/api/users/register",
        json={"username": "testuser", "password": "testpassword"},
    )
    assert response.status_code == 201  # Ожидаем статус 201 Created
    data = response.json()
    assert data["username"] == "testuser"
    assert "id" in data

def test_register_existing_user(client):
    """Тест: Попытка регистрации пользователя с уже существующим именем."""
    client.post("/api/users/register", json={"username": "existinguser", "password": "password"})
    response = client.post(
        "/api/users/register",
        json={"username": "existinguser", "password": "anotherpassword"},
    )
    assert response.status_code == 400  # Ожидаем ошибку клиента
    assert response.json()["detail"] == "Username already registered"

def test_login_for_access_token(client):
    """Тест: Успешный логин и получение JWT токена."""
    client.post("/api/users/register", json={"username": "loginuser", "password": "loginpass"})
    response = client.post(
        "/api/users/token",
        data={"username": "loginuser", "password": "loginpass"},
        headers={"Content-Type": "application/x-www-form-urlencoded"} # Формат для OAuth2
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

def test_login_wrong_password(client):
    """Тест: Попытка логина с неверным паролем."""
    client.post("/api/users/register", json={"username": "wrongpassuser", "password": "correct"})
    response = client.post(
        "/api/users/token",
        data={"username": "wrongpassuser", "password": "incorrect"},
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    assert response.status_code == 401  # Ожидаем ошибку "Unauthorized"
    assert response.json()["detail"] == "Incorrect username or password"

PROJECT_NAME=chat-app
COMPOSE=docker-compose -p $(PROJECT_NAME)

.PHONY: up down restart logs build shell-db shell-backend

# Запустить все сервисы
up:
	$(COMPOSE) up -d

# Остановить и удалить контейнеры
down:
	$(COMPOSE) down

# Перезапустить сервисы
restart: down up

# Собрать образы заново
build:
	$(COMPOSE) build

# Логи всех сервисов
logs:
	$(COMPOSE) logs -f

# Зайти внутрь контейнера PostgreSQL
shell-db:
	$(COMPOSE) exec db psql -U chat_user -d chat_db

# Зайти внутрь контейнера backend
shell-backend:
	$(COMPOSE) exec backend bash

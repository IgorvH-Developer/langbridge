# backend/app/fcm_service.py
import os
from typing import List, Dict, Any, Optional
import firebase_admin
from firebase_admin import credentials, messaging
from firebase_admin.exceptions import FirebaseError

from .logger import logger

# Инициализация Firebase Admin SDK
SERVICE_ACCOUNT_KEY_PATH = os.path.join(os.path.dirname(__file__), 'service-account.json')

# ID проекта оставляем для логирования, но не для инициализации
PROJECT_ID = "langbridge-17ead"

if os.path.exists(SERVICE_ACCOUNT_KEY_PATH):
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        logger.info(f"Firebase Admin SDK initialized successfully.")
    except Exception as e:
        logger.error(f"Failed to initialize Firebase Admin SDK: {e}", exc_info=True)
else:
    logger.warning(f"Firebase service account key not found at {SERVICE_ACCOUNT_KEY_PATH}. Push notifications will be disabled.")

# Функция-обертка для отправки уведомлений
async def send_push_notification(
        fcm_tokens: List[str],
        notification_data: Dict[str, Any],
        message_data: Dict[str, Any]
):
    """
    Отправляет push-уведомление на указанные FCM токены через Firebase Admin SDK.
    """
    if not firebase_admin._apps:
        logger.error("Firebase Admin SDK is not initialized. Skipping push notification.")
        return

    valid_tokens = [token for token in fcm_tokens if token]
    if not valid_tokens:
        logger.warning("No valid FCM tokens provided to send_push_notification.")
        return

    notification = messaging.Notification(
        title=notification_data.get("title"),
        body=notification_data.get("body"),
        image=notification_data.get("image")
    )

    apns_config = messaging.APNSConfig(
        payload=messaging.APNSPayload(
            aps=messaging.Aps(
                sound="default",
                content_available=True,
            )
        )
    )

    message = messaging.MulticastMessage(
        tokens=valid_tokens,
        notification=notification,
        data=message_data,
        apns=apns_config
    )

    try:
        # Используем `send_each_for_multicast`.
        # Этот метод работает через новый HTTP v1 API и устойчив к проблемам с DNS.
        response = messaging.send_each_for_multicast(message)
        logger.info(f"Push notification sent via HTTP v1 API. Success: {response.success_count}, Failure: {response.failure_count}")

        if response.failure_count > 0:
            errors = []
            for i, resp in enumerate(response.responses):
                if not resp.success:
                    # Логируем ошибку для каждого неудачного токена
                    token_index = valid_tokens.index(message.tokens[i]) if message.tokens[i] in valid_tokens else -1
                    failed_token = valid_tokens[token_index] if token_index != -1 else "unknown"
                    errors.append(f"Token: {failed_token}, Error: {resp.exception}")
            logger.error(f"Failed to send to some tokens: {'; '.join(errors)}")

    except FirebaseError as e:
        # Ловим специфичные ошибки Firebase
        logger.error(f"A Firebase error occurred when sending push notification: {e}", exc_info=True)
    except Exception as e:
        # Ловим все остальные ошибки
        logger.error(f"An unexpected error occurred when sending push notification: {e}", exc_info=True)

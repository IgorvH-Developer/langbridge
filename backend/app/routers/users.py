from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi.security import OAuth2PasswordRequestForm, OAuth2PasswordBearer
from sqlalchemy.orm import Session, joinedload
from datetime import timedelta
from typing import List, Optional
from uuid import UUID as PyUUID

from .. import models, schemas, database, security
from ..logger import logger
from jose import JWTError, jwt

router = APIRouter(prefix="/api/users", tags=["Users"])

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/users/token")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(database.get_db)):
    # ... (эта функция остается без изменений, она нужна для авторизации)
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    logger.info(f"getting user by token: {token}")
    try:
        payload = jwt.decode(token, security.SECRET_KEY, algorithms=[security.ALGORITHM])
        username: str = payload.get("sub")
        logger.info(f"username : {username}")
        if username is None:
            logger.warning(f"username is none")
            raise credentials_exception
        token_data = schemas.TokenData(username=username)
        logger.info(f"token_data : {token_data}")
    except JWTError:
        logger.warning(f"got exception")
        raise credentials_exception
    user = db.query(models.User).filter(models.User.username == token_data.username).first()
    if user is None:
        logger.warning(f"failed to find user by username: {token_data.username}")
        raise credentials_exception
    return user


# --- Аутентификация и Регистрация (без изменений) ---

@router.post("/register", response_model=schemas.UserProfileResponse, status_code=status.HTTP_201_CREATED)
async def register_user(user_data: schemas.UserCreate, db: Session = Depends(database.get_db)):
    """Регистрирует нового пользователя."""
    logger.info(f"Attempting to register new user: '{user_data.username}'")
    db_user = db.query(models.User).filter(models.User.username == user_data.username).first()
    if db_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username already registered")

    hashed_password = security.get_password_hash(user_data.password)
    new_user = models.User(username=user_data.username, hashed_password=hashed_password)

    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    logger.info(f"User '{new_user.username}' registered with ID: {new_user.id}")
    # Важно: Возвращаем здесь полный профиль, чтобы клиент мог получить ID
    return await get_user_profile(str(new_user.id), db)


@router.post("/token", response_model=schemas.Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):
    logger.info(f"getting tocker: {form_data}, {db}")
    user = db.query(models.User).filter(models.User.username == form_data.username).first()
    if not user or not security.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
    # ВАЖНО: убедимся, что 'user_id' есть в токене. Это ключ к работе на клиенте.
    access_token = security.create_access_token(
        data={"sub": user.username, "user_id": str(user.id)},
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer", "user_id": str(user.id)} # Добавляем user_id в ответ


# --- Профиль пользователя ---

@router.get("/{user_id_str}", response_model=schemas.UserProfileResponse)
async def get_user_profile(user_id_str: str, db: Session = Depends(database.get_db)):
    """Возвращает публичный профиль любого пользователя по его ID."""
    # ... (без изменений)
    try:
        user_uuid = PyUUID(user_id_str)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user ID format")
    # ... остальная часть без изменений

    user = db.query(models.User).options(
        joinedload(models.User.languages)
    ).filter(models.User.id == user_uuid).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user_languages = []
    stmt = db.query(models.Language, models.user_languages.c.level, models.user_languages.c.type) \
        .join(models.user_languages) \
        .filter(models.user_languages.c.user_id == user.id)

    for lang_model, level, lang_type in stmt.all():
        user_languages.append(schemas.UserLanguageLink(
            id=lang_model.id,
            name=lang_model.name,
            code=lang_model.code,
            level=level,
            type=lang_type
        ))

    user_profile = schemas.UserProfileResponse.from_orm(user)
    user_profile.languages = user_languages

    return user_profile


# --- УДАЛЯЕМ ЭНДПОИНТЫ /me ---
# @router.get("/me", ...)
# async def read_users_me(...): ...

# --- ЗАМЕНЯЕМ ЭНДПОИНТЫ /me на эндпоинты с {user_id} ---

@router.put("/{user_id_str}", response_model=schemas.UserProfileResponse)
async def update_user_profile(
        user_id_str: str,
        user_update: schemas.UserUpdate,
        current_user: models.User = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    """Обновляет профиль пользователя. Пользователь может обновлять только свой профиль."""
    if str(current_user.id) != user_id_str:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed to update another user's profile")

    # `current_user` - это уже объект пользователя, который мы хотим обновить
    update_data = user_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(current_user, key, value)

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    logger.info(f"User profile for '{current_user.username}' updated.")

    return await get_user_profile(str(current_user.id), db)


@router.put("/{user_id_str}/languages", status_code=status.HTTP_204_NO_CONTENT)
async def update_user_languages(
        user_id_str: str,
        languages_update: List[schemas.LanguageUpdate],
        current_user: models.User = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    """Полностью заменяет список языков пользователя. Пользователь может обновлять только свои языки."""
    if str(current_user.id) != user_id_str:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed to update another user's languages")

    # 1. Удаляем все текущие языковые связи для этого пользователя
    db.query(models.user_languages).filter(models.user_languages.c.user_id == current_user.id).delete()

    # 2. Добавляем новые
    for lang_data in languages_update:
        lang_exists = db.query(models.Language).filter(models.Language.id == lang_data.language_id).first()
        if not lang_exists:
            continue

        new_link = models.user_languages.insert().values(
            user_id=current_user.id,
            language_id=lang_data.language_id,
            level=lang_data.level,
            type=lang_data.type
        )
        db.execute(new_link)

    db.commit()
    return

# --- ПОИСК ПОЛЬЗОВАТЕЛЕЙ ---

# КРИТЕРИЙ 2: Пользователей можно фильтровать по языкам
@router.get("/", response_model=List[schemas.UserInListResponse])
async def find_users(
        native_lang_code: Optional[str] = Query(None, description="Код родного языка для поиска (e.g., 'en')"),
        learning_lang_code: Optional[str] = Query(None, description="Код изучаемого языка для поиска (e.g., 'ru')"),
        db: Session = Depends(database.get_db)
):
    """Ищет пользователей по родному и/или изучаемому языку."""
    query = db.query(models.User).options(joinedload(models.User.languages))

    if native_lang_code:
        query = query.join(models.user_languages).join(models.Language).filter(
            models.Language.code == native_lang_code,
            models.user_languages.c.type == 'native'
        )

    if learning_lang_code:
        query = query.join(models.user_languages).join(models.Language).filter(
            models.Language.code == learning_lang_code,
            models.user_languages.c.type == 'learning'
        )

    users = query.distinct().limit(100).all() # distinct() чтобы избежать дублей из-за join'ов

    # Собираем ответ. Это не очень эффективно, N+1 запрос. В идеале нужна оптимизация.
    # Но для начала сойдет.
    result = []
    for user in users:
        profile = await get_user_profile(str(user.id), db) # Получаем полные данные для каждого
        user_in_list = schemas.UserInListResponse(
            id=profile.id,
            username=profile.username,
            avatar_url=profile.avatar_url,
            country=profile.country,
            languages=profile.languages
        )
        result.append(user_in_list)

    return result

# --- ВАЖНО: Добавим эндпоинт для получения списка всех языков ---
@router.get("/languages/all", response_model=List[schemas.LanguageInDB])
async def get_all_languages(db: Session = Depends(database.get_db)):
    """Возвращает список всех доступных в системе языков."""
    return db.query(models.Language).all()

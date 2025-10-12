from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi.security import OAuth2PasswordRequestForm, OAuth2PasswordBearer
from sqlalchemy.orm import Session, joinedload, aliased
from datetime import timedelta
from typing import List, Optional
from uuid import UUID as PyUUID

from .. import models, schemas, database, security
from ..logger import logger
from jose import JWTError, jwt

router = APIRouter(prefix="/api/users", tags=["Users"])

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/users/token")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(database.get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, security.SECRET_KEY, algorithms=[security.ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = schemas.TokenData(username=username)
    except JWTError:
        raise credentials_exception
    user = db.query(models.User).filter(models.User.username == token_data.username).first()
    if user is None:
        raise credentials_exception
    return user

# --- Аутентификация и Регистрация (не меняются) ---
@router.post("/register", response_model=schemas.UserProfileResponse, status_code=status.HTTP_201_CREATED)
async def register_user(user_data: schemas.UserCreate, db: Session = Depends(database.get_db)):
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
    return schemas.UserProfileResponse.model_validate(new_user)

@router.post("/token", response_model=schemas.Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):
    # ... (код этой функции не меняется)
    user = db.query(models.User).filter(models.User.username == form_data.username).first()
    if not user or not security.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect username or password", headers={"WWW-Authenticate": "Bearer"})
    access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = security.create_access_token(data={"sub": user.username, "user_id": str(user.id)}, expires_delta=access_token_expires)
    return {"access_token": access_token, "token_type": "bearer", "user_id": str(user.id)}

# --- Профиль пользователя ---

@router.get("/{user_id_str}", response_model=schemas.UserProfileResponse)
async def get_user_profile(user_id_str: str, db: Session = Depends(database.get_db)):
    try:
        user_uuid = PyUUID(user_id_str)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user ID format")

    user = db.query(models.User).options(
        joinedload(models.User.language_associations).joinedload(models.UserLanguageAssociation.language)
    ).filter(models.User.id == user_uuid).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Валидируем базовый профиль
    user_profile = schemas.UserProfileResponse.model_validate(user)

    # Правильно собираем языки через Association Object
    languages_data = []
    for assoc in user.language_associations:
        languages_data.append(schemas.UserLanguageLink(
            id=assoc.language.id,
            name=assoc.language.name,
            code=assoc.language.code,
            level=assoc.level,
            type=assoc.type
        ))
    user_profile.languages = languages_data
    return user_profile


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

    update_data = user_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(current_user, key, value)

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    logger.info(f"User profile for '{current_user.username}' updated.")

    return current_user


@router.put("/{user_id_str}/languages", status_code=status.HTTP_204_NO_CONTENT)
async def update_user_languages(
        user_id_str: str,
        languages_update: List[schemas.LanguageUpdate],
        current_user: models.User = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    if str(current_user.id) != user_id_str:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed")

    try:
        current_user.language_associations.clear()
        db.flush()

        for lang_data in languages_update:
            assoc = models.UserLanguageAssociation(
                language_id=lang_data.language_id,
                level=lang_data.level,
                type=lang_data.type
            )
            current_user.language_associations.append(assoc)

        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"Could not update languages for user {current_user.id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Could not update languages.")

    return


# --- ПОИСК ПОЛЬЗОВАТЕЛЕЙ ---
@router.get("/", response_model=List[schemas.UserInListResponse])
async def find_users(
        native_lang_code: Optional[str] = Query(None, description="Native language code (e.g., 'en')"),
        learning_lang_code: Optional[str] = Query(None, description="Learning language code (e.g., 'ru')"),
        db: Session = Depends(database.get_db)
):
    query = db.query(models.User).options(
        joinedload(models.User.language_associations).joinedload(models.UserLanguageAssociation.language)
    )

    if native_lang_code:
        native_assoc_alias = aliased(models.UserLanguageAssociation)
        native_lang_alias = aliased(models.Language)
        query = query.join(native_assoc_alias, models.User.language_associations)
        query = query.join(native_lang_alias, native_assoc_alias.language)
        query = query.filter(
            native_lang_alias.code == native_lang_code,
            native_assoc_alias.type == 'native'
        )

    if learning_lang_code:
        learning_assoc_alias = aliased(models.UserLanguageAssociation)
        learning_lang_alias = aliased(models.Language)
        query = query.join(learning_assoc_alias, models.User.language_associations)
        query = query.join(learning_lang_alias, learning_assoc_alias.language)
        query = query.filter(
            learning_lang_alias.code == learning_lang_code,
            learning_assoc_alias.type == 'learning'
        )

    users = query.distinct().limit(100).all()

    return users

# --- Get all languages ---
@router.get("/languages/all", response_model=List[schemas.LanguageInDB])
async def get_all_languages(db: Session = Depends(database.get_db)):
    return db.query(models.Language).order_by(models.Language.name).all()


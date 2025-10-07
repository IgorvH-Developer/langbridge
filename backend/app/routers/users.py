from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm, OAuth2PasswordBearer
from sqlalchemy.orm import Session
from datetime import timedelta

from .. import models, schemas, database, security
from ..logger import logger
from jose import JWTError, jwt

router = APIRouter(prefix="/api/users", tags=["Users"])

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/users/token")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(database.get_db)):
    """Декодирует JWT токен и возвращает объект пользователя из БД."""
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

# --- Аутентификация и Регистрация ---

@router.post("/register", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
async def register_user(user_data: schemas.UserCreate, db: Session = Depends(database.get_db)):
    """Регистрирует нового пользователя."""
    logger.debug(f"Attempting to register new user: '{user_data.username}'")
    db_user = db.query(models.User).filter(models.User.username == user_data.username).first()
    if db_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username already registered")

    hashed_password = security.get_password_hash(user_data.password)
    new_user = models.User(username=user_data.username, hashed_password=hashed_password)

    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    logger.info(f"User '{new_user.username}' registered with ID: {new_user.id}")
    return new_user

@router.post("/token", response_model=schemas.Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):
    """Предоставляет JWT токен при успешном входе."""
    logger.debug(f"getting tocker: {form_data}, {db}")
    user = db.query(models.User).filter(models.User.username == form_data.username).first()
    if not user or not security.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = security.create_access_token(
        data={"sub": user.username, "user_id": str(user.id)}, # Добавим user_id в токен
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

# --- Профиль пользователя ---

@router.get("/me", response_model=schemas.UserResponse)
async def read_users_me(current_user: models.User = Depends(get_current_user)):
    logger.debug(f"getting user me: {current_user}")
    """Возвращает профиль текущего аутентифицированного пользователя."""
    return current_user

@router.put("/me", response_model=schemas.UserResponse)
async def update_user_me(
        user_update: schemas.UserUpdate,
        current_user: models.User = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    logger.debug(f"updating user me: {user_update}, {current_user}, {db}")
    """Обновляет профиль текущего пользователя."""
    update_data = user_update.model_dump(exclude_unset=True) # Используем model_dump
    for key, value in update_data.items():
        setattr(current_user, key, value)

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    logger.info(f"User profile for '{current_user.username}' updated.")
    return current_user
from fastapi import APIRouter, WebSocket

router = APIRouter(prefix="/api")

@router.get("/hello")
async def hello():
    return {"message": "Hello from FastAPI"}

@router.websocket("/ws/{chat_id}")
async def websocket_endpoint(websocket: WebSocket, chat_id: str):
    await websocket.accept()
    await websocket.send_text(f"Connected to chat {chat_id}")
    while True:
        data = await websocket.receive_text()
        await websocket.send_text(f"You said: {data}")

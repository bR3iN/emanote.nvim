from os import environ, kill, getpid
from signal import SIGINT
from typing import Set
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse

STATIC_HTML = """
<!DOCTYPE html>
<html>
<head>
    <style>
        body, html {
            margin: 0;
            padding: 0;
            height: 100%;
            overflow: hidden;
        }
        #siteFrame {
            height: 100%;
            width: 100%;
            border: none;
        }
    </style>
</head>
<body>
    <iframe id="siteFrame"></iframe>

    <script>
        var host = location.host;
        var ws = new WebSocket("ws://" + host + "/ws");
        var siteFrame = document.getElementById('siteFrame');

        ws.onmessage = function(event) {
            siteFrame.src = event.data;
            siteFrame.contentWindow.focus();
        };
    </script>
</body>
</html>
"""


INITIAL_SITE = environ['INITIAL_SITE']

app = FastAPI()
connections: Set[WebSocket] = set()


@app.get('/')
async def _():
    return HTMLResponse(content=STATIC_HTML)


@app.websocket('/ws')
async def _(websocket: WebSocket):
    connections.add(websocket)
    await websocket.accept()
    print(len(connections))
    try:
        await websocket.send_text(INITIAL_SITE)
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        connections.remove(websocket)


@app.post('/set-url')
async def _(request: Request):
    url = (await request.body()).decode()
    for ws in connections:
        await ws.send_text(url)


@app.post('/shutdown')
async def _(_: Request):
    kill(getpid(), SIGINT)

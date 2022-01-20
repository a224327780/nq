import os
from pathlib import Path

from sanic import Sanic, text, json

app = Sanic("nq")


def add_cors_headers(request, response):
    headers = {
        "Access-Control-Allow-Methods": "PUT, GET, POST, DELETE, OPTIONS",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": 'Origin, Accept, Content-Type, X-Requested-With, X-CSRF-Token',
    }
    response.headers.extend(headers)


app.register_middleware(add_cors_headers, "response")


@app.get("/install")
async def install(request):
    content_type = 'application/x-shellscript'
    content = Path('scripts/install.sh').read_text()
    return text(content, content_type=content_type)


@app.get("/uninstall")
async def uninstall(request):
    content_type = 'application/x-shellscript'
    content = Path('scripts/uninstall.sh').read_text()
    return text(content, content_type=content_type)


@app.websocket("/")
async def ws_data(request, ws):
    while True:
        data = "hello!"
        print("Sending: " + data)
        await ws.send(data)
        data = await ws.recv()
        print("Received: " + data)


@app.get('/')
async def home(request):
    return text('')


@app.get('/e')
async def envs(request):
    return json(dict(os.environ.items()))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=os.getenv('PORT', 8080), debug=False, access_log=False)

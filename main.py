import os
from pathlib import Path

from sanic import Sanic, text, json, Request

from _version import VERSION

app = Sanic("nq")
app.static("/nq-agent", "client")


def add_cors_headers(request, response):
    headers = {
        "Access-Control-Allow-Methods": "PUT, GET, POST, DELETE, OPTIONS",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": 'Origin, Accept, Content-Type, X-Requested-With, X-CSRF-Token',
    }
    response.headers.extend(headers)


app.register_middleware(add_cors_headers, "response")


@app.get("/install")
async def install(request: Request):
    content_type = 'application/x-shellscript'
    host = request.url_for('home').strip('/')
    params = f'version="{VERSION}"\nhost="{host}"'
    content = Path('scripts/install.sh').read_text().replace('# params', params)
    return text(f"{content}\n", content_type=content_type)


@app.get("/uninstall")
async def uninstall(request):
    content_type = 'application/x-shellscript'
    content = Path('scripts/uninstall.sh').read_text()
    return text(content, content_type=content_type)


@app.websocket("/ws")
async def ws_data(request, ws):
    while True:
        data = "hello!"
        print("Sending: " + data)
        await ws.send(data)
        data = await ws.recv()
        print("Received: " + data)


@app.get('/')
async def home(request: Request):
    content = f"curl {request.url_for('install')} | sudo bash"
    return text(content)


@app.get('/check')
async def check_update(request: Request):
    return json({'code': 0, 'data': False})


@app.get('/e')
async def envs(request):
    print(request.url_for('home'))
    return json(dict(os.environ.copy()))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=os.getenv('PORT', 8080), debug=False, access_log=False, auto_reload=True)

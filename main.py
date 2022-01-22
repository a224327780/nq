import asyncio
import hashlib
import json
import os
from pathlib import Path

from sanic import Sanic, text, Request
from sanic import json as json_
from sanic.log import logger

from utils.log import DEFAULT_LOGGING
from utils.version import VERSION

app = Sanic("nq", log_config=DEFAULT_LOGGING)
app.static("/nq-agent", "client")

NQ_SERVER_PORT = os.getenv('NQ_SERVER_PORT', 15555)


async def handle_client(reader, writer):
    client_id = writer.get_extra_info('peername')
    logger.info('Client connected: {}'.format(client_id))
    while True:
        request = (await reader.read(1024)).decode('utf8')
        if not request or request == 'quit':
            break
        logger.info(request)
        writer.write('we'.encode('utf-8'))
        await writer.drain()
    logger.info('close')
    writer.close()


async def start_socket_server():
    host = '127.0.0.1'
    server = await asyncio.start_server(handle_client, host, NQ_SERVER_PORT)
    logger.info(host)
    async with server:
        await server.serve_forever()


app.add_task(start_socket_server())


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
    server = request.server_name
    host = request.url_for('home').split('/')
    params = f'version="{VERSION}"\nserver="{server}"\nport="{NQ_SERVER_PORT}"\nhost="{host}"'
    content = Path('utils/get-install.sh').read_text()
    content = content.replace('#env', params)
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


@app.post('/add')
async def add_host(request: Request):
    name = request.form.get('name')
    m = hashlib.md5()
    m.update(name.encode('utf-8'))
    _id = m.hexdigest().upper()
    host = {'name': name, 'id': _id}
    host_file = Path('hosts') / f'{_id}.host'
    host_file.write_text(json.dumps(host))

    content = f"curl {request.url_for('install')} | sh -s {_id}"
    return text(content)


@app.get('/version')
async def version(request: Request):
    return text(VERSION)


@app.get('/e')
async def envs(request):
    return json_(dict(os.environ.copy()))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=os.getenv('PORT', 8080), debug=True, access_log=True, auto_reload=True)

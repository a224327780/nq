import hashlib
import json
import os
from datetime import datetime, timedelta
from pathlib import Path

from motor.motor_asyncio import AsyncIOMotorClient
from sanic import Sanic, text, Request
from sanic import json as json_
from sanic.log import logger

from utils.common import get_bj_time, progress, is_online, m_date
from utils.log import DEFAULT_LOGGING
from utils.version import VERSION

app = Sanic("nq", log_config=DEFAULT_LOGGING)
mongo_uri = os.getenv('MONGO_URI')
col_host_name = 'host'
col_hosts_name = 'hosts'


@app.middleware('response')
def add_cors_headers(request, response):
    headers = {
        "Access-Control-Allow-Methods": "PUT, GET, POST, DELETE, OPTIONS",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Credentials": "true",
        "Access-Control-Allow-Headers": (
            "origin, content-type, accept, "
            "authorization, x-xsrf-token, x-request-id"
        ),
    }
    response.headers.extend(headers)


@app.before_server_start
async def setup_db(_app, loop):
    _app.ctx.mongo_client = AsyncIOMotorClient(mongo_uri)
    _app.ctx.mongo_db = _app.ctx.mongo_client['db0']


async def get_hosts():
    db = app.ctx.mongo_db
    col = db[col_hosts_name]
    col_item = db[col_host_name]
    data = []
    async for item in col.find():
        _id = item['_id']
        host_item = await col_item.find_one({'token': _id}, sort=[('create_date', -1)])
        if not host_item:
            continue

        host_item['ram_gap'] = progress(host_item['ram_usage'], host_item['ram_total'])
        host_item['disk_gap'] = progress(host_item['disk_usage'], host_item['disk_total'])
        host_item['load_gap'] = progress(host_item['load'].split(' ')[0], host_item['cpu_cores'])
        host_item['is_online'] = is_online(host_item['create_date'])
        host_item['m_date'] = m_date(host_item['create_date'])
        data.append(item)
    return {'code': 0, 'data': data, 'message': ''}


@app.get("/install")
async def install(request: Request):
    content_type = 'application/x-shellscript'
    api = request.url_for('agent').replace('http', 'https')
    content = Path('scripts/install.sh').read_text().replace('API="$2"', f'API="{api}"')
    headers = {'accept-ranges': 'bytes'}
    return text(f'{content}\n', content_type=content_type, headers=headers)


@app.get("/uninstall")
async def uninstall(request):
    content_type = 'application/x-shellscript'
    headers = {'accept-ranges': 'bytes'}
    content = Path('scripts/uninstall.sh').read_text()
    return text(content, content_type=content_type, headers=headers)


@app.websocket("/ws")
async def ws_data(request, ws):
    while True:
        data = await get_hosts()
        await ws.send(json.dumps(data))


@app.get('/')
async def home(request: Request):
    return text(request.scheme)


@app.post('/add')
async def add_host(request: Request):
    name = request.form.get('name')
    m = hashlib.md5()
    m.update(name.encode('utf-8'))
    _id = m.hexdigest().upper()

    db = app.ctx.mongo_db
    col = db[col_hosts_name]
    data = await col.find_one({'_id': _id})
    if data:
        return json_({'code': 1, 'message': f'{name} Already exists.', data: []})

    host = {'name': name, '_id': _id}
    await col.insert_one(host)

    url = request.url_for('install').replace('http', 'https')
    content = f"curl {url} | bash -s {_id}"
    return json_({'code': 0, 'message': '', 'data': content})


@app.get('/hosts')
async def hosts(request):
    data = await get_hosts()
    return json_(data)


@app.post('/agent')
async def agent(request: Request):
    db = app.ctx.mongo_db
    col = db[col_host_name]
    col_hosts = db[col_hosts_name]

    data = request.form.get('data')
    token = request.form.get('token')

    host = await col_hosts.find_one({'_id': token})
    if not host:
        return json_({'code': 1, 'data': [], 'message': f'hostId: {token} Not Found.'})

    day_1_ago = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S")
    await col.delete_many({'token': token, 'create_date': {'$lt': f'{day_1_ago}'}})

    field_map = {
        0: 'version', 1: 'uptime', 2: 'sessions', 3: 'processes',
        4: 'processes_array', 5: 'os_kernel', 6: 'os_name', 7: 'os_arch',
        8: 'cpu_name', 9: 'cpu_cores', 10: 'cpu_freq',
        11: 'ram_total', 12: 'ram_usage', 13: 'swap_total', 14: 'swap_usage',
        15: 'disk_total', 16: 'disk_usage', 17: 'connections', 18: 'nic',
        19: 'ipv4', 20: 'ipv6', 21: 'rx', 22: 'tx', 23: 'load'}
    save_data = {'create_date': get_bj_time(), 'token': token}
    try:
        for i, datum in enumerate(data.split('|')):
            field = field_map.get(i)
            if field:
                save_data[field] = datum
        await col.insert_one(save_data)
    except Exception as e:
        logger.exception(e)
        return json_({'code': 1, 'data': [], 'message': str(e)})

    return json_({'code': 0, 'data': [], 'message': ''})


@app.get('/version')
async def version(request: Request):
    return text(VERSION)


@app.get('/e')
async def envs(request):
    return json_(dict(os.environ.copy()))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=os.getenv('PORT', 8080), debug=True, access_log=True, auto_reload=True)

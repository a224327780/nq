import base64
import math
from datetime import datetime, timezone, timedelta


def get_bj_time():
    utc_dt = datetime.utcnow().replace(tzinfo=timezone.utc)
    return utc_dt.astimezone(timezone(timedelta(hours=8))).strftime('%Y-%m-%d %H:%M:%S')


def decode(s: str):
    s = s.strip()
    padding = len(s) % 4
    if padding == 1:
        return ''

    if padding == 2:
        s += '=='
    elif padding == 3:
        s += '='
    return str(base64.b64decode(s), 'utf-8')


def is_online(last_date):
    return diff_date_seconds(last_date) < 200


def diff_date_seconds(last_date):
    a = datetime.strptime(last_date, '%Y-%m-%d %H:%M:%S')
    b = datetime.now()
    return (b - a).seconds


def m_date(last_date):
    s = diff_date_seconds(last_date)
    date_name = ['seconds ago', 'minutes ago', 'hours ago']
    i = int(math.floor(math.log(s, 60)))
    if i > len(date_name):
        return last_date

    p = math.pow(60, i)
    return f'{int(s / p)} {date_name[i]}'


def progress(a, b, c=100):
    n = round((float(a) / float(b)) * c, 2)
    return 100 if n > 100 else n

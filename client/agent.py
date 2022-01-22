import os
import sched
import socket
import time
from threading import Thread

s = sched.scheduler(time.time)
try:
    from agent_env import host, server, port, version, token
except Exception as e:
    raise e


def check_update():
    url = f'{host}/version'
    data = os.popen(f'curl -s {url}').read()
    print(data)
    s.enter(86400, 1, check_update, ())


class SendAgent:
    def __init__(self):
        self.client = None
        self.init()

    def init(self):
        self.client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.client.connect((server, port))

    def send(self, data):
        if not self.client or not hasattr(self.client, 'send'):
            self.init()
        self.client.send(data.encode('utf-8'))

    def close(self):
        try:
            self.client.close()
        finally:
            self.client = None


agent = SendAgent()


def send_agent():
    try:
        cmd = 'bash /etc/nodequery/agent.sh'
        b = os.popen(cmd).readlines()
        print(b)
        data = ''
        agent.send(data)
    except Exception as e1:
        print(e1)
    finally:
        s.enter(10, 0, send_agent, ())


def start():
    s.enter(86400, 1, check_update, ())
    s.enter(0, 0, send_agent, ())
    s.run()


def run():
    t = Thread(target=start, name='client')
    t.daemon = True
    t.start()
    t.join()


if __name__ == "__main__":
    run()

import os
import sched
import time
from threading import Thread

s = sched.scheduler(time.time)


def check_update():
    with open('/etc/nodequery/host.txt') as f:
        host = float(f.read())
    s.enter(86400, 1, check_update, ())


def send_agent():
    cmd = 'bash /etc/nodequery/agent.sh'
    b = os.popen(cmd).readlines()
    print(b)
    s.enter(10, 0, send_agent, ())


def start():
    s.enter(0, 1, check_update, ())
    s.enter(0, 0, send_agent, ())
    s.run()


def run():
    t = Thread(target=start, name='client')
    t.daemon = True
    t.start()
    t.join()


if __name__ == "__main__":
    run()

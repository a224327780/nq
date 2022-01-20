import os, sys

cmd = 'bash nq.sh'

b = os.popen(cmd).readlines()
print(b)
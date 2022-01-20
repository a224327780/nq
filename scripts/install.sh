#!/bin/bash

# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Prepare output
echo -e "|\n|   NodeQuery Installer\n|   ===================\n|"

# Root required
if [ $(id -u) != "0" ];
then
	echo -e "|   Error: You need to be root to install the NodeQuery agent\n|"
	echo -e "|          The agent itself will NOT be running as root but instead under its own non-privileged user\n|"
	exit 1
fi

host=$1

# Attempt to delete previous agent
if [ -f /etc/nodequery/agent.sh ]
then
	# Remove agent dir
	rm -Rf /etc/nodequery
fi

# Create agent dir
mkdir -p /etc/nodequery

# Download agent
echo -e "|   Downloading agent.sh to /etc/nodequery\n|\n|   + $(wget -nv -o /dev/stdout -O /etc/nodequery/nq-agent.sh --no-check-certificate ${host}/client/agent.sh)"

wget -nv -o /dev/stdout -O /etc/nodequery/main.py --no-check-certificate ${host}/client/main.py

wget -nv -o /dev/stdout -O /etc/systemd/system/nq-agent.service --no-check-certificate ${host}/client/agent.service

wget -nv -o /dev/stdout -O /etc/init.d/nq-agent --no-check-certificate ${host}/client/init.d.agent

if [ -f /etc/nodequery/nq-agent.sh ]
then
	chmod +x /etc/init.d/nq-agent
	systemctl daemon-reload
  systemctl start nq-agent
  systemctl enable nq-agent

	# Show success
	echo -e "|\n|   Success: The NodeQuery agent has been installed\n|"

else
	# Show error
	echo -e "|\n|   Error: The NodeQuery agent could not be installed\n|"
fi
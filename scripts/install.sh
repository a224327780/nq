#!/bin/bash

# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# params

# Prepare output
echo -e "|\n|   NodeQuery Installer\n|   ===================\n|"

# Root required
if [ $(id -u) != "0" ];
then
	echo -e "|   Error: You need to be root to install the NodeQuery agent\n|"
	echo -e "|          The agent itself will NOT be running as root but instead under its own non-privileged user\n|"
	exit 1
fi

# Attempt to delete previous agent
if [ -f /etc/nodequery/nq-agent.sh ]
then
	# Remove agent dir
	if [ -f /etc/systemd/system/nq-agent.service ]; then
	  systemctl stop nq-agent.service
    systemctl disable nq-agent.service
	fi

  rm -rf /etc/nodequery
  rm -f /etc/init.d/nq-agent
  rm -f /etc/systemd/system/nq-agent.service
fi

# Create agent dir
mkdir -p /etc/nodequery

# Download agent
echo -e "|   Downloading agent.sh to /etc/nodequery"

wget -nv -O /etc/nodequery/nq-agent.sh --no-check-certificate ${host}/nq-agent/agent.sh

wget -nv -O /etc/nodequery/main.py --no-check-certificate ${host}/nq-agent/main.py

wget -nv -O /etc/systemd/system/nq-agent.service --no-check-certificate ${host}/nq-agent/agent.service

wget -nv -O /etc/init.d/nq-agent --no-check-certificate ${host}/nq-agent/init.d.agent

echo $version > /etc/nodequery/version.txt
echo $host > /etc/nodequery/host.txt

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
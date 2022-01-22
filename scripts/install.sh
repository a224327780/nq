#!/usr/bin/env sh

# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Attempt to delete previous agent
if [ -f /etc/nodequery/nq-agent.sh ]
then
	if [ -f /etc/systemd/system/nq-agent.service ]; then
	  systemctl stop nq-agent.service
    systemctl disable nq-agent.service
	fi

  rm -rf /etc/nodequery
  rm -f /etc/init.d/nq-agent
  rm -f /etc/systemd/system/nq-agent.service
fi

mkdir -p /etc/nodequery

echo -e "|   Downloading agent.sh to /etc/nodequery"
host="https://raw.githubusercontent.com/a224327780/nq/client"

curl -k -s -o /etc/nodequery/nq-agent.sh ${host}/agent.sh
curl -k -s -o /etc/nodequery/agent.py ${host}/agent.py
curl -k -s -o /etc/systemd/system/nq-agent.service ${host}agent.service
curl -k -s -o /etc/init.d/nq-agent ${host}/init.d.agent

echo -e "version = '$1'\nserver = '$2'\nport = '$3'\nhost = '$4'\ntoken = '$5'" > /etc/nodequery/agent_env.py

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
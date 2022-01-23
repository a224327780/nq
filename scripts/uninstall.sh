#!/bin/bash
kill -9 `ps -ef| grep -i 'nq-agent' | grep -v grep| awk '{print $2}'` && rm -R /etc/nodequery && (crontab -u nodequery -l | grep -v "/etc/nodequery/nq-agent.sh") | crontab -u nodequery - && userdel nodequery

echo -e "Uninstall completed."

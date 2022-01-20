#!/bin/bash

systemctl stop nq-agent.service
systemctl disable nq-agent.service

rm -f /etc/init.d/nq-agent
rm -rf /etc/nodequery
rm -rf /etc/systemd/system/nq-agent.service

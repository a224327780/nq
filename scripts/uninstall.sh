#!/bin/bash

systemctl stop nq-agent.service
systemctl disable nq-agent.service

rm -rf /etc/nodequery
rm -f /etc/init.d/nq-agent
rm -f /etc/systemd/system/nq-agent.service

#!/bin/bash

# This script is used to uninstall the network monitor
# Start by removing the service
sudo systemctl stop egpaf.monitor.service
sudo systemctl disable egpaf.monitor.service
sudo rm /etc/systemd/system/egpaf.monitor.service
sudo systemctl daemon-reload

# Remove the monitor directory
sudo rm -rf /opt/egpaf

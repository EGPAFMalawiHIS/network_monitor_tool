#!/bin/bash
# warn the user about uninstalling the service
echo "This will uninstall the service, transactions log and delete the environment file"
read -p "Do you want to continue? (y/n): " uninstall

if [ "$uninstall" == "y" ]; then
    echo "Uninstalling service"
    # disable the service
    echo "Disabling service"
    sudo systemctl stop egpaf.monitor.service
    sudo systemctl disable egpaf.monitor.service
    # remove the service
    echo "Removing service"
    sudo rm /etc/systemd/system/egpaf.monitor.service
    # remove the monitor script
    echo "Removing monitor script"
    sudo rm /opt/egpaf/monitor/monitor.sh
    # remove the environment file
    echo "Removing environment file"
    sudo rm /opt/egpaf/monitor/.env
    # remove the log directory
    echo "Removing log directory"
    sudo rm -rf /opt/egpaf/monitor/log
    # remove the monitor directory
    echo "Removing monitor directory"
    sudo rm -rf /opt/egpaf/monitor
    echo "Service uninstalled successfully"
else
    echo "Leaving service intact"
fi

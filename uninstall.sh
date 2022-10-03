#!/bin/bash
# warn the user about uninstalling the service

function uninstallService {
    # check if the service exists
    if [ -f /etc/systemd/system/egpaf-monitor.service ]; then
        # stop the service
        sudo systemctl stop egpaf-monitor.service
        # disable the service
        sudo systemctl disable egpaf-monitor.service
        # remove the service
        sudo rm /etc/systemd/system/egpaf-monitor.service
        # reload the daemon
        sudo systemctl daemon-reload
        # restart the service
        sudo systemctl restart egpaf-monitor.service
        echo "Service removed successfully"
    else
        echo "Service does not exist"
    fi
}

function uninstallEnv {
    # check if the environment exists
    if [ -f /opt/egpaf/monitor/.env ]; then
        # remove the environment
        sudo rm /opt/egpaf/monitor/.env
        echo "Environment removed successfully"
    else
        echo "Environment does not exist"
    fi
}

function uninstallMonitor {
    # check if the monitor exists
    if [ -f /opt/egpaf/monitor/monitor.sh ]; then
        # remove the monitor
        sudo rm /opt/egpaf/monitor/monitor.sh
        echo "Monitor removed successfully"
    else
        echo "Monitor does not exist"
    fi
}

function removeDirectory {
    # check if the directory exists
    if [ -d /opt/egpaf/monitor ]; then
        # remove the directory
        sudo rm -r /opt/egpaf/monitor
        echo "Directory removed successfully"
    else
        echo "Directory does not exist"
    fi
}

echo "This will uninstall the service, transactions log and delete the environment file"
read -p "Do you want to continue? (y/n): " uninstall

if [ "$uninstall" == "y" ]; then
    uninstallService
    uninstallEnv
    uninstallMonitor
    removeDirectory
else
    echo "Leaving service intact"
fi

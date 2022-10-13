#!/bin/bash
# warn the user about uninstalling the service

function killAllMonitorProcesses {
    # kill all monitor processes
    echo "Killing all monitor processes"
    sudo killall monitor.sh
}

function uninstallMonitorService {
    # check if the service exists
    if [ -f /etc/systemd/system/egpaf.monitor.service ]; then
        # stop the service
        sudo systemctl stop egpaf.monitor.service
        # disable the service
        sudo systemctl disable egpaf.monitor.service
        # remove the service
        sudo rm /etc/systemd/system/egpaf.monitor.service
        # reload the daemon
        sudo systemctl daemon-reload
        echo "Service removed successfully"
    else
        echo "Service does not exist"
    fi
}

function uninstallServerService {
    # check if the service exists
    if [ -f /etc/systemd/system/egpaf.server.service ]; then
        # stop the service
        sudo systemctl stop egpaf.server.service
        # disable the service
        sudo systemctl disable egpaf.server.service
        # remove the service
        sudo rm /etc/systemd/system/egpaf.server.service
        # reload the daemon
        sudo systemctl daemon-reload
        echo "Server service removed successfully"
    else
        echo "Server service does not exist"
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

function removeHub {
    read -p "Do you want to continue uninstalling hub? (y/n): " uninstall
    if [ "$uninstall" == "y" ]; then
        killAllMonitorProcesses
        uninstallMonitorService
        uninstallEnv
        uninstallMonitor
        removeDirectory
    else
        echo "Leaving service intact"
    fi
}

function removeMolecularHub {
    read -p "Do you want to continue uninstalling molecular lab? (y/n): " uninstall
    if [ "$uninstall" == "y" ]; then
        uninstallServerService
    else
        echo "Leaving service intact"
    fi
}

echo "This will uninstall the service, transactions log and delete the environment file"
read -p "Do you want to uninstall the hub or molecular lab ? (h/m): " uninstall

if [ "$uninstall" == "h" ]; then
    removeHub
elif [ "$uninstall" == "m" ]; then
    removeMolecularHub
else
    echo "Invalid selection. Exiting setup"
    exit 1
fi
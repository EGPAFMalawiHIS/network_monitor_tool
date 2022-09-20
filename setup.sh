#!/bin/bash

# check if egpaf monitor folder exists
if [ ! -d /opt/egpaf/monitor ]; then
  sudo mkdir -p /opt/egpaf/monitor
fi

# create an function that captures environment variables
function capturEnv {
    # capture the environment variables
    read -p 'Enter Molecular Lab IP/HOST Address: ' ip
    read -p 'Enter Molecular Lab Port: ' port
    read -p 'CHSU IP/HOST Address: ' chsu
    read -p 'CHSU Port: ' chsuport

    echo "MLABIP=$ip" >> ./.env
    echo "MLABPORT=$port" >> ./.env
    echo "CHSU=$chsu" >> ./.env
    echo "CHSUPORT=$chsuport" >> ./.env

    suco cp ./.env /opt/egpaf/monitor/.env
}

# create a function that creates a network monitor service
function createService {
    # create the service file
    sudo cp ./monitor.sh /opt/egpaf/monitor/monitor.sh
    sudo chmod +x /opt/egpaf/monitor/monitor.sh
    sudo cp ./monitor.service /etc/systemd/system/monitor.service
    sudo systemctl daemon-reload
    sudo systemctl enable monitor.service
    sudo systemctl start monitor.service
}

# First check if there is an existing environment

if [ -f /opt/egpaf/monitor/.env ]; then
    echo "Existing environment found. Below are the settings in .env"
    echo "----------------------------------------------------------"
    cat /opt/egpaf/monitor/.env 
    echo "----------------------------------------------------------"
    echo "Do you want to overwrite the existing environment? (y/n)"
    read overwrite
    if [ "$overwrite" == "y" ]; then
        echo "Overwriting existing environment"
        rm /opt/egpaf/monitor/.env 
        capturEnv
    else
        echo "Exiting setup"
        exit 1
    fi
else
    echo "No existing environment found. Creating new environment"
    capturEnv
fi

# Secondly check if there is an existing service
if [ -f /etc/systemd/system/monitor.service ]; then
    echo "Existing service found. Below are the settings in monitor.service"
    echo "----------------------------------------------------------"
    cat /etc/systemd/system/monitor.service
    echo "----------------------------------------------------------"
    echo "Do you want to overwrite the existing service? (y/n)"
    read overwrite
    if [ "$overwrite" == "y" ]; then
        echo "Overwriting existing service"
        # disable the service
        sudo systemctl stop monitor.service
        sudo systemctl disable monitor.service
        # remove the service
        rm /etc/systemd/system/monitor.service
        createService
    else
        echo "Exiting setup"
        exit 1
    fi
else
    echo "No existing service found. Creating new service"
    createService
fi

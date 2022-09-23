#!/bin/bash

# check if egpaf monitor folder exists
if [ ! -d /opt/egpaf/monitor ]; then
  sudo mkdir -p /opt/egpaf/monitor
fi

# remove .env file if it exists
if [ -f ./.env ]; then
  sudo rm ./.env
fi

# create monitor sqlite database file does not exists
if [ ! -f /opt/egpaf/monitor/log/transaction.db ]; then 
    touch /opt/egpaf/monitor/log/transaction.db
    # create table
    sqlite3 /opt/egpaf/monitor/log/transaction.db "CREATE TABLE transactions (id TEXT PRIMARY KEY NOT NULL, start_time TEXT, end_time TEXT, sender_bits TEXT, receiver_bits TEXT, online INTEGER NOT NULL, sync_status INTEGER NOT NULL);"
fi 

# remove monitor.service file if it exists
if [ -f ./monitor.service ]; then
  sudo rm ./monitor.service
fi

# install jq to read json just incase the serve does have it
sudo apt install jq

# install local debian file
sudo dpkg -i ./iperf3_3.9-1_amd64.deb

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

    sudo cp ./.env /opt/egpaf/monitor/.env
}

function createMonitorFile {
    # remove the file if it exists
    if [ -f ./monitor.service ]; then
        sudo rm ./monitor.service
    fi
    echo "
[Unit]
Description=EGPAF NETWORK MONITOR
After=network.target

[Service]
Type=simple

Restart=always
KillMode=process
WorkingDirectory = /opt/egpaf/monitor/

User=$USER
ExecStart=/bin/bash ./monitor.sh

[Install]
WantedBy=multi-user.target
    " >> ./monitor.service
}

# create a function that creates a network monitor service
function createService {
    # create the service file
    createMonitorFile
    sudo cp ./monitor.sh /opt/egpaf/monitor/monitor.sh
    sudo chmod +x /opt/egpaf/monitor/monitor.sh
    sudo cp ./monitor.service /etc/systemd/system/egpaf.monitor.service
    sudo systemctl daemon-reload
    sudo systemctl enable egpaf.monitor.service
    sudo systemctl start egpaf.monitor.service
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
if [ -f /etc/systemd/system/egpaf.monitor.service ]; then
    echo "Existing service found. Below are the settings in monitor.service"
    echo "----------------------------------------------------------"
    cat /etc/systemd/system/egpaf.monitor.service
    echo "----------------------------------------------------------"
    echo "Do you want to overwrite the existing service? (y/n)"
    read overwrite
    if [ "$overwrite" == "y" ]; then
        echo "Overwriting existing service"
        # disable the service
        sudo systemctl stop egpaf.monitor.service
        sudo systemctl disable egpaf.monitor.service
        # remove the service
        rm /etc/systemd/system/egpaf.monitor.service
        createService
    else
        echo "Exiting setup"
        exit 1
    fi
else
    echo "No existing service found. Creating new service"
    createService
fi

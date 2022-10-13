#!/bin/bash

# change mode uninstall.sh to executable
sudo chmod +x uninstall.sh

# check if egpaf monitor folder exists
if [ ! -d /opt/egpaf/monitor ]; then
    sudo mkdir -p /opt/egpaf/monitor
    sudo chmod 777 /opt/egpaf
    sudo chmod 777 /opt/egpaf/monitor
fi

# create log folder
if [ ! -d /opt/egpaf/monitor/log ]; then
    sudo mkdir -p /opt/egpaf/monitor/log
    sudo chmod 777 /opt/egpaf/monitor/log
fi

# remove .env file if it exists
if [ -f ./.env ]; then
    sudo rm ./.env
fi

# check if jq is installed
if ! [ -x "$(command -v jq)" ]; then
    echo 'jq is not installed.' >&2
    echo 'Installing jq...'
    sudo apt-get install jq
    # exit if jq is not installed
    if ! [ -x "$(command -v jq)" ]; then
     # install jq from packages folder
        sudo dpkg -i packages/libc6_2.27-3ubuntu1_amd64.deb
        sudo dpkg -i packages/libonig4_6.7.0-1_amd64.deb
        sudo dpkg -i packages/libjq1_1.5+dfsg-2_amd64.deb
        sudo dpkg -i packages/jq_1.5+dfsg-2_amd64.deb
        if ! [ -x "$(command -v jq)" ]; then
            echo 'jq installation failed.' >&2
            echo 'Please install jq manually and try again.' >&2
            exit 1
        fi
    fi
fi

# check if sqlite3 is installed
if ! [ -x "$(command -v sqlite3)" ]; then
    echo 'sqlite3 is not installed.' >&2
    echo 'Installing sqlite3...'
    sudo apt-get install sqlite3
    # exit if sqlite3 is not installed
    if ! [ -x "$(command -v sqlite3)" ]; then
        echo 'sqlite3 installation failed.' >&2
        echo 'Please install sqlite3 manually and try again.' >&2
        exit 1
    fi
fi

# check if curl is installed
if ! [ -x "$(command -v curl)" ]; then
    echo 'curl is not installed.' >&2
    echo 'Installing curl...'
    sudo apt-get install curl
    # exit if curl is not installed
    if ! [ -x "$(command -v curl)" ]; then
        echo 'curl installation failed.' >&2
        echo 'Please install curl manually and try again.' >&2
        exit 1
    fi
fi

# check if iperf3 is installed
if ! [ -x "$(command -v iperf3)" ]; then
    echo 'iperf3 is not installed.' >&2
    echo 'Installing iperf3...'
    # install local debian file
    sudo dpkg -i ./iperf3_3.9-1_amd64.deb
fi

# create monitor sqlite database file does not exists
if [ ! -f /opt/egpaf/monitor/log/transaction.db ]; then
    sudo touch /opt/egpaf/monitor/log/transaction.db
    sudo chmod 777 /opt/egpaf/monitor/log/transaction.db
    # create table
    sqlite3 /opt/egpaf/monitor/log/transaction.db "CREATE TABLE transactions (id TEXT PRIMARY KEY NOT NULL, start_time TEXT, end_time TEXT, sender_bits TEXT, receiver_bits TEXT, online INTEGER NOT NULL, molecular_address TEXT NOT NULL, port TEXT NOT NULL, scan_status INTEGER, sync_status INTEGER NOT NULL); CREATE INDEX idx_transactions_sync_status ON transactions (sync_status);"
fi

# remove monitor.service file if it exists
if [ -f ./monitor.service ]; then
    sudo rm ./monitor.service
fi

# create an function that captures environment variables
function capturEnv {
    # capture the environment variables
    read -p 'Enter Molecular Lab IP/HOST Address: ' ip
    read -p 'Enter Molecular Lab Port: ' port
    read -p 'Dashboard API URL: ' chsu
    read -p 'Enter Site ID: ' siteid
    read -p 'Enter Test Interval in seconds(minimum 61): ' duration

    while [ "$duration" -lt 60 ]; do
        read -p 'Invalid interval. Please re-enter Interval: ' duration
    done

    echo "MLABIP=$ip" >>./.env
    echo "MLABPORT=$port" >>./.env
    echo "CHSU=$chsu" >>./.env
    echo "DURATION=$duration" >>./.env
    echo "SITEID=$siteid" >>./.env

    sudo cp ./.env /opt/egpaf/monitor/.env
    sudo chmod 777 /opt/egpaf/monitor/.env
}

function setupHub {
    # create the service file
    createMonitorFile
    sudo cp ./monitor.sh /opt/egpaf/monitor/monitor.sh
    sudo chmod +x /opt/egpaf/monitor/monitor.sh
    sudo cp ./monitor.service /etc/systemd/system/egpaf.monitor.service
    sudo chmod 777 /etc/systemd/system/egpaf.monitor.service
    sudo systemctl daemon-reload
    sudo systemctl enable egpaf.monitor.service
    sudo systemctl start egpaf.monitor.service
}

function setupMolecularLab {
    # create the service file
    createServerFile
    sudo cp ./server.service /etc/systemd/system/egpaf.server.service
    sudo chmod 777 /etc/systemd/system/egpaf.server.service
    sudo systemctl daemon-reload
    sudo systemctl enable egpaf.server.service
    sudo systemctl start egpaf.server.service
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
ExecStart=/bin/bash /opt/egpaf/monitor/monitor.sh

[Install]
WantedBy=multi-user.target
    " >>./monitor.service
}

function createServerFile {
    # remove the file if it exists
    if [ -f ./server.service ]; then
        sudo rm ./server.service
    fi
    echo "
[Unit]
Description=EGPAF NETWORK MONITOR SERVER
After=network.target

[Service]
Type=simple

Restart=always
KillMode=process

User=$USER
ExecStart=iperf3 -s

[Install]
WantedBy=multi-user.target
    " >>./server.service
}

# create a function that creates a network monitor service
function createService {
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
            sudo rm /opt/egpaf/monitor/.env
            capturEnv
        else
            echo "Leaving existing environment intact"
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
            sudo rm /etc/systemd/system/egpaf.monitor.service
            setupHub
        else
            echo "Exiting setup"
            exit 1
        fi
    else
        echo "No existing service found. Creating new service"
        setupHub
    fi
}

# Prompt user to select if they want to setup the hub or the molecular lab
read -p "Do you want to setup the hub or the molecular lab? (h/m) " setup
if [ "$setup" == "h" ]; then
    createService
elif [ "$setup" == "m" ]; then
    setupMolecularLab
else
    echo "Invalid selection. Exiting setup"
    exit 1
fi

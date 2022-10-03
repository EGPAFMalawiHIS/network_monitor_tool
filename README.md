# Introduction
This readme serves to guide both the user and the developer on how to use the monitor tool and how to develop it further.

## User Guide
In order to use the monitor tool, you need to have a linux server especially ubuntu as this solution has been tried and test on such an environment. You also need to have the following packages installed:
    - jq
    - curl
    - git
    - sqlite3
    - iperf3

### Installation
To install the monitor tool, you need to clone the repository and run the install script. The install script will install all the required packages and will also create a cron job that will run the monitor script every 5 minutes. The install script will also create a database file that will be used to store the data collected by the monitor script. The database file will be created in the same directory as the monitor script. To install the monitor tool, run the following commands:

```bash
git clone https://github.com/EGPAFMalawiHIS/network_monitor_tool.git
cd network_monitor_tool
sudo chmod +x setup.sh
./setup.sh
```

### Usage
The monitor script will collect the following data:
    - Port Scans
    - Iperf3 throughput

The monitor script will also send the collected data to the server. The server will then store the data in the database file.

### Uninstall
To uninstall the monitor tool, navigate to the cloned directory and run the following commands:

```bash
./uninstall.sh
```

## Developer Guide
The monitor tool is written in bash and is divided into two parts:
    - The monitor script
    - The sqlite3 database

The monitor script is responsible for collecting the data and sending it to the server. The server will then store the data in the database file.
The monitor script heavily relies on the following packages:
    - jq
    - curl
    - sqlite3
    - iperf3

Most of the code is inside functions to make them more readable and easier to update and debug. The script is divided into the following functions:
    - convert_bit_to_megabit (This function converts the bit value to megabit value)
    - get_api_key (This function gets the api key from the server)
    - send_data_to_api (This function sends the data to the server)
    - update_failed_records_in_database (This function updates the failed records in the database)
    - delete_synced_records_in_database (This function deletes the synced records in the database)
    - process_records (This function processes the unsyced records in the database by trying to send them to the server)
    - failed_connection (This function is called when the connection to the server fails)
    - port_scan (This function is responsible for collecting the port scan data)
    - bandwidth (This function is responsible for collecting the bandwidth data)

The database file is responsible for storing the data collected by the monitor script. The database file is created by the install script and is located in the same directory as the monitor script. The database file has only one table 
namely 'transactions'.

Below is the schema for the transactions table.

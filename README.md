# Introduction
This readme serves to guide both the user and the developer on how to use the monitor tool and how to develop it further.

## User Guide
In order to use the monitor tool, you need to have a linux server especially ubuntu as this solution has been tried and test on such an environment. You also need to have the following packages installed:
- jq
- curl
- git
- sqlite3
- iperf3

### Setup
To setup the monitor tool, you need to clone the repository.
```bash
git clone https://github.com/EGPAFMalawiHIS/network_monitor_tool.git
cd network_monitor_tool
sudo chmod +x setup.sh
```

### Installation
This section will guide you through the installation process of the monitor tool. The installation process is divided into two parts:
- Installation of the monitor tool at the HUB
- Installation of the server tool at the MOLECULAR LAB

The entry point into the installation process is the `setup.sh` script at the root of the cloned repository.

To start the installation process, you need to run the following command:
```bash
./setup.sh
```

#### `Installation of the monitor tool at the HUB`
Once the installation is started from above, you will be prompted to enter the type of tool you are trying to install.\
In this case, you need to enter `h` to install the monitor tool at the HUB.\
This will then prompt you to enter the address of the molecular lab server.\
It will then prompt for mysql database port to do portscans.\
Then another prompt for Dashboard URL, the URL will be used to send data of monitor transactions.

#### `Installation of the server tool at the MOLECULAR LAB`
Once the installation is started from installation section, you will be prompted to enter the type of tool you are trying to install.\
In this case, you need to enter `m` to install the server tool at the MOLECULAR LAB.\
This will create a service that will be listening for incoming requests from the HUB.

### Usage
The monitor script will collect the following data:
- Port Scans
- Iperf3 throughput

The monitor script will also send the collected data to the server. The server will then store the data in the database file.

### Uninstall
To uninstall the tool, navigate to the cloned directory and run the following commands:

```bash
./uninstall.sh
```
This will prompt for the tool you are trying to uninstall.\
In case you need to uninstall monitor tool then to enter `h` otherwise `m`.\
This process is irreversible.\
You will need to reinstall the tool if you need to use it again and back up the database file if you need to keep the data.


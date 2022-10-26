#!/bin/bash

echo 'Starting iperf3 server...'
iperf3 -s -D
echo 'iperf3 server started'
# loop every minute
while true; do
    # check if the iperf3 server is running
    if ! pgrep -x "iperf3" > /dev/null
    then
        echo 'iperf3 server is not running.' >&2
        echo 'Starting iperf3 server...'
        iperf3 -s -D
        echo 'iperf3 server re-started'
    fi
    sleep 60
done
#!/bin/bash

GW=`/sbin/ip route | awk '/default/ { print $3 }'`
checkdns=`cat /etc/resolv.conf | awk '/nameserver/ {print $2}' | awk 'NR == 1 {print; exit}'`

# read key pair values in .env file
source ./.env

checkml=$MLABIP
checkport=$MLABPORT
interval=$DURATION
api="$CHSU:$CHSUPORT"

#some functions
function convert_bit_to_megabit {
    echo "scale=2; $1 / 1000000" | bc
}

function get_api_key {
    # get the api key from the api
    api_key=`curl -s $api/api_key`
    echo $api_key
}

function send_data_to_api {
  # get response status from api
  echo "Sending data to api"
  echo "-------------------"
  echo "Data to send: $1"
  api_key='129290fhf'
  response=`curl --write-out '%{http_code}' --output /dev/null -s -X POST -H "Content-Type: application/json" -d '{"api_key":"'$api_key'", "data": "'$1'"}}' $api`
  if [ $response -eq 200 ]; then
    echo "Data sent successfully"
  else
    echo "Error sending data"
  fi
  echo $response
}

function update_failed_records_in_database {
  sqlite3 ./log/transaction.db "$1"
}

function delete_synced_records_in_database {
  sqlite3 ./log/transaction.db "DELETE FROM transactions WHERE sync_status = 1; DELETE FROM scans WHERE sync_status = 1;"
}

# process all records not synced
function process_records {
    # get all records not synced
    records=`sqlite3 -json ./log/transaction.db "SELECT * FROM transactions where sync_status = 0 LIMIT 30;"`
    statements=""
    # loop through each record in the json array

    echo ${records}
    for row in $(echo "${records}" | jq -r '.[] | @base64'); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }

        echo $(_jq '.id')
        echo $(_jq '.start_time')
        # get the id of the record
        id=`_jq '.id'`
        # get the start time of the record
        start_time=`_jq '.start_time'`
        # get the end time of the record
        end_time=`_jq '.end_time'`
        # get the sender bits of the record
        sender_bits=`_jq '.sender_bits'`
        # get the receiver bits of the record
        receiver_bits=`_jq '.receiver_bits'`
        # get the online status of the record
        online=`_jq '.online'`
        # get the sync status of the record
        sync_status=`_jq '.sync_status'`
        # create the data to send to the api
        data="{\"id\":\"$id\",\"start_time\":$start_time,\"end_time\":\"$end_time\",\"sender_bits\":\"$sender_bits\",\"receiver_bits\":\"$receiver_bits\",\"online\":\"$online\"}"
        # send the data to the api
        echo $data
        echo 'About to send data to api'
        response= send_data_to_api "$data" 
        echo $response
        if [[ $response -eq "200" ]]; then
          # create the statement to update the record
          statement="UPDATE transactions SET sync_status = 1 WHERE id = '$id';"
          # append the statement to the statements variable
          statements="$statements $statement"
        fi
    done
    # update the records
    update_failed_records_in_database "$statements"
}

function failed_connection {
  # insert into sqlite database
  uuid=$(cat /proc/sys/kernel/random/uuid)
  enddate=$(date)
  sqlite3 ./log/transaction.db "INSERT INTO transactions (id, start_time, end_time, online, sync_status) VALUES ('$uuid','$1', '$enddate',0, 0);"
  echo "Failed connection"
}


function bandwidth {
  startdate=$(date +%a,\ %d\ %b\ %Y\ %T)
  iperf3 -c $MLABIP -bidir -J | tee ./log/test.json
  startime=$(jq '.start.timestamp.time' ./log/test.json)
  # check if startime is null or empty
  if [ -z "$startime" ]; then
    failed_connection "$startdate"
  else
    # create an end date in 24hr format 
    endtime=$(date +%a,\ %d\ %b\ %Y\ %T)
    senderbits=$(jq '.end.sum_sent.bits_per_second' ./log/test.json)
    receiverbits=$(jq '.end.sum_received.bits_per_second' ./log/test.json)
    # convert bits to megabits
    senderbits=$(convert_bit_to_megabit $senderbits)
    receiverbits=$(convert_bit_to_megabit $receiverbits)
    # insert into sqlite database
    uuid=$(cat /proc/sys/kernel/random/uuid)
    sqlite3 ./log/transaction.db "INSERT INTO transactions (id, start_time, end_time, sender_bits, receiver_bits, online, sync_status) VALUES ('$uuid','$startdate', '$endtime', $senderbits, $receiverbits, 1, 0);"
    # send data to api
    data="{\"id\":\"$uuid\",\"start_time\":\"$startdate\",\"end_time\":\"$endtime\",\"sender_bits\":\"$senderbits\",\"receiver_bits\":\"$receiverbits\",\"online\":1}"
    response= send_data_to_api "$data"
    echo $response
    if [[ $response -eq "200" ]]; then
      # update the record
      update_failed_records_in_database "UPDATE transactions SET sync_status = 1 WHERE id = '$uuid';"
    fi
  fi
}

function portscan
{
  startdate=$(date)
  uuid=$(cat /proc/sys/kernel/random/uuid)
  tput setaf 6; echo "Starting port scan of $checkml port 3306"; tput sgr0;
  if nc -zw1 $checkml  $checkport; then
    enddate=$(date)
    sqlite3 ./log/transaction.db "INSERT INTO scans (id, start_time, end_time, port, online, sync_status) VALUES ('$uuid','$startdate', '$enddate', '$checkport', 1, 0);"
    tput setaf 2; echo "Port scan good, $checkml port 3306 available"; tput sgr0;
  else
    enddate=$(date)
    sqlite3 ./log/transaction.db "INSERT INTO scans (id, start_time, end_time, port, online, sync_status) VALUES ('$uuid','$startdate', '$enddate', '$checkport', 0, 0);"
    echo "Port scan of $checkml port 3306 failed."
  fi
}

# loop evey 5 minutes
while true
do
  # start a new thread to check the bandwidth
  process_records &
  bandwidth &
  portscan &
  delete_synced_records_in_database &
  sleep $interval
done

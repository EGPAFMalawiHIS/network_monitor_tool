#!/bin/bash

GW=$(/sbin/ip route | awk '/default/ { print $3 }')
checkdns=$(cat /etc/resolv.conf | awk '/nameserver/ {print $2}' | awk 'NR == 1 {print; exit}')

# read key pair values in .env file
source ./.env

checkml=$MLABIP
checkport=$MLABPORT
interval=$DURATION
site=$SITEID
api="$CHSU:$CHSUPORT"

#some functions
function convert_bit_to_megabit {
  echo "scale=2; $1 / 1000000" | bc
}

function get_api_key {
  # get the api key from the api
  api_key=$(curl -s $api/api_key)
  echo $api_key
}

function send_data_to_api {
  # get response status from api
  echo "Sending data to api"
  echo "-------------------"
  echo "Data to send: $1"
  response=$(curl --write-out '%{http_code}' --output /dev/null -s -X POST -H "Content-Type: application/json" -d '{"data": "'$1'"}}' $api)
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
  sqlite3 ./log/transaction.db "DELETE FROM transactions WHERE sync_status = 1;"
}

# process all records not synced
function process_records {
  # get all records not synced
  records=$(sqlite3 -json ./log/transaction.db "SELECT * FROM transactions where sync_status = 0 LIMIT 30;")
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
    id=$(_jq '.id')
    # get the start time of the record
    start_time=$(_jq '.start_time')
    # get the sender bits of the record
    sender_bits=$(_jq '.sender_bits')
    # get the receiver bits of the record
    receiver_bits=$(_jq '.receiver_bits')
    # get the online status of the record
    online=$(_jq '.online')
    molecular_address=$(_jq '.molecular_address')
    port=$(_jq '.port')
    scan_status=$(_jq '.scan_status')
    # create the data to send to the api
    data="{\"site_id\":\"$site\",\"test_time\":\"$start_time\",\"uplink\":\"$senderbits\",\"downlink\":\"$receiverbits\",\"online\":\"$online\",\"scan_status\":$scan_status,\"ip_address\":\"$molecular_address\",\"port\":\"$port\"}"
    # send the data to the api
    echo $data
    echo 'About to send data to api'
    response= send_data_to_api "$data"
    if [[ $response -eq 200 ]]; then
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
  sqlite3 ./log/transaction.db "INSERT INTO transactions (id, start_time, end_time, online, molecular_address, port, scan_status, sync_status) VALUES ('$uuid','$1','$enddate',0, '$checkml', '$checkport', $2, 0);"
  echo "Failed connection"
}

function bandwidth {
  startdate=$(date +%a,\ %d\ %b\ %Y\ %T)
  iperf3 -c $MLABIP -bidir -J | tee ./log/test.json
  scan=$(portscan)
  startime=$(jq '.start.timestamp.time' ./log/test.json)
  # check if startime is null or empty
  if [ -z "$startime" ]; then
    failed_connection "$startdate" $scan
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
    sqlite3 ./log/transaction.db "INSERT INTO transactions (id, start_time, end_time, sender_bits, receiver_bits, online, molecular_address, port, scan_status, sync_status) VALUES ('$uuid','$startdate', '$endtime', $senderbits, $receiverbits, 1, '$checkml', '$checkport', '$scan', 0);"
    # send data to api
    data="{\"site_id\":\"$site\",\"test_time\":\"$startdate\",\"uplink\":\"$senderbits\",\"downlink\":\"$receiverbits\",\"online\":1,\"scan_status\":$scan,\"ip_address\":\"$checkml\",\"port\":\"$checkport\"}"
    response= send_data_to_api "$data"
    echo $response
    if [[ $response -eq "200" ]]; then
      # update the record
      update_failed_records_in_database "UPDATE transactions SET sync_status = 1 WHERE id = '$uuid';"
    fi
  fi
}

function portscan {
  result=0
  if nc -zw1 $checkml $checkport; then
    result=1
  fi
  # return the result
  echo $result
}

while true; do
  # check if there are records not synced
  records=$(sqlite3 -json ./log/transaction.db "SELECT * FROM transactions where sync_status = 0 LIMIT 1;")
  if [[ $records != "[]" ]]; then
    # process the records
    process_records &
  fi
  # delete all synced records
  delete_synced_records_in_database &
  # run the bandwidth test
  bandwidth &
  # sleep for 5 minutes
  sleep $interval
done

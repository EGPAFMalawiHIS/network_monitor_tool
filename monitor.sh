#!/bin/bash

GW=$(/sbin/ip route | awk '/default/ { print $3 }')
checkdns=$(cat /etc/resolv.conf | awk '/nameserver/ {print $2}' | awk 'NR == 1 {print; exit}')

# read key pair values in .env file
source ./.env

checkml=$MLABIP
checkport=$MLABPORT
interval=$DURATION
site=$SITEID
api=$CHSU

#some functions
function convert_bit_to_megabit {
  local real_number=$(handleScientificNumbers "$1")
  echo "scale=2; $real_number / 1000000" | bc
}

function get_api_key {
  # get the api key from the api
  api_key=$(curl -s $api/api_key)
  echo $api_key
}

function send_data_to_api {
  response=$(curl --write-out '%{http_code}' --output /dev/null -s --location --request POST "$api/api/v1/create" --header "Content-Type: application/json" --data-raw "$1")
  echo $response
}

function update_failed_records_in_database {
  sqlite3 /opt/egpaf/monitor/log/transaction.db "$1"
}

function delete_synced_records_in_database {
  sqlite3 /opt/egpaf/monitor/log/transaction.db "DELETE FROM transactions WHERE sync_status = 1;"
}

# process all records not synced
function process_records {
  # get all records not synced
  mapfile -t < <(sqlite3 -list /opt/egpaf/monitor/log/transaction.db "SELECT * FROM transactions where sync_status = 0 LIMIT 50000;")
  # loop through elements in MAPFILE
  for record in "${MAPFILE[@]}"; do
    # get the record id
    id=$(echo $record | awk -F'|' '{print $1}')
    start_time=$(echo $record | awk -F'|' '{print $2}')
    sender_bits=$(echo $record | awk -F'|' '{print $4}')
    receiver_bits=$(echo $record | awk -F'|' '{print $5}')
    online=$(echo $record | awk -F'|' '{print $6}')
    molecular_address=$(echo $record | awk -F'|' '{print $7}')
    port=$(echo $record | awk -F'|' '{print $8}')
    scan_status=$(echo $record | awk -F'|' '{print $9}')
    # create the data to send to the api
    data="{\"site_id\":\"$site\",\"uuid\":\"$id\",\"test_time\":\"$start_time\",\"uplink\":\"$sender_bits\",\"downlink\":\"$receiver_bits\",\"online\":\"$online\",\"port_scan_status\":$scan_status,\"molecular_lab_ip\":\"$molecular_address\",\"port_scan\":\"$port\"}"
    # send the data to the api
    echo $data
    echo 'About to send data to api'
    local response=$(send_data_to_api "$data")
    echo $response
    if [ $response -eq 201 ]; then
      # create the statement to update the record
      statement="UPDATE transactions SET sync_status = 1 WHERE id = '$id';"
      update_failed_records_in_database "$statement"
    fi
  done
  # loop through each record in the json array

  # echo ${records}
  # for row in $(echo "${records}" | jq -r '.[] | @base64'); do
  #   _jq() {
  #     echo ${row} | base64 --decode | jq -r ${1}
  #   }

  #   echo $(_jq '.id')
  #   echo $(_jq '.start_time')
  #   # get the id of the record
  #   id=$(_jq '.id')
  #   # get the start time of the record
  #   start_time=$(_jq '.start_time')
  #   # get the sender bits of the record
  #   sender_bits=$(_jq '.sender_bits')
  #   # get the receiver bits of the record
  #   receiver_bits=$(_jq '.receiver_bits')
  #   # get the online status of the record
  #   online=$(_jq '.online')
  #   echo "this is the online status: $online"
  #   molecular_address=$(_jq '.molecular_address')
  #   port=$(_jq '.port')
  #   scan_status=$(_jq '.scan_status')
  #   # create the data to send to the api
  #   data="{\"site_id\":\"$site\",\"uuid\":\"$id\",\"test_time\":\"$start_time\",\"uplink\":\"$sender_bits\",\"downlink\":\"$receiver_bits\",\"online\":\"$online\",\"port_scan_status\":$scan_status,\"molecular_lab_ip\":\"$molecular_address\",\"port_scan\":\"$port\"}"
  #   # send the data to the api
  #   echo $data
  #   echo 'About to send data to api'
  #   local response=$(send_data_to_api "$data")
  #   echo $response
  #   if [ $response -eq 201 ]; then
  #     # create the statement to update the record
  #     statement="UPDATE transactions SET sync_status = 1 WHERE id = '$id';"
  #     update_failed_records_in_database "$statement"
  #   fi
  # done
}

function failed_connection {
  # insert into sqlite database
  uuid=$(cat /proc/sys/kernel/random/uuid)
  enddate=$(date +"%Y-%m-%d %H:%M:%S +%Z")
  sqlite3 /opt/egpaf/monitor/log/transaction.db "INSERT INTO transactions (id, start_time, end_time, online, molecular_address, port, scan_status, sync_status, sender_bits, receiver_bits) VALUES ('$uuid','$1','$enddate',0, '$checkml', '$checkport', '$2', 0, 0, 0);"
  data="{ \"site_id\": \"$site\", \"uuid\": \"$uuid\", \"test_time\": \"$1\", \"uplink\": 0, \"downlink\": 0, \"online\": 0, \"port_scan_status\": $2, \"molecular_lab_ip\": \"$checkml\", \"port_scan\": \"$checkport\" }"
  echo $data
  local result=$(send_data_to_api "$data")
  if [ $result -eq 201 ]; then
    # create the statement to update the record
    statement="UPDATE transactions SET sync_status = 1 WHERE id = '$uuid';"
    update_failed_records_in_database "$statement"
  fi
  echo "Failed connection"
}

function handleScientificNumbers {
  # check if the number is in scientific notation
  if [[ $1 == *e* ]]; then
    # convert the number to scientific notation
    echo $(printf "%10.2f\n" $1)
  else
    echo $1
  fi
}

function bandwidth {
  # date should be in mysql standard format
  startdate=$(date +"%Y-%m-%d %H:%M:%S +%Z")
  iperf3 -c $MLABIP -bidir -J | tee /opt/egpaf/monitor/log/test.json
  scan=$(portscan)
  startime=$(jq '.start.timestamp.time' /opt/egpaf/monitor/log/test.json)
  # check if startime is null or empty
  if [ -z "$startime" ]; then
    echo 'startime is null'
    failed_connection "$startdate" "$scan"
  elif ! [ -n "$startime" ]; then
    echo 'startime is null'
    failed_connection "$startdate" "$scan"
  else
    echo 'startime is not null. This is the value: ' $startime
    # create an end date in 24hr format
    endtime=$(date +"%Y-%m-%d %H:%M:%S +%Z")
    senderbits=$(jq '.end.sum_sent.bits_per_second' /opt/egpaf/monitor/log/test.json)
    receiverbits=$(jq '.end.sum_received.bits_per_second' /opt/egpaf/monitor/log/test.json)
    # convert bits to megabits
    senderbits=$(convert_bit_to_megabit $senderbits)
    receiverbits=$(convert_bit_to_megabit $receiverbits)
    # echo senderbits and receiverbits
    echo "sender bits: $senderbits"
    echo "reciver bits: $receiverbits"
    # insert into sqlite database
    uuid=$(cat /proc/sys/kernel/random/uuid)
    sqlite3 /opt/egpaf/monitor/log/transaction.db "INSERT INTO transactions (id, start_time, end_time, sender_bits, receiver_bits, online, molecular_address, port, scan_status, sync_status) VALUES ('$uuid','$startdate', '$endtime', $senderbits, $receiverbits, 1, '$checkml', '$checkport', '$scan', 0);"
    # send data to api
    data="{\"site_id\":\"$site\",\"uuid\":\"$uuid\",\"test_time\":\"$startdate\",\"uplink\":\"$senderbits\",\"downlink\":\"$receiverbits\",\"online\":1,\"port_scan_status\":$scan,\"molecular_lab_ip\":\"$checkml\",\"port_scan\":\"$checkport\"}"
    local response=$(send_data_to_api "$data")
    # convert response to integer
    echo "Response is $response"
    if [[ $response -eq 201 ]]; then
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
  records=$(sqlite3 -list /opt/egpaf/monitor/log/transaction.db "SELECT * FROM transactions where sync_status = 0 LIMIT 1;")
  # check if there are sqlite list records
  if [ -z "$records" ]; then
    echo 'No records to sync'
  elif ! [ -n "$records" ]; then
    echo 'No records to sync'
  else
    echo 'There are records to sync'
    # sync the records
     process_records &
  fi
  # if [[ $records != "[]" ]]; then
  #   # process the records
  #   process_records &
  # fi
  # delete all synced records
  delete_synced_records_in_database &
  # run the bandwidth test
  bandwidth &
  echo "Sleeping for $interval seconds"
  sleep $interval
done

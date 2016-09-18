#!/bin/bash

MAGE_WEB_USER="myshop"
MAGE_WEB_ROOT_PATH="/home/${MAGE_WEB_USER}/public_html"
API_URL="https://api.digitalocean.com/v2"
TOKEN="DO TOKEN"
DROPLET_ID=$(curl -s http://169.254.169.254/metadata/v1/id)
PRIVATE_IPV4=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
BALANCER="LB IP ADDRESS"

# Get CPU qty
CPU=$(grep -c "^processor" /proc/cpuinfo)
# Calculate droplet average load 5min
LOAD_1=$(cat /proc/loadavg | awk '{print $1}')
LOAD_AVERAGE_1=$(($(echo ${LOAD_1} | awk '{print 100 * $1}') / ${CPU}))
# Droplet average 5min load < 25% then delete droplet
if [ ${LOAD_AVERAGE_1} -le 25 ] ; then
# Remove IP from load balancer
ssh -q -oStrictHostKeyChecking=no -i ${MAGE_WEB_ROOT_PATH%/*}/.ssh/${MAGE_WEB_USER} ${MAGE_WEB_USER}@${BALANCER} sed -i "/${PRIVATE_IPV4}/d" ${MAGE_WEB_ROOT_PATH%/*}/backend.txt
# Delete droplet now
curl -s -X DELETE "${API_URL}/droplets/${DROPLET_ID}" -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" >/dev/null 2>&1
fi

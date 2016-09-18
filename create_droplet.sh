#!/bin/bash

## config
MAGE_WEB_USER="myshop"
MAGE_DOMAIN="myshop.com"
MAGE_WEB_ROOT_PATH="/home/${MAGE_WEB_USER}/public_html"
API_URL="https://api.digitalocean.com/v2"
TOKEN="DO TOKEN"
REGION="fra1"
DROPLET_SIZE="2gb"
IMAGE_ID="centos-7-x64"
SSH="DO SSH KEY ID"
BALANCER="LB PRIVATE IP ADDRESS"
DROPLET_CONFIG_FILE="LINK TO GITHUB PRIVATE REPO"
DROPLET_ID=$(echo $RANDOM)
DROPLETS_QTY=$(ssh -q -oStrictHostKeyChecking=no -i ${MAGE_WEB_ROOT_PATH%/*}/.ssh/${MAGE_WEB_USER} ${MAGE_WEB_USER}@${BALANCER} cat ${MAGE_WEB_ROOT_PATH%/*}/backend.txt | wc -l)

# Get CPU qty
CPU=$(grep -c "^processor" /proc/cpuinfo)
# Calculate droplet average load 5min
LOAD_1=$(cat /proc/loadavg | awk '{print $1}')
LOAD_AVERAGE_1=$(($(echo ${LOAD_1} | awk '{print 100 * $1}') / ${CPU}))
# Lock droplets total
if [ ${DROPLETS_QTY} -le 5 ] ; then
# Droplet average 5min load > 75% then create new droplet
if [ ${LOAD_AVERAGE_1} -ge 75 ] ; then
curl -X POST "${API_URL}/droplets" \
  -d"{\"name\":\"${DROPLET_ID}.${MAGE_DOMAIN}\",
\"region\":\"${REGION}\",
\"size\":\"${DROPLET_SIZE}\",
\"private_networking\":true,
\"image\":\"${IMAGE_ID}\",
\"ssh_keys\":[${SSH}],
\"user_data\":
\"#!bin/bash
wget -O /root/droplet_config.sh ${DROPLET_CONFIG_FILE}
bash /root/droplet_config.sh
rm /root/droplet_config.sh
\"}" \
	-H "Authorization: Bearer ${TOKEN}" \
	-H "Content-Type: application/json"
fi
fi

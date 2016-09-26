#!/bin/bash
# LOAD BALANCER
# Check running droplets

MAGE_WEB_USER="myshop"
MAGE_WEB_ROOT_PATH="/home/${MAGE_WEB_USER}/public_html"
MAGE_ADMIN_EMAIL="alert@myshop.com"
DROPLETS="${MAGE_WEB_ROOT_PATH%/*}/backend.conf"

while /usr/bin/inotifywait -e modify ${MAGE_WEB_ROOT_PATH%/*}/backend.conf; do
service nginx reload
echo "IP in Load Balance: ${DROPLETS}" | mail -s "Load Balance droplet reloaded" ${MAGE_ADMIN_EMAIL}
done

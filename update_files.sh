#!/bin/bash

# Push updates from master server to frontend web servers via rsync
MAGE_WEB_USER="myshop"
MAGE_WEB_ROOT_PATH="/home/${MAGE_WEB_USER}/public_html"
BALANCER="DO LB IP ADDRESS"
now=$(date +"%d.%m.%Y %T")
DROPLETS=$(ssh -q -oStrictHostKeyChecking=no -i ${MAGE_WEB_ROOT_PATH%/*}/.ssh/${MAGE_WEB_USER} ${MAGE_WEB_USER}@${BALANCER} cat ${MAGE_WEB_ROOT_PATH%/*}/backend.txt)
webservers=(${DROPLETS})
status="${MAGE_WEB_ROOT_PATH}/datasync.status.html"

if [ ! -z "${DROPLETS}" ]; then

if [ -d /tmp/.rsync.lock ]; then
echo "FAILURE : rsync lock exists : Perhaps there are lots of new data to push to frontend web servers." > ${status}
exit 1
fi

touch /tmp/.rsync.lock

if [ $? = "1" ]; then
echo "FAILURE : can not create lock" > ${status}
exit 1
else
echo "SUCCESS : created lock" > ${status}
fi

for DROPLET in ${webservers[@]}; do

echo "===== Beginning rsync of ${DROPLET} ====="

nice -n 20 /usr/bin/rsync -azx --timeout=30 --delete -e "ssh -q -oStrictHostKeyChecking=no -i ${MAGE_WEB_ROOT_PATH%/*}/.ssh/id_rsa" --exclude-from=${MAGE_WEB_ROOT_PATH%/*}/exclude.list  ${MAGE_WEB_ROOT_PATH}/ ${MAGE_WEB_USER}@${DROPLET}:${MAGE_WEB_ROOT_PATH}/

if [ $? = "1" ]; then
echo "Time of sync: ${now}" > ${status}
echo "<br/>" >> ${status}
echo "FAILURE : rsync failed." >> ${status}
exit 1
fi

echo "===== Completed rsync of ${DROPLET} =====";
done

/bin/rm -rf /tmp/.rsync.lock
echo "Time of sync: ${now}" > $status
echo "<br/>" >> $status
echo "SUCCESS : rsync completed successfully" >> $status
fi

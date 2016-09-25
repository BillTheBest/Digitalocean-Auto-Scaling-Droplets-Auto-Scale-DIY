#!/bin/bash
#====================================================================#
#  MagenX - Magento Autoscaling Template                             #
#    Copyright (C) 2016 admin@magenx.com                             #
#       All rights reserved.                                         #
#====================================================================#

### DEFINE LINKS AND PACKAGES ###

REPO_MASCM_TMP="https://raw.githubusercontent.com/magenx/Magento-Automated-Server-Configuration-from-MagenX/master/tmp/"
REPO_REMI="http://rpms.famillecollet.com/enterprise/remi-release-7.rpm"
REPO_FAN="http://www.city-fan.org/ftp/contrib/yum-repo/city-fan.org-release-1-13.rhel7.noarch.rpm"

# WebStack Packages
EXTRA_PACKAGES="boost tbb lz4 libyaml libdwarf bind-utils e2fsprogs gcc net-tools mcrypt unzip vim wget curl sudo rsyslog ncurses-devel GeoIP ImageMagick postfix attr nfs-utils nfs-utils-lib"
PHP_PACKAGES=(cli common fpm opcache gd curl mbstring bcmath soap mcrypt mysqlnd pdo xml xmlrpc intl gmp php-gettext phpseclib recode symfony-class-loader symfony-common tcpdf tcpdf-dejavu-sans-fonts tidy udan11-sql-parser snappy lz4) 
PHP_PECL_PACKAGES=(pecl-redis pecl-lzf pecl-geoip pecl-zip pecl-memcache)

# config vars
MAGE_DOMAIN="myshop.com"
MAGE_WEB_USER="myshop"
MAGE_WEB_ROOT_PATH="/home/${MAGE_WEB_USER}/public_html"
MAGE_ADMIN_EMAIL="alert@myshop.com"
MAGE_TIMEZONE="UTC"
SESSION_SAVE_PATH="tcp://1.2.3.4:6379"
SYSLOG_SERVER="@1.2.3.4:514"
BALANCER="DO LB IP ADDRESS"
DELETE_DROPLET_SCRIPT="LINK TO GITHUB PRIVATE REPO"
SSH_PORT=""

## System changes
hostnamectl set-hostname web${RANDOM}.${MAGE_DOMAIN}

# ssh config
sed -i "s/.*Port 22/Port ${SSH_PORT}/g" /etc/ssh/sshd_config
sed -i "s/.*LoginGraceTime.*/LoginGraceTime 30/" /etc/ssh/sshd_config
sed -i "s/.*MaxAuthTries.*/MaxAuthTries 6/" /etc/ssh/sshd_config
sed -i "s/.*X11Forwarding.*/X11Forwarding no/" /etc/ssh/sshd_config
sed -i "s/.*UseDNS.*/UseDNS no/" /etc/ssh/sshd_config
 
/bin/systemctl restart sshd.service

## add droplet ip to the load balancer
export PRIVATE_IPV4=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
ssh -q -oStrictHostKeyChecking=no -i ${MAGE_WEB_ROOT_PATH%/*}/.ssh/${MAGE_WEB_USER} -p ${SSH_PORT} ${MAGE_WEB_USER}@${BALANCER} "echo ${PRIVATE_IPV4} >> ${MAGE_WEB_ROOT_PATH%/*}/backend.txt" >/dev/null 2>&1

## create user
mkdir -p ${MAGE_WEB_ROOT_PATH}
setfacl -Rdm u:${MAGE_WEB_USER}:rwx,g:${MAGE_WEB_USER}:rwx,g::rw-,o::- ${MAGE_WEB_ROOT_PATH}
useradd -d ${MAGE_WEB_ROOT_PATH%/*} -s /sbin/nologin ${MAGE_WEB_USER} >/dev/null 2>&1

### DROPLET ACTIONS
## install all extra packages
yum -q -y install epel-release ${REPO_FAN} >/dev/null 2>&1
sed -i '0,/gpgkey/s//includepkgs=curl libmetalink libpsl libcurl libssh2\n&/' /etc/yum.repos.d/city-fan.org.repo
yum -q -y install ${EXTRA_PACKAGES} >/dev/null 2>&1

## update everything
yum -y -q update >/dev/null 2>&1

service nfs rpcbind restart

mkdir -p ${MAGE_WEB_ROOT_PATH}/media
mount ${MAGE_ADMIN_SERVER}:${MAGE_WEB_ROOT_PATH}/media ${MAGE_WEB_ROOT_PATH}/media
 
## install php 7.0
rpm --quiet -Uh ${REPO_REMI} >/dev/null 2>&1
yum --enablerepo=remi,remi-php70 -y -q install php ${PHP_PACKAGES[@]/#/php-} ${PHP_PECL_PACKAGES[@]/#/php-} >/dev/null 2>&1
          
## plug in service status alert
cp /usr/lib/systemd/system/php-fpm.service /etc/systemd/system/php-fpm.service
sed -i "s/PrivateTmp=true/PrivateTmp=false/" /etc/systemd/system/php-fpm.service
sed -i "/^After.*/a OnFailure=service-status-mail@%n.service" /etc/systemd/system/php-fpm.service
sed -i "/\[Install\]/i Restart=on-failure\nRestartSec=10\n" /etc/systemd/system/php-fpm.service
systemctl daemon-reload
systemctl enable php-fpm >/dev/null 2>&1
systemctl disable httpd >/dev/null 2>&1

cat > /etc/sysctl.conf <<END
fs.file-max = 1000000
fs.inotify.max_user_watches = 1000000
vm.swappiness = 10
net.ipv4.ip_forward = 0
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.accept_source_route = 0
kernel.sysrq = 0
kernel.core_uses_pid = 1
kernel.msgmnb = 65535
kernel.msgmax = 65535
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mem = 8388608 8388608 8388608
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 65535 8388608
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_challenge_ack_limit = 1073741823
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 15
net.ipv4.tcp_max_orphans = 262144
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_max_tw_buckets = 400000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_sack = 1
net.ipv4.route.flush = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 8388608
net.core.wmem_default = 8388608
net.core.netdev_max_backlog = 262144
net.core.somaxconn = 65535
END

sysctl -q -p

cat > /etc/php.d/10-opcache.ini <<END
zend_extension=opcache.so
opcache.enable = 1
opcache.enable_cli = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 4
opcache.max_accelerated_files = 50000
opcache.max_wasted_percentage = 5
opcache.use_cwd = 1
opcache.validate_timestamps = 0
;opcache.revalidate_freq = 2
opcache.file_update_protection = 2
opcache.revalidate_path = 0
opcache.save_comments = 1
opcache.load_comments = 1
opcache.fast_shutdown = 0
opcache.enable_file_override = 0
opcache.optimization_level = 0xffffffff
opcache.inherited_hack = 1
opcache.blacklist_filename=/etc/php.d/opcache-default.blacklist
opcache.max_file_size = 0
opcache.consistency_checks = 0
opcache.force_restart_timeout = 60
opcache.error_log = "${MAGE_WEB_ROOT_PATH}/var/log/opcache.log"
opcache.log_verbosity_level = 1
opcache.preferred_memory_model = ""
opcache.protect_memory = 0
;opcache.mmap_base = ""
END

cp /etc/php.ini /etc/php.ini.BACK
sed -i 's/^\(max_execution_time = \)[0-9]*/\17200/' /etc/php.ini
sed -i 's/^\(max_input_time = \)[0-9]*/\17200/' /etc/php.ini
sed -i 's/^\(memory_limit = \)[0-9]*M/\1512M/' /etc/php.ini
sed -i 's/^\(post_max_size = \)[0-9]*M/\164M/' /etc/php.ini
sed -i 's/^\(upload_max_filesize = \)[0-9]*M/\164M/' /etc/php.ini
sed -i 's/expose_php = On/expose_php = Off/' /etc/php.ini
sed -i 's/;realpath_cache_size = 16k/realpath_cache_size = 512k/' /etc/php.ini
sed -i 's/;realpath_cache_ttl = 120/realpath_cache_ttl = 86400/' /etc/php.ini
sed -i 's/short_open_tag = Off/short_open_tag = On/' /etc/php.ini
sed -i 's/; max_input_vars = 1000/max_input_vars = 50000/' /etc/php.ini
sed -i 's/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 28800/' /etc/php.ini
sed -i 's/mysql.allow_persistent = On/mysql.allow_persistent = Off/' /etc/php.ini
sed -i 's/mysqli.allow_persistent = On/mysqli.allow_persistent = Off/' /etc/php.ini
sed -i 's/pm = dynamic/pm = ondemand/' /etc/php-fpm.d/www.conf
sed -i 's/;pm.max_requests = 500/pm.max_requests = 10000/' /etc/php-fpm.d/www.conf
sed -i 's/pm.max_children = 50/pm.max_children = 1000/' /etc/php-fpm.d/www.conf
sed -i 's/;error_log = syslog/error_log = syslog/'  /etc/php.ini

echo "*         soft    nofile          700000" >> /etc/security/limits.conf
echo "*         hard    nofile          1000000" >> /etc/security/limits.conf

timedatectl set-timezone ${MAGE_TIMEZONE}

sed -i "s/\[www\]/\[${MAGE_WEB_USER}\]/" /etc/php-fpm.d/www.conf
sed -i "s/user = apache/user = ${MAGE_WEB_USER}/" /etc/php-fpm.d/www.conf
sed -i "s/group = apache/group = ${MAGE_WEB_USER}/" /etc/php-fpm.d/www.conf
sed -i "s/;listen.owner = nobody/listen.group = ${MAGE_WEB_USER}/" /etc/php-fpm.d/www.conf
sed -i "s/;listen.group = nobody/listen.group = ${MAGE_WEB_USER}/" /etc/php-fpm.d/www.conf
sed -i "s/;listen.mode = 0660/listen.mode = 0660/" /etc/php-fpm.d/www.conf
sed -i "s,session.save_handler = files,session.save_handler = redis," /etc/php.ini
sed -i 's,;session.save_path = "/tmp",session.save_path = "${SESSION_SAVE_PATH}",' /etc/php.ini
sed -i "s,.*date.timezone.*,date.timezone = ${MAGE_TIMEZONE}," /etc/php.ini
sed -i '/sendmail_path/,$d' /etc/php-fpm.d/www.conf

cat >> /etc/php-fpm.d/www.conf <<END
;;
;; Custom pool settings
php_flag[display_errors] = off
php_admin_flag[log_errors] = on
php_admin_value[memory_limit] = 512M
php_admin_value[date.timezone] = ${MAGE_TIMEZONE}
END

sed -i "s,error_log = /var/log/php-fpm/error.log,error_log = syslog/" /etc/php-fpm.conf
sed -i "s,;syslog.facility = daemon,syslog.facility = local4/" /etc/php-fpm.conf

echo "local4.* ${SYSLOG_SERVER}" >> /etc/rsyslog.conf
service rsyslog restart >/dev/null 2>&1

## service status email alerting
wget -qO /etc/systemd/system/service-status-mail@.service ${REPO_MASCM_TMP}service-status-mail@.service
wget -qO /bin/service-status-mail.sh ${REPO_MASCM_TMP}service-status-mail.sh
sed -i "s/MAGEADMINEMAIL/${MAGE_ADMIN_EMAIL}/" /bin/service-status-mail.sh
sed -i "s/DOMAINNAME/${MAGE_DOMAIN}/" /bin/service-status-mail.sh
chmod u+x /bin/service-status-mail.sh
systemctl daemon-reload

/bin/systemctl restart php-fpm.service

## create swap
dd if=/dev/zero of=/swapfile bs=1M count=512
mkswap /swapfile
chown root:root /swapfile 
chmod 0600 /swapfile
swapon /swapfile

## delete droplet script
wget -O /root/delete_droplet.sh ${DELETE_DROPLET_SCRIPT}
echo "*/5 * * * * /root/delete_droplet.sh > /dev/null" >> magecron
crontab -u root magecron
chmod u+x /root/delete_droplet.sh

## fix permissions
chown -R ${MAGE_WEB_USER}:${MAGE_WEB_USER} ${MAGE_WEB_ROOT_PATH%/*}
find . -type f -exec chmod 660 {} \;
find . -type d -exec chmod 2770 {} \;

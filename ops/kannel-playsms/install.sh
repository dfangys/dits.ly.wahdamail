#!/usr/bin/env bash
# Idempotent installer for Kannel + playSMS on CentOS 7
# Uses variables from .env in the same directory. DO NOT echo secrets.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo ".env not found in $ROOT_DIR. Copy .env.example to .env and fill values." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

log() { echo -e "[+] $*"; }
run() { echo "+ $*"; eval "$*"; }

# Defaults
ADMIN_ALLOWED_IPS=${ADMIN_ALLOWED_IPS:-127.0.0.1/32}
TLS_POLICY=${TLS_POLICY:-none}
WEB_SERVER=${WEB_SERVER:-nginx}  # nginx|apache
if [[ "$WEB_SERVER" == "nginx" ]]; then
  PLAYSMS_WEBROOT=${PLAYSMS_WEBROOT:-/www/wwwroot/playsms}
else
  PLAYSMS_WEBROOT=${PLAYSMS_WEBROOT:-/var/www/playsms}
fi
PLAYSMS_VERSION=${PLAYSMS_VERSION:-1.4.5}
DB_BACKUP_RETENTION_DAYS=${DB_BACKUP_RETENTION_DAYS:-7}
TIMEZONE=${TIMEZONE:-Africa/Tripoli}

# Detect availability of credentials
REQUIRED_DB_VARS=(MARIADB_ROOT_PASSWORD PLAYSMS_DB_PASS KANNEL_DLR_PASS)
HAS_DB_CREDS=1
for v in "${REQUIRED_DB_VARS[@]}"; do
  if [[ -z "${!v:-}" ]]; then HAS_DB_CREDS=0; fi
done

REQUIRED_ALMADAR_VARS=(ALMADAR_HOST ALMADAR_PORT ALMADAR_SYSTEM_ID ALMADAR_PASSWORD)
REQUIRED_LIBYANA_VARS=(LIBYANA_HOST LIBYANA_PORT LIBYANA_SYSTEM_ID LIBYANA_PASSWORD)
HAS_SMPP=1
for v in "${REQUIRED_ALMADAR_VARS[@]}"; do
  if [[ -z "${!v:-}" ]]; then HAS_SMPP=0; fi
done
for v in "${REQUIRED_LIBYANA_VARS[@]}"; do
  if [[ -z "${!v:-}" ]]; then HAS_SMPP=0; fi
done

# 1) Base repos, time, firewall, SELinux booleans
log "Enable repos and base packages"
yum -y install epel-release yum-utils policycoreutils-python firewalld chrony || true
run "systemctl enable --now chronyd"
run "systemctl enable --now firewalld"
# Set timezone
run "timedatectl set-timezone '${TIMEZONE}' || true"

# Remi for PHP 7.4
if ! rpm -q remi-release >/dev/null 2>&1; then
  run "yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm"
fi
run "yum-config-manager --enable remi-php74"

# MariaDB 10.5 repo (archived channel for CentOS 7)
cat >/etc/yum.repos.d/MariaDB.repo <<'EOF'
[mariadb]
name = MariaDB
baseurl = http://archive.mariadb.org/mariadb-10.5/yum/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

log "Install packages (skip Apache/PHP if WEB_SERVER=nginx)"
if [[ "$WEB_SERVER" == "apache" ]]; then
  yum -y install httpd \
    php php-cli php-common php-mysqlnd php-gd php-mbstring php-xml php-curl php-zip php-intl php-json || true
else
  echo "Skipping Apache/PHP packages because WEB_SERVER=$WEB_SERVER (aaPanel/nginx assumed)"
fi
# Always install MariaDB client/server (from MariaDB repo)
yum -y install MariaDB-server MariaDB-client galera-4 || true
# Try to install Kannel from repos if available (often not in CentOS 7)
yum -y install kannel kannel-mysql || true

# 2) Database: start MariaDB; if creds provided, secure and create DBs/users
run "systemctl enable --now mariadb"

if [[ "$HAS_DB_CREDS" -eq 1 ]]; then
  log "Secure MariaDB and create databases/users"
  # Try to set root password if no password works
  if mysql -uroot -e 'SELECT 1' >/dev/null 2>&1; then
    mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}'; FLUSH PRIVILEGES;" || true
  fi
  # From now on, use the provided password
  mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${PLAYSMS_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${KANNEL_DLR_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${PLAYSMS_DB_USER}'@'127.0.0.1' IDENTIFIED BY '${PLAYSMS_DB_PASS}';"
  mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${KANNEL_DLR_USER}'@'127.0.0.1' IDENTIFIED BY '${KANNEL_DLR_PASS}';"
  mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${PLAYSMS_DB}.* TO '${PLAYSMS_DB_USER}'@'127.0.0.1';"
  mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "GRANT SELECT,INSERT,UPDATE,DELETE ON ${KANNEL_DLR_DB}.* TO '${KANNEL_DLR_USER}'@'127.0.0.1'; FLUSH PRIVILEGES;"

  # Load Kannel DLR schema if present
  if [[ -f /usr/share/doc/kannel-*/mysql-dlr.sql ]]; then
    mysql -u"${KANNEL_DLR_USER}" -p"${KANNEL_DLR_PASS}" -h 127.0.0.1 "${KANNEL_DLR_DB}" < /usr/share/doc/kannel-*/mysql-dlr.sql || true
  elif [[ -f /usr/share/kannel/mysql-dlr.sql ]]; then
    mysql -u"${KANNEL_DLR_USER}" -p"${KANNEL_DLR_PASS}" -h 127.0.0.1 "${KANNEL_DLR_DB}" < /usr/share/kannel/mysql-dlr.sql || true
  fi
else
  log "DB credentials not provided. Skipping DB hardening and schema creation."
fi

# 3) Web server vhost + playSMS deployment (files only; complete via web installer)
mkdir -p "$PLAYSMS_WEBROOT"
if [[ "$WEB_SERVER" == "apache" ]]; then
  log "Configure Apache vhost for playSMS"
  cat >/etc/httpd/conf.d/playsms.conf <<EOF
<VirtualHost *:80>
    ServerName ${PLAYSMS_VHOST_SERVERNAME}
    DocumentRoot ${PLAYSMS_WEBROOT}
    <Directory ${PLAYSMS_WEBROOT}>
        AllowOverride All
        Options FollowSymLinks
        Require all granted
    </Directory>
    ErrorLog /var/log/httpd/playsms_error.log
    CustomLog /var/log/httpd/playsms_access.log combined
</VirtualHost>
EOF
  run "systemctl enable --now httpd"
else
  log "Configure Nginx server block for playSMS"
  # Detect php-fpm socket/port (aaPanel typical paths). Fallback to 127.0.0.1:9000
  PHP_FPM_SOCK_CANDIDATE=$(grep -R "^listen\s*=\s*" /www/server/php/*/etc/php-fpm.d/www.conf 2>/dev/null | awk -F= '{gsub(/ /,""); print $2}' | head -n1 || true)
  if [[ -z "$PHP_FPM_SOCK_CANDIDATE" ]]; then PHP_FPM_SOCK_CANDIDATE="127.0.0.1:9000"; fi
  # Choose vhost dir
  NGINX_VHOST_DIR="/etc/nginx/conf.d"
  if [[ -d "/www/server/panel/vhost/nginx" ]]; then NGINX_VHOST_DIR="/www/server/panel/vhost/nginx"; fi
  if [[ ! -d "$NGINX_VHOST_DIR" ]]; then mkdir -p "$NGINX_VHOST_DIR"; fi
  cat >"$NGINX_VHOST_DIR/playsms.conf" <<EOF
server {
    listen 80;
    server_name ${PLAYSMS_VHOST_SERVERNAME};
    root ${PLAYSMS_WEBROOT};
    index index.php index.html;
    client_max_body_size 20m;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass ${PHP_FPM_SOCK_CANDIDATE};
        fastcgi_read_timeout 300;
    }

    location ~* \.(?:css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf)$ {
        expires 7d;
        access_log off;
    }

    access_log /var/log/nginx/playsms_access.log;
    error_log /var/log/nginx/playsms_error.log;
}
EOF
  # Reload nginx if present
  (nginx -t && systemctl reload nginx) || true
fi

firewall-cmd --permanent --add-service=http || true
firewall-cmd --permanent --add-service=https || true
firewall-cmd --reload || true

log "Fetch playSMS ${PLAYSMS_VERSION} and stage into ${PLAYSMS_WEBROOT}"
TMPDIR="/usr/local/src"
mkdir -p "$TMPDIR"
if ! curl -fsSL -o "$TMPDIR/playsms-${PLAYSMS_VERSION}.tar.gz" "https://github.com/playsms/playsms/archive/refs/tags/${PLAYSMS_VERSION}.tar.gz"; then
  echo "Warning: Could not download playSMS ${PLAYSMS_VERSION}. Please place files manually into ${PLAYSMS_WEBROOT}." >&2
else
  tar -xf "$TMPDIR/playsms-${PLAYSMS_VERSION}.tar.gz" -C "$TMPDIR"
  rsync -a "$TMPDIR/playsms-${PLAYSMS_VERSION}/" "$PLAYSMS_WEBROOT/"
fi

# Pre-create config.php if sample exists
if [[ -f "$PLAYSMS_WEBROOT/config.php.sample" ]]; then
  cp -n "$PLAYSMS_WEBROOT/config.php.sample" "$PLAYSMS_WEBROOT/config.php"
  sed -i "s/'db_driver'.*/'db_driver' => 'mysql',/" "$PLAYSMS_WEBROOT/config.php" || true
  sed -i "s/'db_host'.*/'db_host' => '127.0.0.1',/" "$PLAYSMS_WEBROOT/config.php" || true
  sed -i "s/'db_port'.*/'db_port' => '3306',/" "$PLAYSMS_WEBROOT/config.php" || true
  sed -i "s/'db_name'.*/'db_name' => '${PLAYSMS_DB}',/" "$PLAYSMS_WEBROOT/config.php" || true
  sed -i "s/'db_user'.*/'db_user' => '${PLAYSMS_DB_USER}',/" "$PLAYSMS_WEBROOT/config.php" || true
  sed -i "s/'db_pass'.*/'db_pass' => '${PLAYSMS_DB_PASS}',/" "$PLAYSMS_WEBROOT/config.php" || true
fi

chown -R apache:apache "$PLAYSMS_WEBROOT"
find "$PLAYSMS_WEBROOT" -type d -exec chmod 755 {} \;
find "$PLAYSMS_WEBROOT" -type f -exec chmod 644 {} \;

# SELinux booleans and contexts for Apache
setsebool -P httpd_can_network_connect on || true
setsebool -P httpd_can_network_connect_db on || true
semanage fcontext -a -t httpd_sys_rw_content_t "${PLAYSMS_WEBROOT}/(var|storage|uploads)(/.*)?" || true
restorecon -Rv "$PLAYSMS_WEBROOT" || true

# 4) Kannel installation (fallback to source build if binaries missing) and configuration
# If bearerbox not present, try to build from source
if ! command -v bearerbox >/dev/null 2>&1; then
  log "Kannel not found in repos; building from source"
  yum -y groupinstall "Development Tools" || true
  yum -y install libxml2-devel openssl-devel pam-devel pcre-devel mariadb-devel zlib-devel || true
  SRC_DIR=/usr/local/src
  mkdir -p "$SRC_DIR"
  if [[ ! -d "$SRC_DIR/gateway-1.4.5" ]]; then
    curl -fsSL -o "$SRC_DIR/kannel.tar.gz" https://www.kannel.org/download/1.4.5/gateway-1.4.5.tar.gz || true
    tar -xf "$SRC_DIR/kannel.tar.gz" -d "$SRC_DIR" || tar -xf "$SRC_DIR/kannel.tar.gz" -C "$SRC_DIR"
  fi
  cd "$SRC_DIR/gateway-1.4.5" 2>/dev/null || cd "$SRC_DIR/gateway-1.4.5"
  ./configure --prefix=/usr --sysconfdir=/etc/kannel --with-mysql --with-openssl || true
  make -j$(nproc) || true
  make install || true
fi

log "Create Kannel config and directories"
useradd --system --home-dir /var/lib/kannel --shell /sbin/nologin kannel || true
mkdir -p /etc/kannel /var/log/kannel /var/spool/kannel /etc/kannel/certs
chown -R kannel:kannel /etc/kannel /var/log/kannel /var/spool/kannel

# Build allowed-prefix with optional formats
ALM_PREFIXES="+21891,+21893,21891,21893"
LIB_PREFIXES="+21892,+21894,21892,21894"
if [[ "${ACCEPT_00218}" == "true" ]]; then
  ALM_PREFIXES=",${ALM_PREFIXES},0021891,0021893"; ALM_PREFIXES=${ALM_PREFIXES#,}
  LIB_PREFIXES=",${LIB_PREFIXES},0021892,0021894"; LIB_PREFIXES=${LIB_PREFIXES#,}
fi
if [[ "${ACCEPT_LOCAL_09}" == "true" ]]; then
  ALM_PREFIXES=",${ALM_PREFIXES},091,093"; ALM_PREFIXES=${ALM_PREFIXES#,}
  LIB_PREFIXES=",${LIB_PREFIXES},092,094"; LIB_PREFIXES=${LIB_PREFIXES#,}
fi

cat >/etc/kannel/kannel.conf <<EOF
# Core
group = core
admin-port = 13000
admin-password = ${KANNEL_ADMIN_PASS}
status-password = ${KANNEL_STATUS_PASS}
admin-deny-ip = "0.0.0.0/0"
admin-allow-ip = "127.0.0.1;${ADMIN_ALLOWED_IPS}"
smsbox-port = 13001
box-deny-ip = "0.0.0.0/0"
box-allow-ip = "127.0.0.1"
store-type = file
store-file = /var/spool/kannel/kannel.store
access-log = /var/log/kannel/access.log
log-file = /var/log/kannel/bearerbox.log
log-level = 1
pidfile = /var/run/kannel/kannel.pid
# DLR storage
dlr-storage = mysql
dlr-url = "http://127.0.0.1/playsms/index.php?app=call&cat=gateway&plugin=kannel&access=callback&smsc=%p&to=%T&ts=%t&status=%d&id=%i"
dlr-msg-id = true

# MySQL connection for DLR
group = mysql-connection
id = dlr-db
host = 127.0.0.1
username = ${KANNEL_DLR_USER}
password = ${KANNEL_DLR_PASS}
database = ${KANNEL_DLR_DB}
max-connections = 2

# smsbox
group = smsbox
bearerbox-host = 127.0.0.1
sendsms-port = 13001
sendsms-chars = "0123456789 +-"
global-charset = UTF-8
log-file = /var/log/kannel/smsbox.log
access-log = /var/log/kannel/smsbox-access.log
smsbox-port = 13001
smsbox-bind-addr = 127.0.0.1

# sendsms user for playSMS
group = sendsms-user
username = ${KANNEL_SENDSMS_USER}
password = ${KANNEL_SENDSMS_PASS}
user-deny-ip = "0.0.0.0/0"
user-allow-ip = "127.0.0.1"
max-messages = 10
concatenation = true
default-dlr-mask = 31
EOF

# Append SMPP blocks only if credentials provided
if [[ "$HAS_SMPP" -eq 1 ]]; then
  cat >>/etc/kannel/kannel.conf <<EOF

# SMPP: Almadar
group = smsc
smsc = smpp
smsc-id = almadar
host = ${ALMADAR_HOST}
port = ${ALMADAR_PORT}
system-type =
system-id = ${ALMADAR_SYSTEM_ID}
password = ${ALMADAR_PASSWORD}
interface-version = 34
transceiver-mode = ${ALMADAR_BIND_MODE}
connections = ${ALMADAR_MAX_BINDS}
throughput = ${ALMADAR_TPS_PER_BIND}
window-size = ${ALMADAR_WINDOW_SIZE}
enquire-link-interval = ${ALMADAR_ENQUIRE_LINK}
smpp-ack-timeout = ${ALMADAR_SUBMIT_TIMEOUT}
reconnect-delay = 5
keepalive = 1
source-addr-ton = ${ALMADAR_SRC_TON}
source-addr-npi = ${ALMADAR_SRC_NPI}
dest-addr-ton = ${ALMADAR_DST_TON}
dest-addr-npi = ${ALMADAR_DST_NPI}
allowed-prefix = ${ALM_PREFIXES}
EOF

  if [[ "${ALMADAR_TLS}" == "on" ]]; then
    cat >>/etc/kannel/kannel.conf <<'EOF'
use-ssl = true
# ssl-ca-file = /etc/kannel/certs/ca.pem
# ssl-cert-file = /etc/kannel/certs/client.crt
# ssl-key-file = /etc/kannel/certs/client.key
EOF
  fi

  cat >>/etc/kannel/kannel.conf <<EOF

# SMPP: Libyana
group = smsc
smsc = smpp
smsc-id = libyana
host = ${LIBYANA_HOST}
port = ${LIBYANA_PORT}
system-type =
system-id = ${LIBYANA_SYSTEM_ID}
password = ${LIBYANA_PASSWORD}
interface-version = 34
transceiver-mode = ${LIBYANA_BIND_MODE}
connections = ${LIBYANA_MAX_BINDS}
throughput = ${LIBYANA_TPS_PER_BIND}
window-size = ${LIBYANA_WINDOW_SIZE}
enquire-link-interval = ${LIBYANA_ENQUIRE_LINK}
smpp-ack-timeout = ${LIBYANA_SUBMIT_TIMEOUT}
reconnect-delay = 5
keepalive = 1
source-addr-ton = ${LIBYANA_SRC_TON}
source-addr-npi = ${LIBYANA_SRC_NPI}
dest-addr-ton = ${LIBYANA_DST_TON}
dest-addr-npi = ${LIBYANA_DST_NPI}
allowed-prefix = ${LIB_PREFIXES}
EOF

  if [[ "${LIBYANA_TLS}" == "on" ]]; then
    cat >>/etc/kannel/kannel.conf <<'EOF'
use-ssl = true
# ssl-ca-file = /etc/kannel/certs/ca.pem
# ssl-cert-file = /etc/kannel/certs/client.crt
# ssl-key-file = /etc/kannel/certs/client.key
EOF
  fi
else
  log "SMPP credentials not provided. Skipping smsc blocks for now."
fi

chown -R kannel:kannel /etc/kannel
chmod 640 /etc/kannel/kannel.conf

# 5) systemd units
cat >/etc/systemd/system/kannel-bearerbox.service <<'EOF'
[Unit]
Description=Kannel bearerbox (core)
After=network-online.target mariadb.service
Wants=network-online.target

[Service]
User=kannel
Group=kannel
ExecStart=/usr/sbin/bearerbox -v 1 -d 1 /etc/kannel/kannel.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/kannel-smsbox.service <<'EOF'
[Unit]
Description=Kannel smsbox (HTTP sendsms)
After=kannel-bearerbox.service
Requires=kannel-bearerbox.service

[Service]
User=kannel
Group=kannel
ExecStart=/usr/sbin/smsbox -v 1 -d 1 /etc/kannel/kannel.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
# Enable services but only start when SMPP configured
systemctl enable kannel-bearerbox kannel-smsbox

# 6) Logrotate
cat >/etc/logrotate.d/kannel <<'EOF'
/var/log/kannel/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    copytruncate
    create 0640 kannel kannel
}
EOF

# 7) Kernel/network tuning
cat >/etc/sysctl.d/99-kannel-tuning.conf <<'EOF'
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 8192
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
EOF
sysctl --system || true

grep -q '^kannel' /etc/security/limits.conf || cat >>/etc/security/limits.conf <<'EOF'
kannel soft nofile 65536
kannel hard nofile 65536
EOF

# 8) Firewall rules for 13000 (admin) and ensure 13001 stays local
log "Configure firewalld for Kannel admin port"
# Remove any broad open rule for 13000 if exists
firewall-cmd --permanent --remove-port=13000/tcp || true
# Allow only from ADMIN_ALLOWED_IPS
IFS=';' read -r -a CIDRS <<<"${ADMIN_ALLOWED_IPS}"
for cidr in "${CIDRS[@]}"; do
  [[ -z "$cidr" ]] && continue
  firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${cidr}' port protocol='tcp' port='13000' accept" || true
done
firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port protocol='tcp' port='13000' drop" || true
firewall-cmd --reload || true

# 9) Start Kannel if SMPP is configured; otherwise skip
if [[ "$HAS_SMPP" -eq 1 ]]; then
  log "Start Kannel services"
  systemctl restart kannel-bearerbox kannel-smsbox
  sleep 2
  log "Kannel status (local query)"
  curl -s "http://127.0.0.1:13000/status?password=${KANNEL_ADMIN_PASS}" | sed -n '1,60p' || true
else
  log "SMPP not configured yet. Kannel services not started. After updating /etc/kannel/kannel.conf, run: systemctl restart kannel-bearerbox kannel-smsbox"
fi

echo "\nDone. Next steps:"
echo "1) Complete playSMS web installer at http://<server-ip>/ or ${PLAYSMS_FQDN}"
echo "2) In playSMS, configure Kannel gateway (127.0.0.1:13001, user ${KANNEL_SENDSMS_USER})"
echo "3) Run tests: /root/kannel-setup/scripts/test_sendsms.sh"
EOF

# 8) Firewall rules for 13000 (admin) and ensure 13001 stays local
log "Configure firewalld for Kannel admin port"
# Remove any broad open rule for 13000 if exists
firewall-cmd --permanent --remove-port=13000/tcp || true
# Allow only from ADMIN_ALLOWED_IPS
IFS=';' read -r -a CIDRS <<<"${ADMIN_ALLOWED_IPS}"
for cidr in "${CIDRS[@]}"; do
  [[ -z "$cidr" ]] && continue
  firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${cidr}' port protocol='tcp' port='13000' accept" || true
done
firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port protocol='tcp' port='13000' drop" || true
firewall-cmd --reload || true

# 9) Start Kannel if SMPP is configured; otherwise skip
if [[ "$HAS_SMPP" -eq 1 ]]; then
  log "Start Kannel services"
  systemctl restart kannel-bearerbox kannel-smsbox
  sleep 2
  log "Kannel status (local query)"
  curl -s "http://127.0.0.1:13000/status?password=${KANNEL_ADMIN_PASS}" | sed -n '1,60p' || true
else
  log "SMPP not configured yet. Kannel services not started. After updating /etc/kannel/kannel.conf, run: systemctl restart kannel-bearerbox kannel-smsbox"
fi

echo "\nDone. Next steps:"
echo "1) Complete playSMS web installer at http://<server-ip>/ or ${PLAYSMS_FQDN}"
echo "2) In playSMS, configure Kannel gateway (127.0.0.1:13001, user ${KANNEL_SENDSMS_USER})"
echo "3) Run tests: /root/kannel-setup/scripts/test_sendsms.sh"


#!/usr/bin/env bash
set -euo pipefail

DB_ROOT_PWD="${DB_ROOT_PWD:-}"

# 1) Ensure playSMS webroot present and staged
PLAYSMS_WEBROOT=/www/wwwroot/playsms
mkdir -p "$PLAYSMS_WEBROOT"
if [ ! -f "$PLAYSMS_WEBROOT/index.php" ]; then
  cd /usr/local/src
  curl -fsSL -o playsms-1.4.5.tar.gz https://github.com/playsms/playsms/archive/refs/tags/1.4.5.tar.gz
  rm -rf playsms-1.4.5 || true
  mkdir -p playsms-1.4.5
  (tar -xzf playsms-1.4.5.tar.gz --strip-components=1 -C playsms-1.4.5) || (tar -xf playsms-1.4.5.tar.gz --strip-components=1 -C playsms-1.4.5)
  rsync -a playsms-1.4.5/ "$PLAYSMS_WEBROOT"/
fi
chown -R root:root "$PLAYSMS_WEBROOT"
find "$PLAYSMS_WEBROOT" -type d -exec chmod 755 {} \;
find "$PLAYSMS_WEBROOT" -type f -exec chmod 644 {} \;

# 2) Mount playSMS under dimensions.ly as /playsms/ via aaPanel include
PHP_SOCK=$(grep -R "^listen\s*=\s*" /www/server/php/*/etc/php-fpm.d/www.conf 2>/dev/null | awk -F= '{gsub(/ /,"" ); print $2}' | head -n1)
[ -z "$PHP_SOCK" ] && PHP_SOCK=127.0.0.1:9000
VHOST_DIR=/www/server/panel/vhost/nginx/proxy/dimensions.ly
mkdir -p "$VHOST_DIR"
cat > "$VHOST_DIR/playsms.conf" <<'EOF'
location ^~ /playsms/ {
    alias /www/wwwroot/playsms/;
    index index.php index.html;
    try_files $uri $uri/ /playsms/index.php?$args;
}

location ~ ^/playsms/.*\.php$ {
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME /www/wwwroot/playsms$fastcgi_script_name;
    fastcgi_pass __PHP_SOCK__;
    fastcgi_read_timeout 300;
}
EOF
sed -i "s|__PHP_SOCK__|$PHP_SOCK|" "$VHOST_DIR/playsms.conf"
mkdir -p /var/log/nginx
:> /var/log/nginx/playsms_access.log
:> /var/log/nginx/playsms_error.log
chmod 640 /var/log/nginx/playsms_*.log || true
nginx -t >/dev/null
systemctl reload nginx || nginx -s reload || true

# 3) MySQL databases and users (if root password provided)
if [ -n "$DB_ROOT_PWD" ]; then
  if ! MYSQL_PWD="$DB_ROOT_PWD" mysql -uroot -e "SELECT 1" >/dev/null 2>&1; then
    mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PWD'; FLUSH PRIVILEGES;" || true
  fi
  MYSQL_PWD="$DB_ROOT_PWD" mysql -uroot -e "CREATE DATABASE IF NOT EXISTS playsms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  MYSQL_PWD="$DB_ROOT_PWD" mysql -uroot -e "CREATE DATABASE IF NOT EXISTS kannel_dlr CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  SECRETS=/root/kannel-setup/.secrets
  touch "$SECRETS" && chmod 600 "$SECRETS"
  get_secret() { grep -E "^$1=" "$SECRETS" | head -n1 | cut -d= -f2- || true; }
  set_secret() { sed -i "/^$1=/d" "$SECRETS"; echo "$1=$2" >> "$SECRETS"; }
  PLAYSMS_DB_PASS=$(get_secret PLAYSMS_DB_PASS); [ -n "$PLAYSMS_DB_PASS" ] || PLAYSMS_DB_PASS=$(openssl rand -hex 12)
  KANNEL_DLR_PASS=$(get_secret KANNEL_DLR_PASS); [ -n "$KANNEL_DLR_PASS" ] || KANNEL_DLR_PASS=$(openssl rand -hex 12)
  KANNEL_SENDSMS_PASS=$(get_secret KANNEL_SENDSMS_PASS); [ -n "$KANNEL_SENDSMS_PASS" ] || KANNEL_SENDSMS_PASS=$(openssl rand -hex 12)
  set_secret PLAYSMS_DB_PASS "$PLAYSMS_DB_PASS"
  set_secret KANNEL_DLR_PASS "$KANNEL_DLR_PASS"
  set_secret KANNEL_SENDSMS_PASS "$KANNEL_SENDSMS_PASS"
  MYSQL_PWD="$DB_ROOT_PWD" mysql -uroot -e "CREATE USER IF NOT EXISTS 'playsms_user'@'127.0.0.1' IDENTIFIED BY '$PLAYSMS_DB_PASS';"
  MYSQL_PWD="$DB_ROOT_PWD" mysql -uroot -e "CREATE USER IF NOT EXISTS 'kannel_dlr_user'@'127.0.0.1' IDENTIFIED BY '$KANNEL_DLR_PASS';"
  MYSQL_PWD="$DB_ROOT_PWD" mysql -uroot -e "GRANT ALL PRIVILEGES ON playsms.* TO 'playsms_user'@'127.0.0.1';"
  MYSQL_PWD="$DB_ROOT_PWD" mysql -uroot -e "GRANT SELECT,INSERT,UPDATE,DELETE ON kannel_dlr.* TO 'kannel_dlr_user'@'127.0.0.1'; FLUSH PRIVILEGES;"
  # Write playSMS DB config
  if [ -f "$PLAYSMS_WEBROOT/config.php" ]; then
    sed -i "s/'db_driver'.*/'db_driver' => 'mysql',/" "$PLAYSMS_WEBROOT/config.php"
    sed -i "s/'db_host'.*/'db_host' => '127.0.0.1',/" "$PLAYSMS_WEBROOT/config.php"
    sed -i "s/'db_port'.*/'db_port' => '3306',/" "$PLAYSMS_WEBROOT/config.php"
    sed -i "s/'db_name'.*/'db_name' => 'playsms',/" "$PLAYSMS_WEBROOT/config.php"
    sed -i "s/'db_user'.*/'db_user' => 'playsms_user',/" "$PLAYSMS_WEBROOT/config.php"
    sed -i "s/'db_pass'.*/'db_pass' => '$PLAYSMS_DB_PASS',/" "$PLAYSMS_WEBROOT/config.php"
  fi
  # Kannel DLR + sendsms-user + allowed-prefix routing
  TS=$(date +%Y%m%d%H%M%S)
  cp -a /etc/kannel/kannel.conf /etc/kannel/kannel.conf.bak-$TS 2>/dev/null || true
  if ! grep -q "^dlr-storage" /etc/kannel/kannel.conf; then
    cat >> /etc/kannel/kannel.conf <<'EOK'
# DLR storage and callback
dlr-storage = mysql
dlr-url = "http://127.0.0.1/playsms/index.php?app=call&cat=gateway&plugin=kannel&access=callback&smsc=%p&to=%T&ts=%t&status=%d&id=%i"

group = mysql-connection
id = dlr-db
host = 127.0.0.1
username = kannel_dlr_user
password = __KANNEL_DLR_PASS__
database = kannel_dlr
max-connections = 2
EOK
    sed -i "s|__KANNEL_DLR_PASS__|$KANNEL_DLR_PASS|" /etc/kannel/kannel.conf
  fi
  if ! grep -q "username = playsms" /etc/kannel/kannel.conf; then
    cat >> /etc/kannel/kannel.conf <<'EOK'
# sendsms user for playSMS
group = sendsms-user
username = playsms
password = __KANNEL_SENDSMS_PASS__
user-allow-ip = "127.0.0.1"
max-messages = 10
concatenation = true
default-dlr-mask = 31
EOK
    sed -i "s|__KANNEL_SENDSMS_PASS__|$KANNEL_SENDSMS_PASS|" /etc/kannel/kannel.conf
  fi
  # Insert allowed-prefix under each SMSC if not present
  if ! grep -q "+21891,\+21893" /etc/kannel/kannel.conf; then
    awk '
      BEGIN{alm=0; lib=0}
      /^group[ \t]*=[ \t]*smsc/{in_smsc=1}
      /smsc-id[ \t]*=[ \t]*Almadar/{alm=1}
      /smsc-id[ \t]*=[ \t]*Libyana/{lib=1}
      {
        print
        if (alm && $0 ~ /^interface-version/ && !seen_alm) {
          print "allowed-prefix = +21891,+21893,21891,21893,0021891,0021893,091,093"
          seen_alm=1; alm=0
        }
        if (lib && $0 ~ /^interface-version/ && !seen_lib) {
          print "allowed-prefix = +21892,+21894,21892,21894,0021892,0021894,092,094"
          seen_lib=1; lib=0
        }
      }
    ' /etc/kannel/kannel.conf > /etc/kannel/kannel.conf.tmp && mv /etc/kannel/kannel.conf.tmp /etc/kannel/kannel.conf
  fi
  systemctl restart kannel-bearerbox kannel-smsbox || true
fi

# 4) Final checks (no secrets)
echo "---CHECKS START---"
echo -n "[Nginx config test] "; nginx -t >/dev/null && echo OK || echo FAIL
echo -n "[playsms path] "; [ -f /www/wwwroot/playsms/index.php ] && echo OK || echo MISSING
echo -n "[dimensions.ly include] "; [ -f /www/server/panel/vhost/nginx/proxy/dimensions.ly/playsms.conf ] && echo OK || echo MISSING
echo -n "[Kannel bearerbox] "; command -v bearerbox >/dev/null && echo OK || echo MISSING
echo -n "[Kannel dlr-storage] "; grep -q "^dlr-storage" /etc/kannel/kannel.conf && echo YES || echo NO
echo -n "[Kannel sendsms-user playsms] "; grep -q "username = playsms" /etc/kannel/kannel.conf && echo YES || echo NO
echo -n "[Routing prefixes present] "; grep -q "+21891,\+21893" /etc/kannel/kannel.conf && grep -q "+21892,\+21894" /etc/kannel/kannel.conf && echo YES || echo NO
echo "---CHECKS END---"


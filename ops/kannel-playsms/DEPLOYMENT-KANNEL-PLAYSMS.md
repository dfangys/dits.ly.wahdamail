# Deployment Runbook: Kannel + playSMS (CentOS 7)

Environment
- OS: CentOS 7
- SELinux: enforcing
- Timezone: Africa/Tripoli
- Repos: EPEL, Remi (PHP 7.4), MariaDB 10.5

Credentials (stored only in /root/kannel-setup/.env, not in VCS)
- Kannel admin: ${KANNEL_ADMIN_PASS}
- Kannel sendsms: ${KANNEL_SENDSMS_USER}/${KANNEL_SENDSMS_PASS}
- MariaDB root: ${MARIADB_ROOT_PASSWORD}
- Databases: ${PLAYSMS_DB}/${PLAYSMS_DB_USER}/${PLAYSMS_DB_PASS}, ${KANNEL_DLR_DB}/${KANNEL_DLR_USER}/${KANNEL_DLR_PASS}
- SMPP Almadar: ${ALMADAR_*}
- SMPP Libyana: ${LIBYANA_*}

Key paths
- Kannel config: /etc/kannel/kannel.conf
- Kannel logs: /var/log/kannel/
- Kannel spool: /var/spool/kannel/
- Systemd units: /etc/systemd/system/kannel-bearerbox.service, /etc/systemd/system/kannel-smsbox.service
- playSMS webroot: ${PLAYSMS_WEBROOT}
- Apache vhost: /etc/httpd/conf.d/playsms.conf
- MariaDB data: /var/lib/mysql
- Backups: /var/backups/db

Firewall
- 80/tcp, 443/tcp open
- 13000/tcp restricted to ADMIN_ALLOWED_IPS
- 13001 bound to 127.0.0.1 only

Routing and normalization
- Almadar prefixes: +21891,+21893,21891,21893,(optional) 0021891,0021893,091,093
- Libyana prefixes: +21892,+21894,21892,21894,(optional) 0021892,0021894,092,094
- Outbound normalization to E.164 (+218…) recommended in playSMS. This deployment accepts multiple input formats for routing.

Operations
- Start: systemctl start kannel-bearerbox kannel-smsbox httpd mariadb
- Stop: systemctl stop kannel-bearerbox kannel-smsbox httpd mariadb
- Restart: systemctl restart kannel-bearerbox kannel-smsbox
- Status: systemctl status kannel-bearerbox kannel-smsbox --no-pager
- Kannel admin page: curl -s "http://127.0.0.1:13000/status?password=${KANNEL_ADMIN_PASS}"

Logs and rotation
- /var/log/kannel/bearerbox.log
- /var/log/kannel/smsbox.log
- /var/log/kannel/access.log
- Rotated daily via /etc/logrotate.d/kannel

Backups (optional)
- Use db-backup-playsms-kannel.sh (create under /usr/local/sbin) with nightly cron in /etc/cron.d/db-backup-playsms-kannel
- Retention: ${DB_BACKUP_RETENTION_DAYS} days

Scaling guidance
- Increase connections (binds) and throughput/window-size per SMSC as allowed by upstream
- Monitor bearerbox.log for throttling (ESME_RTHROTTLED etc.) and adjust throughput
- OS tuning in /etc/sysctl.d/99-kannel-tuning.conf; limits in /etc/security/limits.conf

Security
- SELinux booleans: httpd_can_network_connect=on, httpd_can_network_connect_db=on
- Admin port restricted via firewalld rich rules
- If using TLS for SMPP, place certs under /etc/kannel/certs and enable *_TLS=on in .env, then rerun installer

Testing
- Use scripts/test_sendsms.sh after completing playSMS setup and Kannel is running
- Validate DLR callbacks in /var/log/httpd/playsms_access.log
- In playSMS UI, confirm message status transitions (Sent/Delivered/Failed)


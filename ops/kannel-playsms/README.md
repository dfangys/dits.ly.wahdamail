# Kannel + playSMS Deployment Kit (CentOS 7)

This package contains a reproducible setup for Kannel SMS Gateway integrated with playSMS on CentOS 7.

What’s included
- .env.example — fill with your real values on the server (never commit secrets)
- install.sh — idempotent installer: repos, packages, Kannel, playSMS, MariaDB, SELinux, firewall, logrotate, systemd
- templates/
  - kannel.conf.template — reference template (install.sh generates actual config from .env)
  - playsms.conf.template — Apache vhost (install.sh renders from .env)
- systemd/
  - kannel-bearerbox.service
  - kannel-smsbox.service
- logrotate/kannel — daily rotation for Kannel logs
- scripts/test_sendsms.sh — local test helper to validate routing & DLRs
- DEPLOYMENT-KANNEL-PLAYSMS.md — operational runbook

Prereqs and notes
- Do not place secrets in this repo. Copy this folder to the server, create .env from .env.example, and fill values there.
- You will need SMPP credentials and DB passwords. The installer never echoes secrets.
- Admin port (13000) will be restricted to ADMIN_ALLOWED_IPS; sendsms (13001) binds to 127.0.0.1.
- SELinux remains enforcing with required booleans; firewalld in place.

Usage
1) Copy to server
   scp -P 6934 -r ops/kannel-playsms root@78.46.122.21:/root/kannel-setup

2) On server (as root)
   cd /root/kannel-setup
   cp .env.example .env
   # Edit .env to provide real values (SMPP, passwords, IPs, FQDN, version)
   vi .env
   chmod +x install.sh scripts/test_sendsms.sh
   ./install.sh

3) Complete playSMS web installer
   - Visit: http://<server-ip>/ (or your FQDN)
   - Create admin using PLAYSMS_ADMIN_* from .env
   - In playSMS Gateway config, set:
     - sendsms URL: http://127.0.0.1:13001/cgi-bin/sendsms
     - username/password: KANNEL_SENDSMS_USER/KANNEL_SENDSMS_PASS
     - DLR URL: http://127.0.0.1/playsms/index.php?app=call&cat=gateway&plugin=kannel&access=callback
     - Save and set as default gateway
   - Start playsmsd:
     /var/www/playsms/bin/playsmsd check && /var/www/playsms/bin/playsmsd start

4) Validate
   - Kannel admin (from allowed IP or via SSH tunnel):
     curl -s "http://127.0.0.1:13000/status?password=$KANNEL_ADMIN_PASS" | sed -n '1,80p'
   - Run test script:
     ./scripts/test_sendsms.sh
   - Watch logs:
     tail -f /var/log/kannel/bearerbox.log /var/log/kannel/smsbox.log
     tail -f /var/log/httpd/playsms_access.log

Routing & normalization
- Routing is enforced in Kannel per-SMSC via allowed-prefix for:
  - Almadar: +21891,+21893,21891,21893,0021891,0021893,091,093
  - Libyana: +21892,+21894,21892,21894,0021892,0021894,092,094
- Outbound normalization to E.164 (+218…) is recommended at the application layer (playSMS). Consult playSMS settings to normalize destinations; this kit accepts multiple input formats and ensures routing.

Security highlights
- Admin port 13000: restricted via firewalld to ADMIN_ALLOWED_IPS
- sendsms port 13001: bound to 127.0.0.1
- SELinux: enforcing; booleans for httpd to connect network/DB
- Logrotate: daily for Kannel logs
- Backups: optional cron and mysqldump script included

Uninstall (manual)
- systemctl disable --now kannel-smsbox kannel-bearerbox httpd mariadb
- yum remove kannel kannel-mysql httpd MariaDB-server -y (if desired)
- rm -rf /etc/kannel /var/log/kannel /var/spool/kannel /var/www/playsms /etc/httpd/conf.d/playsms.conf

Support
- If SMPP requires TLS/VPN, place certs in /etc/kannel/certs and set *_TLS=on in .env; rerun installer.


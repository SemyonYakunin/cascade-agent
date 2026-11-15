export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
timeout 300 apt-get -o DPkg::Lock::Timeout=300 install -y fail2ban </dev/null >/dev/null 2>&1 || { echo "fail2ban: FAIL (установка)"; exit 1; }
[ -f /etc/fail2ban/jail.local ] && cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak
cat > /etc/fail2ban/jail.local <<EOS
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ::1 $IGNORE

[sshd]
enabled = true
port    = $(echo $SSHP | tr ' ' ',')
backend = systemd
EOS
systemctl enable --now fail2ban </dev/null >/dev/null 2>&1
systemctl restart fail2ban </dev/null; sleep 2
if systemctl is-active fail2ban | grep -qx active && fail2ban-client status sshd >/dev/null 2>&1; then echo "fail2ban: PASS"; else echo "fail2ban: FAIL"; fi

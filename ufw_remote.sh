export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
timeout 300 apt-get -o DPkg::Lock::Timeout=300 install -y ufw </dev/null >/dev/null 2>&1 || { echo "ufw: FAIL (установка)"; exit 1; }
grep -q '^IPV6=yes' /etc/default/ufw || sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
for p in $SSHP; do ufw allow $p/tcp >/dev/null; done
ufw allow 443/tcp >/dev/null
cat > /root/ufw-safety.sh <<'EOS'
#!/bin/bash
sleep 300
ufw disable
EOS
chmod +x /root/ufw-safety.sh
nohup /root/ufw-safety.sh >/dev/null 2>&1 </dev/null &
echo $! > /root/ufw-safety.pid
ufw --force enable </dev/null >/dev/null
echo "ufw: $(ufw status | head -n1)"

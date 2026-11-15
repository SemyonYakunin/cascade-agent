#!/bin/bash
# reset.sh: стирает Xray, fail2ban и файрвол. ТОЛЬКО для тестовых серверов (пароли и sysctl не откатывает)
BASE_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$BASE_DIR/lib.sh"
HOST[1]=$S1_HOST; PORT[1]=${S1_PORT:-22}; PASS[1]=$S1_PASS
HOST[2]=$S2_HOST; PORT[2]=${S2_PORT:-22}; PASS[2]=$S2_PASS
init_job
trap 'disconnect; unset S1_PASS S2_PASS PASS SSHPASS' EXIT
read -r -p "Это сотрёт Xray, fail2ban и файрвол на ОБОИХ серверах. Для подтверждения введите СТЕРЕТЬ: " c
[ "$c" = "СТЕРЕТЬ" ] || { echo "Отмена"; exit 1; }
connect 1 || exit 1; connect 2 || exit 1
for n in 1 2; do
  log "Сервер $n: $(rs $n <<'EOS'
ufw --force disable >/dev/null 2>&1
systemctl stop xray >/dev/null 2>&1; systemctl disable xray >/dev/null 2>&1
systemctl stop fail2ban >/dev/null 2>&1; systemctl disable fail2ban >/dev/null 2>&1
pkill -x xray; sleep 1
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y fail2ban ufw </dev/null >/dev/null 2>&1
rm -rf /usr/local/etc/xray /usr/local/share/xray /usr/local/share/renewgeo /etc/systemd/system/xray.service /etc/systemd/system/xray@.service /etc/systemd/system/xray.service.d /etc/systemd/system/xray@.service.d /usr/local/bin/xray /usr/local/bin/newuser /usr/local/bin/rmuser /usr/local/bin/sharelink /usr/local/bin/userlist /usr/local/bin/mainuser /root/vpn-funcs.sh /root/cascad /root/xhttp-install /root/xray_remote.sh /root/prep_remote.sh /root/step.log /root/step.done /root/install.log /root/cascade.log /root/ufw-safety.*
rm -f /etc/systemd/system/*.wants/xray.service /etc/systemd/system/*.wants/xray@*.service
crontab -l 2>/dev/null | grep -v renewgeofiles | crontab -
systemctl daemon-reload; systemctl reset-failed >/dev/null 2>&1
echo "очищено: процесс xray=$(pgrep -x xray >/dev/null && echo ЕСТЬ || echo нет), конфиг xray=$([ -e /usr/local/etc/xray ] && echo есть || echo нет), ufw=$(command -v ufw >/dev/null && echo есть || echo нет), fail2ban=$(command -v fail2ban-client >/dev/null && echo есть || echo нет)"
EOS
)"
done

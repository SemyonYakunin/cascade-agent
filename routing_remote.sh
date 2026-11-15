# на сервере 1; переменные: IS_RU, DOMAINS, CRON_H, CRON_D
source /root/vpn-funcs.sh
if [ "$IS_RU" = 1 ]; then
  J=$(printf '%s\n' $DOMAINS | jq -R . | jq -s .)
  jq --argjson d "$J" '
    .routing.rules |= map(select(((.domain // []) | index("domain:ozonstatic.cn")) | not))
    | .routing.rules as $r | ($r | map(.outboundTag=="block") | index(true)) as $i
    | .routing.rules = ($r[:(($i // -1)+1)] + [{"type":"field","outboundTag":"direct","domain":$d}] + $r[(($i // -1)+1):])' $CFG > /tmp/c.json
else
  jq '.routing.rules |= map(select(.outboundTag != "direct"))' $CFG > /tmp/c.json
fi
echo "применение: $(apply /tmp/c.json | tail -n1)"

mkdir -p /usr/local/share/renewgeo
cat > /usr/local/share/renewgeo/renewgeofiles <<'EOS'
#!/bin/bash
set -e
D=/usr/local/share/xray
B=https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download
T=$(mktemp -d -p $D)
trap 'rm -rf "$T"' EXIT
wget -q -O "$T/geoip.dat" "$B/geoip.dat"
wget -q -O "$T/geosite.dat" "$B/geosite.dat"
if [ ! -s "$T/geoip.dat" ] || [ ! -s "$T/geosite.dat" ]; then
  echo "$(date): скачивание не удалось, старые файлы оставлены"
  exit 1
fi
mv "$T/geoip.dat" "$D/geoip.dat"
mv "$T/geosite.dat" "$D/geosite.dat"
systemctl restart xray
echo "$(date): геоданные обновлены, Xray перезапущен"
EOS
chmod +x /usr/local/share/renewgeo/renewgeofiles
timeout 300 /usr/local/share/renewgeo/renewgeofiles </dev/null | tail -n1 | grep -q "геоданные обновлены" && echo "обновление геоданных: PASS" || echo "обновление геоданных: FAIL"
(crontab -l 2>/dev/null | grep -v renewgeofiles; echo "0 $CRON_H * * $CRON_D /usr/local/share/renewgeo/renewgeofiles >> /var/log/renewgeo.log 2>&1") | crontab -
[ "$(crontab -l | grep -c renewgeofiles)" = 1 ] && echo "расписание ($(crontab -l | grep renewgeofiles | cut -d' ' -f1-5)): PASS" || echo "расписание: FAIL"
systemctl is-active cron </dev/null | grep -qx active && echo "cron active: PASS" || echo "cron active: FAIL"

CT=$(casc_tag)
if [ "$IS_RU" = 1 ]; then
  jq -e '[.routing.rules[] | select(.outboundTag=="direct")] | length >= 3' $CFG >/dev/null && echo "российские правила direct: PASS" || echo "российские правила direct: FAIL"
else
  [ "$(jq '[.routing.rules[] | select(.outboundTag=="direct")] | length' $CFG)" = 0 ] && echo "правил direct нет (сервер не в РФ): PASS" || echo "правил direct нет: FAIL"
fi
jq -e '[.routing.rules[] | select(.outboundTag=="block")] | length == 1' $CFG >/dev/null && echo "блокировка рекламы: PASS" || echo "блокировка рекламы: FAIL"
jq -r --arg t "$CT" '.routing.rules[-1].outboundTag | if .==$t then "последнее правило ведёт в каскад: PASS" else "последнее правило: FAIL" end' $CFG
xray_ok
rm -f /tmp/c.json

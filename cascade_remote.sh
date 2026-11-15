# выполняется на сервере 1; ожидает переменные LINK, CASC_ADDR, SNI2
source /root/vpn-funcs.sh
cd /root
cp $CFG $CFG.before-cascade
timeout 300 bash /root/cascad "$LINK" > /root/cascade.log 2>&1 < /dev/null
echo "cascad: код выхода $?"
grep -aiE "error|ошибк" /root/cascade.log | head -n 5
CT=$(casc_tag); echo "тег каскада: $CT"
jq --arg t "$CT" '(.outbounds[] | select(.tag==$t) | .streamSettings.realitySettings.fingerprint) = "chrome"' $CFG > /tmp/c.json && apply /tmp/c.json
if [ "$(jq -c '.dns' $CFG)" != "null" ]; then jq 'del(.dns)' $CFG > /tmp/c.json && apply /tmp/c.json; echo "блок dns удалён"; fi
CT=$(casc_tag)
jq -r --arg t "$CT" --arg a "$CASC_ADDR" --arg s "$SNI2" '
  .outbounds[] | select(.tag==$t) |
  "адрес=\(.settings.address) \(if .settings.address==$a then "PASS" else "FAIL" end)",
  "порт=\(.settings.port) \(if .settings.port==443 then "PASS" else "FAIL" end)",
  "транспорт=\(.streamSettings.network) \(if .streamSettings.network=="xhttp" then "PASS" else "FAIL" end)",
  "защита=\(.streamSettings.security) \(if .streamSettings.security=="reality" then "PASS" else "FAIL" end)",
  "sni=\(.streamSettings.realitySettings.serverName) \(if .streamSettings.realitySettings.serverName==$s then "PASS" else "FAIL" end)",
  "отпечаток=\(.streamSettings.realitySettings.fingerprint) \(if .streamSettings.realitySettings.fingerprint=="chrome" then "PASS" else "FAIL" end)"' $CFG
jq -r --arg t "$CT" '.routing.rules[-1].outboundTag | "последнее правило: \(.) \(if .==$t then "PASS" else "FAIL" end)"' $CFG
xray_ok
shred -u /root/cascade.log /root/cascad 2>/dev/null; rm -f /tmp/c.json /tmp/work.json

CFG=/usr/local/etc/xray/config.json
systemctl is-active --quiet xray && echo "служба active: PASS" || echo "служба active: FAIL"
for _i in $(seq 1 15); do ss -tln | grep -q ':443 ' && break; sleep 2; done
ss -tln | grep -q ':443 ' && echo "порт 443 слушается: PASS" || echo "порт 443 слушается: FAIL"
for k in shortsid uuid PrivateKey Password; do
  v=$(awk -F': ' -v k="$k" '$0 ~ k{print $2; exit}' /usr/local/etc/xray/.keys 2>/dev/null)
  [ -n "$v" ] && echo "ключ $k: PASS" || echo "ключ $k: FAIL"
done
timeout 90 xray run -test -config $CFG 2>&1 | grep -q "Configuration OK" && echo "конфиг: PASS" || echo "конфиг: FAIL"

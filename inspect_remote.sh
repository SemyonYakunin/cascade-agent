CFG=/usr/local/etc/xray/config.json
echo "версия: $(xray version 2>/dev/null | head -n1)"
echo "служба: $(systemctl is-active xray) | автозапуск: $(systemctl is-enabled xray 2>/dev/null) | работает с: $(systemctl show xray -p ActiveEnterTimestamp --value)"
echo "аптайм сервера: $(uptime -p)"
echo "слушают порты:"; ss -tlnp | awk 'NR>1{print "  "$4" "$6}' | head -n 15
if command -v jq >/dev/null && [ -f $CFG ]; then
  echo "входящие:"
  jq -r '.inbounds[] | "  порт \(.port) \(.protocol) \(.streamSettings.network // "-")/\(.streamSettings.security // "-") sni=\(.streamSettings.realitySettings.serverNames[0] // "-") клиентов=\(.settings.clients // [] | length)"' $CFG
  echo "клиенты:"; jq -r '.inbounds[].settings.clients[]?.email' $CFG | sed 's/^/  /'
  echo "исходящие:"
  jq -r '.outbounds[] | "  \(.tag) \(.protocol) \(.settings.address // .settings.vnext[0].address // "")"' $CFG
  echo "правил маршрутизации: $(jq '.routing.rules | length' $CFG)"
else
  echo "Xray не настроен"
fi
echo "ufw: $(command -v ufw >/dev/null && ufw status | head -n1 || echo не установлен) | fail2ban: $(systemctl is-active fail2ban 2>/dev/null)"

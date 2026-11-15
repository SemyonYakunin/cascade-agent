CFG=/usr/local/etc/xray/config.json

apply() {
  xray run -test -config "$1" 2>&1 | grep -q "Configuration OK" \
    && cp $CFG $CFG.bak-$(date +%Y%m%d-%H%M%S) \
    && cp "$1" $CFG \
    && systemctl restart xray && sleep 1 && systemctl is-active xray \
    || echo "ОШИБКА: конфиг не применён (рабочий файл не тронут или восстановите из .bak-*)"
}

best_sni() {
  for s in "$@"; do
    r=$(timeout 8 curl -4 -s -o /dev/null -m 5 --http2 --tlsv1.3 -w '%{http_version} %{time_appconnect}' https://$s 2>/dev/null) || continue
    v=${r%% *}; tm=${r##* }
    [ "$v" = "2" ] && echo "$tm $s"
  done | sort -n | head -n1 | awk '{print $2}'
}

set_sni() {
  jq --arg s "$1" '(.inbounds[] | select(.streamSettings.realitySettings != null) | .streamSettings.realitySettings) |= (.target=($s+":443") | .serverNames=[$s])' $CFG > /tmp/c.json \
    && apply /tmp/c.json
}

add_users() {
  cp $CFG /tmp/work.json
  for n in "$@"; do
    if jq -e --arg e "$n" '.inbounds[] | select(.streamSettings.realitySettings != null) | .settings.clients[] | select(.email==$e)' /tmp/work.json >/dev/null; then
      echo "уже есть: $n"; continue
    fi
    jq --arg e "$n" --arg u "$(xray uuid)" '(.inbounds[] | select(.streamSettings.realitySettings != null) | .settings.clients) += [{"email":$e,"id":$u,"flow":""}]' /tmp/work.json > /tmp/w2.json \
      && mv /tmp/w2.json /tmp/work.json && echo "добавлен: $n"
  done
  apply /tmp/work.json
}

rm_users() {
  cp $CFG /tmp/work.json
  for n in "$@"; do
    jq --arg e "$n" '(.inbounds[] | select(.streamSettings.realitySettings != null) | .settings.clients) |= map(select(.email != $e))' /tmp/work.json > /tmp/w2.json \
      && mv /tmp/w2.json /tmp/work.json && echo "удалён: $n"
  done
  apply /tmp/work.json
}

list_users() {
  jq -r '.inbounds[] | select(.streamSettings.realitySettings != null) | .settings.clients[] | .email' $CFG
}

mklink() {
  local IN PBK SID SNI ID
  IN='.inbounds[] | select(.streamSettings.realitySettings != null)'
  PBK=$(xray x25519 -i "$(jq -r "$IN | .streamSettings.realitySettings.privateKey" $CFG)" | grep -iE "public|password" | awk '{print $NF}')
  SID=$(jq -r "$IN | .streamSettings.realitySettings.shortIds[0]" $CFG)
  SNI=$(jq -r "$IN | .streamSettings.realitySettings.serverNames[0]" $CFG)
  ID=$(jq -r --arg e "$1" "$IN | .settings.clients[] | select(.email==\$e) | .id" $CFG)
  echo "vless://$ID@$2:443?security=reality&path=%2F&host=&mode=auto&sni=$SNI&fp=chrome&pbk=$PBK&sid=$SID&spx=%2F&type=xhttp&encryption=none#$1"
}

casc_tag() { jq -r '[.outbounds[] | select(.protocol=="vless") | .tag][0]' $CFG; }

xray_ok() {
  systemctl is-active xray | grep -qx active || { echo "FAIL: xray не active"; return 1; }
  for _i in $(seq 1 15); do ss -tln | grep -q ':443 ' && break; sleep 2; done
  ss -tln | grep -q ':443 ' || { echo "FAIL: порт 443 не слушается"; return 1; }
  timeout 90 xray run -test -config $CFG 2>&1 | grep -q "Configuration OK" || { echo "FAIL: конфиг не проходит проверку"; return 1; }
  echo "PASS: xray active, 443 слушается, конфиг OK"
}

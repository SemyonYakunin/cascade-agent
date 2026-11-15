# stage_users.sh: этап 5, пользователи и самопроверка цепочки (ссылки собираются, но не печатаются)
NAMES=(); LINKS=()
stage_users() {
  local cnt=${N_USERS:-1} i nm out list ip sn L
  NAMES=(); LINKS=()
  [[ $cnt =~ ^[0-9]+$ ]] && (( cnt >= 1 && cnt <= 50 )) || { log "СТОП: число пользователей должно быть от 1 до 50"; return 1; }
  for i in $(seq 1 $cnt); do NAMES+=("user$i"); done
  out=$(r 1 "source /root/vpn-funcs.sh; add_users ${NAMES[*]}")
  echo "$out" | tail -n1 | grep -qx active || { log "СТОП: не удалось добавить пользователей"; return 1; }
  if r 1 'source /root/vpn-funcs.sh; list_users' | grep -qx main; then
    r 1 'source /root/vpn-funcs.sh; rm_users main' >/dev/null
    log "Сервер 1: служебный пользователь установщика удалён (на сервере 2 он остаётся: через него идёт каскад)"
  fi
  list=$(r 1 'source /root/vpn-funcs.sh; list_users')
  for nm in "${NAMES[@]}"; do echo "$list" | grep -qx "$nm" || { log "СТОП: на сервере 1 нет пользователя $nm"; return 1; }; done
  log "Пользователи на сервере 1: $(echo "$list" | tr '\n' ' ')"
  out=$({ echo "U='${NAMES[0]}'"; cat "$BASE_DIR/selftest_remote.sh"; } | rs 1)
  ip=$(echo "$out" | sed -n 's/^SELFTEST_IP=//p')
  [ "$ip" = "${HOST[2]}" ] && log "Самопроверка цепочки: PASS (выход с IP $ip)" || { log "Самопроверка цепочки: FAIL (получено: '${ip:-пусто}')"; return 1; }
  sn=$(r 1 "jq -r '.inbounds[] | select(.streamSettings.realitySettings != null) | .streamSettings.realitySettings.serverNames[0]' /usr/local/etc/xray/config.json")
  for nm in "${NAMES[@]}"; do
    L=$(r 1 "source /root/vpn-funcs.sh; mklink $nm ${HOST[1]}")
    case "$L" in vless://*"@${HOST[1]}:443?"*"sni=$sn"*) ;; *) log "СТОП: ссылка для $nm собралась неверно"; return 1;; esac
    LINKS+=("$L")
  done
  log "Ссылок собрано: ${#LINKS[@]} (будут показаны в конце)"
}

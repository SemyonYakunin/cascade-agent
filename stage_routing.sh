# stage_routing.sh: этап 6, правила по стране сервера 1 и автообновление геоданных
RU_DOMAINS='domain:ozonstatic.cn domain:wildberries.cn domain:yastatic.net domain:yandex.net domain:userapi.com domain:vk-cdn.net domain:pool.ntp.org'

# час и день недели для cron сервера 1, чтобы обновление шло в воскресенье в 04:00 по поясу TZ_OFFSET
srv_cron_time() {
  local z S total dow=0
  z=$(r 1 'date +%z'); S=$((10#${z:1:2})); [ "${z:0:1}" = "-" ] && S=$((-S))
  total=$(( 4 - ${TZ_OFFSET:-0} + S ))
  if (( total < 0 )); then total=$((total+24)); dow=6
  elif (( total >= 24 )); then total=$((total-24)); dow=1; fi
  echo "$total $dow"
}

stage_routing() {
  local c1 isru=0 out hour dow u ip tz=${TZ_OFFSET:-0}
  [[ $tz =~ ^-?[0-9]+$ ]] && (( tz >= -12 && tz <= 14 )) || { log "СТОП: TZ_OFFSET должен быть целым числом от -12 до 14"; return 1; }
  TZ_OFFSET=$tz
  c1=$(country_of "${HOST[1]}"); log "Страна сервера 1: ${c1:-не определена}"
  [ "$c1" = RU ] && isru=1
  [ -n "${FORCE_RU:-}" ] && isru=1
  read -r hour dow < <(srv_cron_time)
  log "Режим: $([ $isru = 1 ] && echo 'сервер в РФ, российское напрямую' || echo 'сервер не в РФ, всё через каскад'); геоданные обновляются по воскресеньям в 04:00 ($(printf 'UTC%+d' $tz)); cron сервера: час $hour, день недели $dow"
  out=$({ echo "IS_RU=$isru"; echo "DOMAINS='$RU_DOMAINS'"; echo "CRON_H=$hour"; echo "CRON_D=$dow"; cat "$BASE_DIR/routing_remote.sh"; } | rs 1)
  echo "$out" | sed 's/^/  сервер 1: /' | tee -a "$LOG"
  echo "$out" | grep -qE 'FAIL|ОШИБКА' && { log "СТОП: проверки маршрутизации не прошли"; return 1; }
  echo "$out" | grep -q 'PASS: xray active' || { log "СТОП: Xray после изменений не подтверждён"; return 1; }
  u=$(r 1 'source /root/vpn-funcs.sh; list_users | head -n1')
  ip=$({ echo "U='$u'"; cat "$BASE_DIR/selftest_remote.sh"; } | rs 1 | sed -n 's/^SELFTEST_IP=//p')
  [ "$ip" = "${HOST[2]}" ] && log "Цепочка после смены правил: PASS (выход с IP $ip)" || { log "Цепочка после смены правил: FAIL (получено: '${ip:-пусто}')"; return 1; }
}

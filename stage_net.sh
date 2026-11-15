# stage_net.sh: этап 2, проверка IPv6 между серверами (только чтение)
declare -A V6
get_v6() { r "$1" "ip -6 addr show scope global | awk '/inet6/ && !/deprecated/{print \$2; exit}' | cut -d/ -f1"; }
loss()   { grep -oE '[0-9]+% packet loss' | head -n1; }

stage_net_check() {
  local n o sz res
  V6[1]=$(get_v6 1); V6[2]=$(get_v6 2)
  [ -n "${V6[1]}" ] && [ -n "${V6[2]}" ] || { log "У одного из серверов нет глобального IPv6, каскад пойдёт по IPv4"; return 1; }
  log "IPv6 сервера 1: ${V6[1]}"; log "IPv6 сервера 2: ${V6[2]}"
  NET_OK=1
  for n in 1 2; do
    o=$((3-n))
    res=$(r $n "ping -6 -c 10 -W 3 -q ${V6[$o]} 2>&1" | loss)
    log "Сервер $n -> сервер $o по IPv6: ${res:-нет ответа}"
    [ "$res" = "0% packet loss" ] || NET_OK=0
  done
  for sz in 1232 1432; do
    res=$(r 1 "ping -6 -M do -c 4 -W 3 -s $sz -q ${V6[2]} 2>&1" | loss)
    log "Пакет 1->2 с данными $sz байт (путь MTU $((sz+48))): ${res:-нет ответа}"
  done
  if [ "$NET_OK" = 1 ]; then log "Итог: связь между серверами по IPv6 чистая"
  else log "Итог: между серверами по IPv6 есть потери, каскад пойдёт по IPv4 (если открыт порт 443)"; return 1; fi
}

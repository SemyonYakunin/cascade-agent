# stage_prep.sh: этап 1, обновление системы и пакеты (оба сервера)
start_prep() {
  local n=$1
  { echo "cat > /root/prep_remote.sh <<'EOS'"; cat "$BASE_DIR/prep_remote.sh"; echo "EOS"
    echo "nohup bash /root/prep_remote.sh >/dev/null 2>&1 </dev/null &"; echo "echo started"; } | rs "$n" >/dev/null
}

wait_prep() {
  local i n d d1 d2
  for i in $(seq 1 120); do
    d1=$(r 1 'cat /root/step.done 2>/dev/null'); d2=$(r 2 'cat /root/step.done 2>/dev/null')
    [ -n "$d1" ] && [ -n "$d2" ] && break
    (( i % 4 == 0 )) && log "Обновление идёт... ($((i/4)) мин)"
    sleep 15
  done
  for n in 1 2; do
    d=$(r $n 'cat /root/step.done 2>/dev/null')
    if [ "$d" != 0 ]; then
      log "СТОП: подготовка сервера $n не завершилась успешно (код: ${d:-нет}). Последние строки журнала:"
      r $n 'tail -n 15 /root/step.log' | tee -a "$LOG"; return 1
    fi
  done
  log "Обновление и пакеты: готово на обоих серверах"
}

reboot_server() {
  local n=$1 old new i
  old=$(r $n 'cat /proc/sys/kernel/random/boot_id')
  log "Сервер $n: перезагрузка"
  r $n "nohup bash -c 'sleep 2; reboot' >/dev/null 2>&1 &"
  sleep 15; rm -f "/tmp/cm-$JOB_ID-$n"
  for i in $(seq 1 42); do
    new=$(SSHPASS="${PASS[$n]}" sshpass -e ssh $SSH_BASE -o PubkeyAuthentication=no -o ControlPath=none -p "${PORT[$n]}" "root@${HOST[$n]}" 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null)
    [ -n "$new" ] && [ "$new" != "$old" ] && break
    sleep 10
  done
  [ -n "$new" ] && [ "$new" != "$old" ] || { log "СТОП: сервер $n не вернулся за 7 минут (нужна консоль хостинга)"; return 1; }
  connect $n
}

stage_prep() {
  local n
  for n in 1 2; do start_prep $n; done
  log "Обновление запущено на обоих серверах (5-15 минут)"
  wait_prep || return 1
  for n in 1 2; do
    if [ "$(r $n '[ -f /var/run/reboot-required ] && echo yes || echo no')" = yes ]; then reboot_server $n || return 1; fi
  done
  for n in 1 2; do
    log "Сервер $n: jq=$(r $n 'jq --version') | swap=$(r $n 'free -m | awk "/Swap/{print \$2}"') МБ | ядро=$(r $n 'uname -r')"
  done
}

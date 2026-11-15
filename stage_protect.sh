# stage_protect.sh: этап 7, fail2ban и файрвол со страховочным таймером
detect_ssh_ports() {
  local p
  p=$(echo "ss -tlnp | awk '/sshd/{n=split(\$4,a,\":\"); print a[n]}' | sort -u | tr '\n' ' '" | rs "$1")
  p=$(echo $p); echo "${p:-${PORT[$1]}}"
}

# отмена страховки: сначала убиваем сам скрипт-таймер (по PID из файла), не ищем по тексту команды
cancel_safety() { r "$1" 'p=$(cat /root/ufw-safety.pid 2>/dev/null); [ -n "$p" ] && kill $p; rm -f /root/ufw-safety.pid /root/ufw-safety.sh; true'; }

verify_fw() {
  local n=$1 ok=1 out
  out=$(SSHPASS="${PASS[$n]}" sshpass -e ssh $SSH_BASE -o PubkeyAuthentication=no -o ControlPath=none -o ControlMaster=no -p "${PORT[$n]}" "root@${HOST[$n]}" 'echo SSH_OK' 2>/dev/null)
  [ "$out" = SSH_OK ] && log "  сервер $n: новое SSH-соединение: PASS" || { log "  сервер $n: новое SSH-соединение: FAIL"; ok=0; }
  [ "$(r $n "ss -tln | grep -q ':443 ' && echo ok")" = ok ] && log "  сервер $n: Xray слушает 443: PASS" || { log "  сервер $n: Xray слушает 443: FAIL"; ok=0; }
  timeout 8 bash -c "</dev/tcp/${HOST[$n]}/443" 2>/dev/null && log "  сервер $n: порт 443 доступен снаружи: PASS" || { log "  сервер $n: порт 443 снаружи: FAIL"; ok=0; }
  if [ "$n" = 2 ]; then
    [ "$(tcp 1 "${HOST[2]}" 443)" = open ] && log "  сервер 2: порт 443 доступен с сервера 1: PASS" || { log "  сервер 2: с сервера 1 порт 443: FAIL"; ok=0; }
  fi
  [ $ok = 1 ]
}

stage_protect() {
  local n ign cli sshp out u ip st f2 tm
  cli=$(r 1 'echo ${SSH_CONNECTION%% *}')
  ign="${HOST[1]} ${HOST[2]} ${V6[1]:-} ${V6[2]:-} $cli"
  log "fail2ban не банит: $ign"
  for n in 1 2; do
    sshp=$(detect_ssh_ports $n)
    out=$({ echo "IGNORE='$ign' SSHP='$sshp'"; cat "$BASE_DIR/f2b_remote.sh"; } | rs $n)
    log "Сервер $n: $out"
    echo "$out" | grep -q 'fail2ban: PASS' || { log "СТОП: fail2ban на сервере $n не заработал"; return 1; }
  done
  for n in 2 1; do
    sshp=$(detect_ssh_ports $n)
    log "Сервер $n: включаю файрвол (SSH-порты: $sshp, плюс 443)"
    out=$({ echo "SSHP='$sshp'"; cat "$BASE_DIR/ufw_remote.sh"; } | rs $n)
    log "Сервер $n: $out"
    if echo "$out" | grep -q 'Status: active' && verify_fw $n; then
      cancel_safety $n
      log "Сервер $n: файрвол подтверждён, страховка снята"
    else
      log "СТОП: проверка сервера $n не прошла. Страховка выключит файрвол сама через 5 минут (подождите 310 секунд)."
      return 1
    fi
  done
  u=$(r 1 'source /root/vpn-funcs.sh; list_users | head -n1')
  ip=$({ echo "U='$u'"; cat "$BASE_DIR/selftest_remote.sh"; } | rs 1 | sed -n 's/^SELFTEST_IP=//p')
  [ "$ip" = "${HOST[2]}" ] && log "Цепочка после файрвола: PASS (выход с IP $ip)" || { log "Цепочка после файрвола: FAIL (получено: '${ip:-пусто}')"; return 1; }
  for n in 1 2; do
    st=$(r $n 'ufw status | head -n1'); f2=$(r $n 'systemctl is-active fail2ban'); tm=$(r $n 'pgrep -f "[u]fw-safety.sh" | wc -l')
    log "Сервер $n: ufw=$st | fail2ban=$f2 | страховых таймеров: $tm"
    [ "$st" = "Status: active" ] && [ "$f2" = active ] && [ "$tm" = 0 ] || { log "СТОП: итоговая проверка защиты сервера $n не пройдена"; return 1; }
  done
}

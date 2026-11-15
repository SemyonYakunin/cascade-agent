# stage_passwd.sh: этап 8, смена паролей root (сначала сервер 2, затем сервер 1)
declare -A NEWPW PWSTATE

gen_pass() { openssl rand -base64 36 | tr -d '/+=\n' | cut -c1-24; }

set_pass() {
  ensure "$1" || return 1
  printf 'root:%s\n' "$2" | ssh $SSH_BASE -o BatchMode=yes -o ControlPath="$(_cm $1)" -p "${PORT[$1]}" "root@${HOST[$1]}" 'chpasswd'
}

check_pass() {
  SSHPASS="$2" sshpass -e ssh $SSH_BASE -o PubkeyAuthentication=no -o ControlPath=none -o ControlMaster=no \
    -o ConnectTimeout=10 -p "${PORT[$1]}" "root@${HOST[$1]}" 'echo PW_OK' 2>/dev/null
}

print_passwords() {
  local n any=0
  for n in 1 2; do [ -n "${NEWPW[$n]:-}" ] && any=1; done
  [ $any = 1 ] || return 0
  echo
  echo "════════ НОВЫЕ ПАРОЛИ ROOT (показаны один раз, в журнал не пишутся) ════════"
  for n in 1 2; do
    [ -n "${NEWPW[$n]:-}" ] && echo "Сервер $n (${HOST[$n]}): ${NEWPW[$n]}   [${PWSTATE[$n]}]"
  done
  echo "Сохраните их в менеджере паролей."
  echo
}

stage_passwd() {
  local n out
  for n in 2 1; do
    NEWPW[$n]=$(gen_pass)
    [ ${#NEWPW[$n]} -ge 20 ] || { log "СТОП: не удалось сгенерировать пароль"; unset "NEWPW[$n]"; return 1; }
    PWSTATE[$n]="не подтверждён"
    set_pass $n "${NEWPW[$n]}" || { log "СТОП: сервер $n: команда смены пароля вернула ошибку, пароль не менялся"; unset "NEWPW[$n]"; return 1; }
    out=$(check_pass $n "${NEWPW[$n]}")
    if [ "$out" != PW_OK ]; then
      log "Сервер $n: новый пароль не прошёл проверку, повторяю через живую сессию"
      set_pass $n "${NEWPW[$n]}"; sleep 2
      out=$(check_pass $n "${NEWPW[$n]}")
    fi
    if [ "$out" != PW_OK ]; then
      log "Сервер $n: диагностика (SSH-конфигурацию без вашего согласия не меняю):"
      r $n 'passwd -S root; grep -ihE "^\s*(PasswordAuthentication|PermitRootLogin)" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null' | sed 's/^/    /' | tee -a "$LOG"
      KEEP=1
      log "СТОП: новый пароль сервера $n не подтверждён. Сессия оставлена открытой (/tmp/cm-$JOB_ID-$n, до 2 часов)."
      return 1
    fi
    PWSTATE[$n]="проверен"
    if [ -z "$(check_pass $n "${PASS[$n]}")" ]; then log "Сервер $n: новый пароль принят, старый больше не работает: PASS"
    else log "Сервер $n: новый пароль принят, но старый тоже принимается (проверьте настройки): ВНИМАНИЕ"; fi
    PASS[$n]="${NEWPW[$n]}"
  done
  log "Пароли обоих серверов сменены и проверены"
}

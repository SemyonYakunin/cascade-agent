#!/bin/bash
# final.sh: финал для уже настроенной пары: проверка ссылок, выдача, смена паролей
BASE_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
for f in lib stage_passwd; do source "$BASE_DIR/$f.sh"; done
HOST[1]=$S1_HOST; PORT[1]=${S1_PORT:-22}; PASS[1]=$S1_PASS
HOST[2]=$S2_HOST; PORT[2]=${S2_PORT:-22}; PASS[2]=$S2_PASS
init_job
trap '[ -n "${KEEP:-}" ] || disconnect; unset S1_PASS S2_PASS PASS SSHPASS NEWPW LINKS' EXIT
log "Задание $JOB_ID, журнал: $LOG"
connect 1 || exit 1; connect 2 || exit 1
mapfile -t NAMES < <(r 1 'source /root/vpn-funcs.sh; list_users')
[ ${#NAMES[@]} -ge 1 ] || { log "СТОП: на сервере 1 нет пользователей"; exit 1; }
SNI1=$(r 1 "jq -r '.inbounds[] | select(.streamSettings.realitySettings != null) | .streamSettings.realitySettings.serverNames[0]' /usr/local/etc/xray/config.json")
SNI2=$(r 2 "jq -r '.inbounds[] | select(.streamSettings.realitySettings != null) | .streamSettings.realitySettings.serverNames[0]' /usr/local/etc/xray/config.json")
log "Пользователи: ${NAMES[*]} | сайты маскировки: сервер 1 = $SNI1, сервер 2 = $SNI2"
LINKS=(); bad=0
for k in "${!NAMES[@]}"; do
  L=$(r 1 "source /root/vpn-funcs.sh; mklink ${NAMES[$k]} ${HOST[1]}")
  case "$L" in vless://*) ;; *) log "СТОП: ссылка ${NAMES[$k]} не собралась"; exit 1;; esac
  LINKS+=("$L")
  if [ -z "${SKIP_EXT:-}" ]; then
    res=$(ext_check "$L" $((10810+k)))
    [ "$res" = "${HOST[2]}" ] || { sleep 3; res=$(ext_check "$L" $((10810+k))); }
    log "  ${NAMES[$k]}: проверка настоящим клиентом: $res"
    [ "$res" = SKIP ] || [ "$res" = "${HOST[2]}" ] || bad=1
  fi
done
[ $bad = 0 ] || { log "СТОП: внешняя проверка ссылок не прошла (пароли не менялись)"; exit 12; }
echo; echo "════════ ССЫЛКИ (показаны один раз, в журнал не пишутся) ════════"
for k in "${!NAMES[@]}"; do echo "${NAMES[$k]}:"; echo "${LINKS[$k]}"; echo; done
echo "Сервер 1 (вход): ${HOST[1]}, сайт маскировки $SNI1"
echo "Сервер 2 (выход): ${HOST[2]}, сайт маскировки $SNI2"
echo "Проверка на устройстве: https://api.ipify.org должен показать ${HOST[2]}."
echo
read -r -p "Когда клиент работает, напишите  работает  и нажмите Enter (иначе пароли останутся прежними): " ans
case "${ans,,}" in
  работает|yes|да)
    stage_passwd; rc=$?
    print_passwords
    [ $rc = 0 ] || { log "Смена паролей остановлена, см. выше"; exit 10; }
    log "Готово. Доступ агента к серверам закрыт." ;;
  *) log "Пароли не менялись. Сменить позже: SCRIPT=passwd.sh ./run.sh" ;;
esac

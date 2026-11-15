#!/bin/bash
# full.sh: полный цикл. Вход (переменные): S1_HOST S1_PASS [S1_PORT] S2_HOST S2_PASS [S2_PORT] N_USERS [TZ_OFFSET] [FORCE_RU] [SKIP_EXT]
BASE_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
for f in lib preflight stage_prep stage_net stage_xray stage_cascade stage_users stage_routing stage_protect stage_passwd; do source "$BASE_DIR/$f.sh"; done
for v in S1_HOST S1_PASS S2_HOST S2_PASS; do [ -n "${!v:-}" ] || { echo "Нет переменной $v"; exit 2; }; done
HOST[1]=$S1_HOST; PORT[1]=${S1_PORT:-22}; PASS[1]=$S1_PASS
HOST[2]=$S2_HOST; PORT[2]=${S2_PORT:-22}; PASS[2]=$S2_PASS
RES=()
print_res() { echo; echo "──── Итог по этапам ────"; printf '%s\n' "${RES[@]}"; }
ok()   { RES+=("PASS  $1"); }
stop() { RES+=("СТОП  $1"); log "СТОП: $1"; print_res; exit "$2"; }

ensure_v6() {
  local n
  for n in 1 2; do
    [ -n "$(get_v6 $n)" ] || { log "Сервер $n: нет IPv6, включаю настройки"; rs $n < "$BASE_DIR/ipv6_remote.sh" >/dev/null; sleep 10; }
  done
}

init_job
trap '[ -n "${KEEP:-}" ] || disconnect; unset S1_PASS S2_PASS PASS SSHPASS NEWPW LINKS' EXIT
log "Задание $JOB_ID, журнал: $LOG"
connect 1 || exit 1
connect 2 || exit 1

preflight   || stop "проверка серверов" 3;                 ok "Проверка серверов"
stage_prep  || stop "обновление и подготовка" 4;           ok "Обновление и пакеты"
ensure_v6
stage_net_check || log "IPv6 между серверами не подтверждён, это не ошибка: каскад пойдёт по IPv4"
V6[1]=$(get_v6 1); V6[2]=$(get_v6 2)
stage_xray    || stop "установка Xray" 6;                  ok "Xray на обоих серверах"
stage_cascade || stop "сборка каскада" 7;                  ok "Каскад ($CASC_MODE)"
stage_users   || stop "пользователи и проверка цепочки" 8; ok "Пользователи и самопроверка цепочки"
stage_routing || stop "маршрутизация и геоданные" 11;      ok "Маршрутизация и автообновление геоданных"
stage_protect || stop "fail2ban и файрвол" 9;              ok "fail2ban и файрвол"

if [ -z "${SKIP_EXT:-}" ]; then
  log "Проверка каждой ссылки настоящим клиентом (с управляющей машины, файрвол уже включён)"
  bad=0
  for k in "${!NAMES[@]}"; do
    res=$(ext_check "${LINKS[$k]}" $((10810+k)))
    [ "$res" = "${HOST[2]}" ] || { sleep 3; res=$(ext_check "${LINKS[$k]}" $((10810+k))); }
    log "  ${NAMES[$k]}: $res"
    [ "$res" = SKIP ] && continue
    [ "$res" = "${HOST[2]}" ] || bad=1
  done
  [ $bad = 0 ] || stop "внешняя проверка ссылок не прошла (пароли не менялись; серверы настроены, повтор: SCRIPT=final.sh ./run.sh)" 12
  ok "Внешняя проверка ссылок"
fi
print_res

echo; echo "════════ ССЫЛКИ (показаны один раз, в журнал не пишутся) ════════"
for k in "${!NAMES[@]}"; do echo "${NAMES[$k]}:"; echo "${LINKS[$k]}"; echo; done
echo "Сервер 1 (вход): ${HOST[1]}, страна ${C1:-?}, сайт маскировки $SNI1"
echo "Сервер 2 (выход): ${HOST[2]}, страна ${C2:-?}, сайт маскировки $SNI2"
echo "Клиент с поддержкой XHTTP: v2rayN, v2rayNG, Streisand, Happ."
echo "Проверка на устройстве: https://api.ipify.org должен показать ${HOST[2]}."
echo "Если не подключается, проверьте свою сеть (200 или 302 = сеть пропускает):"
echo "  curl -s -o /dev/null -m 10 --resolve $SNI1:443:${HOST[1]} -w 'код=%{http_code}\n' https://$SNI1"
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

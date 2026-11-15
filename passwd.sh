#!/bin/bash
# passwd.sh: только смена паролей обоих серверов
BASE_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
for f in lib stage_passwd; do source "$BASE_DIR/$f.sh"; done
HOST[1]=$S1_HOST; PORT[1]=${S1_PORT:-22}; PASS[1]=$S1_PASS
HOST[2]=$S2_HOST; PORT[2]=${S2_PORT:-22}; PASS[2]=$S2_PASS
init_job
trap '[ -n "${KEEP:-}" ] || disconnect; unset S1_PASS S2_PASS PASS SSHPASS NEWPW' EXIT
log "Задание $JOB_ID, журнал: $LOG"
connect 1 || exit 1; connect 2 || exit 1
stage_passwd; rc=$?
print_passwords
[ $rc = 0 ] || { log "Остановлено на смене паролей"; exit 10; }
log "Пароли сменены"

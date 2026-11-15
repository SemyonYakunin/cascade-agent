#!/bin/bash
# inspect.sh: осмотр двух серверов (только чтение)
BASE_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$BASE_DIR/lib.sh"
HOST[1]=$S1_HOST; PORT[1]=${S1_PORT:-22}; PASS[1]=$S1_PASS
HOST[2]=$S2_HOST; PORT[2]=${S2_PORT:-22}; PASS[2]=$S2_PASS
init_job
trap 'disconnect; unset S1_PASS S2_PASS PASS SSHPASS' EXIT
connect 1 || exit 1; connect 2 || exit 1
for n in 1 2; do log "══ Осмотр сервера $n (${HOST[$n]}) ══"; rs $n < "$BASE_DIR/inspect_remote.sh" | tee -a "$LOG"; done

#!/bin/bash
# lib.sh: задание, подключение, запуск команд на серверах
declare -A HOST PORT PASS

init_job() {
  JOB_ID="$(date +%m%d-%H%M%S)-$RANDOM"
  JOB_DIR="$BASE_DIR/jobs/$JOB_ID"
  mkdir -p "$JOB_DIR"; chmod 700 "$BASE_DIR/jobs" "$JOB_DIR"
  LOG="$JOB_DIR/job.log"; : > "$LOG"; chmod 600 "$LOG"
  SSH_BASE="-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$JOB_DIR/known_hosts -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o ConnectTimeout=15 -o LogLevel=ERROR"
}

log() { echo "[$(date +%T)] $*" | tee -a "$LOG"; }

connect() {
  local n=$1 rc
  SSHPASS="${PASS[$n]}" sshpass -e ssh $SSH_BASE -o PubkeyAuthentication=no \
    -o ControlMaster=yes -o ControlPath="/tmp/cm-$JOB_ID-$n" -o ControlPersist=2h \
    -p "${PORT[$n]}" -fN "root@${HOST[$n]}" 2>"$JOB_DIR/conn$n.err"
  rc=$?
  if [ $rc -ne 0 ]; then
    case $rc in
      5) log "Сервер $n: пароль не принят" ;;
      255) log "Сервер $n: нет связи (адрес, порт ${PORT[$n]}, бан fail2ban?)" ;;
      *) log "Сервер $n: ошибка подключения, код $rc" ;;
    esac
    return 1
  fi
  r "$n" true && log "Сервер $n (${HOST[$n]}): подключено"
}

# выполнить команду на сервере n
r()  { local n=$1; shift; ssh -n $SSH_BASE -o ControlPath="/tmp/cm-$JOB_ID-$n" -p "${PORT[$n]}" "root@${HOST[$n]}" "unset HISTFILE; $*"; }
# выполнить скрипт со стандартного ввода на сервере n
rs() { local n=$1; ssh $SSH_BASE -o ControlPath="/tmp/cm-$JOB_ID-$n" -p "${PORT[$n]}" "root@${HOST[$n]}" 'unset HISTFILE; bash -s'; }
# положить файл на сервер: put N локальный_файл удалённый_путь
put() { local n=$1 src=$2 dst=$3; ssh $SSH_BASE -o ControlPath="/tmp/cm-$JOB_ID-$n" -p "${PORT[$n]}" "root@${HOST[$n]}" "cat > $dst" < "$src"; }
# открыт ли TCP-порт с сервера n: tcp N адрес порт
tcp() { r "$1" "timeout 6 bash -c '</dev/tcp/$2/$3' 2>/dev/null && echo open || echo closed"; }

disconnect() {
  for n in 1 2; do ssh -O exit -o ControlPath="/tmp/cm-$JOB_ID-$n" "root@${HOST[$n]}" 2>/dev/null; done
}

# код страны по IP (две заглавные буквы или пусто)
country_of() { curl -s -m 8 "https://ipinfo.io/$1/country" | tr -d '\n ' | grep -E '^[A-Z]{2}$'; }

# проверка vless-ссылки настоящим клиентом: печатает IP, который виден через ссылку (или FAIL / SKIP)
# ext_check ССЫЛКА ЛОКАЛЬНЫЙ_ПОРТ
ext_check() {
  local D="$BASE_DIR/xray-test" cfg pid ip
  [ -x "$D/xray" ] || { echo SKIP; return; }
  cfg=$(mktemp --suffix=.json)
  LINK="$1" CPORT="$2" python3 - > "$cfg" <<'PY'
import os, json
from urllib.parse import urlparse, parse_qs, unquote
u = urlparse(os.environ["LINK"].strip())
q = {k: v[0] for k, v in parse_qs(u.query).items()}
user = {"address": u.hostname, "port": u.port or 443, "id": u.username, "encryption": "none"}
cfg = {"log": {"loglevel": "warning"},
 "inbounds": [{"listen": "127.0.0.1", "port": int(os.environ["CPORT"]), "protocol": "socks", "settings": {"udp": False}}],
 "outbounds": [{"protocol": "vless", "settings": user,
  "streamSettings": {"network": q.get("type", "tcp"), "security": q.get("security", "none"),
   "realitySettings": {"serverName": q.get("sni", ""), "fingerprint": q.get("fp", "chrome"),
     "publicKey": q.get("pbk", ""), "shortId": q.get("sid", ""), "spiderX": unquote(q.get("spx", "/"))},
   "xhttpSettings": {"path": unquote(q.get("path", "/")), "mode": q.get("mode", "auto")}}}]}
print(json.dumps(cfg))
PY
  "$D/xray" run -config "$cfg" >/dev/null 2>&1 </dev/null &
  pid=$!; sleep 3
  ip=$(curl -s --socks5-hostname 127.0.0.1:$2 -m 20 https://api.ipify.org)
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
  shred -u "$cfg" 2>/dev/null || rm -f "$cfg"
  echo "${ip:-FAIL}"
}

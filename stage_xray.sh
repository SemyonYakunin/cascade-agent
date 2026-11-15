# stage_xray.sh: этап 3, установка Xray на оба сервера
stage_xray() {
  local n i fails=0 out
  ( cd "$BASE_DIR/vendor" && sha256sum -c SHA256SUMS >/dev/null 2>&1 ) \
    || { log "СТОП: установщики в vendor/ не совпадают с зафиксированными хэшами"; return 1; }
  for n in 1 2; do
    put $n "$BASE_DIR/vendor/xhttp-install" /root/xhttp-install
    put $n "$BASE_DIR/xray_remote.sh" /root/xray_remote.sh
    r $n "nohup bash /root/xray_remote.sh >/dev/null 2>&1 </dev/null & echo started" >/dev/null
  done
  log "Установка Xray запущена на обоих серверах"
  for i in $(seq 1 60); do
    [ -n "$(r 1 'cat /root/step.done 2>/dev/null')" ] && [ -n "$(r 2 'cat /root/step.done 2>/dev/null')" ] && break
    (( i % 4 == 0 )) && log "Установка идёт... ($((i/4)) мин)"
    sleep 15
  done
  sleep 3
  for n in 1 2; do
    out=$(rs $n < "$BASE_DIR/xray_check.sh")
    echo "$out" | sed "s/^/  сервер $n: /" | tee -a "$LOG"
    if echo "$out" | grep -q FAIL; then
      fails=1; log "Сервер $n: проверка не прошла. Строки с ошибками из журнала установки:"
      r $n 'grep -aiE "error|fail|ошибк|not found" /root/install.log | grep -v "vless://" | head -n 8' | tee -a "$LOG"
    fi
  done
  [ $fails = 0 ] || return 1
  for n in 1 2; do r $n 'shred -u /root/install.log /root/step.log /root/xhttp-install 2>/dev/null; true'; done
  log "Xray установлен и проверен на обоих серверах"
}

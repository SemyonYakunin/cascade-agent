# preflight.sh: проверка серверов (только чтение, ничего не меняет)
probe() {
  local n=$1 k v
  while IFS='=' read -r k v; do
    [[ $k =~ ^[A-Z0-9_]+$ ]] && declare -g "P${n}_${k}=${v}"
  done < <(rs "$n" < "$BASE_DIR/probe.sh")
}
g() { local v="P$1_$2"; echo "${!v:-?}"; }

preflight() {
  local n stop=0 ram disk v6
  [ "${HOST[1]}" = "${HOST[2]}" ] && { log "СТОП: сервер 1 и сервер 2 это один и тот же адрес"; return 1; }
  for n in 1 2; do probe $n; done
  for n in 1 2; do
    log "── Сервер $n (${HOST[$n]}) ──"
    log "ОС: $(g $n OS) | CPU: $(g $n ARCH) | RAM: $(g $n RAM_MB) МБ | диск свободно: $(g $n DISK_FREE_GB) ГБ"
    log "SSH-порт: $(g $n SSH_PORT) | сетевая карта: $(g $n IFACE)"
    v6=$(g $n V6); [ "$v6" = "?" ] && v6="нет"
    log "IPv6: $v6 | интернет по IPv6: $(g $n V6_PING)"
    log "Xray: $(g $n XRAY) | ufw: $(g $n UFW) | fail2ban: $(g $n F2B) | нужна перезагрузка: $(g $n REBOOT) | apt занят: $(g $n APT_BUSY)"
    [ "$(g $n XRAY)" = yes ] && { log "СТОП: на сервере $n уже есть Xray (конфиг, служба или процесс). Чужую установку не трогаю"; stop=1; }
    [ "$(g $n ARCH)" = x86_64 ] || log "ВНИМАНИЕ: архитектура $(g $n ARCH), проверялась только x86_64"
    case "$(g $n OS)" in *"Ubuntu 22"*|*"Ubuntu 24"*) ;; *) log "ВНИМАНИЕ: ОС не Ubuntu 22/24, нужно проверить вручную" ;; esac
    ram=$(g $n RAM_MB);  [[ $ram  =~ ^[0-9]+$ ]] && (( ram  < 700 )) && log "ВНИМАНИЕ: мало памяти"
    disk=$(g $n DISK_FREE_GB); [[ $disk =~ ^[0-9]+$ ]] && (( disk < 5 )) && { log "СТОП: меньше 5 ГБ свободного диска"; stop=1; }
  done
  if [ "$(g 1 V6_PING)" = ok ] && [ "$(g 2 V6_PING)" = ok ]; then
    log "Итог: IPv6 есть на обоих, будет проверено, проходит ли он между серверами"
  else
    log "Итог: IPv6 есть не везде, будем пробовать включить, иначе каскад по IPv4"
  fi
  return $stop
}

# stage_cascade.sh: этап 4, сайты маскировки по стране сервера и каскад
SNI_DEFAULT="www.samsung.com www.nvidia.com www.asus.com www.lenovo.com www.dell.com www.oracle.com www.amd.com www.cisco.com www.intel.com www.microsoft.com"
sni_list() {
  case "$1" in
    RU) echo "yandex.ru www.yandex.ru ya.ru www.mts.ru www.kinopoisk.ru www.ozon.ru www.wildberries.ru www.dns-shop.ru www.avito.ru" ;;
    LV) echo "www.lsm.lv www.delfi.lv www.ss.lv www.tvnet.lv www.lmt.lv www.tele2.lv www.rimi.lv" ;;
    LT) echo "www.lrt.lt www.delfi.lt www.15min.lt www.tele2.lt" ;;
    EE) echo "www.err.ee www.delfi.ee www.postimees.ee www.tele2.ee" ;;
    FI) echo "www.yle.fi www.hs.fi www.iltalehti.fi www.is.fi www.posti.fi" ;;
    DE) echo "www.spiegel.de www.zeit.de www.heise.de www.t-online.de www.web.de www.gmx.net www.bahn.de" ;;
    NL) echo "www.nu.nl www.tweakers.net www.bol.com www.marktplaats.nl www.rijksoverheid.nl www.nos.nl" ;;
    FR) echo "www.sfr.fr www.francetvinfo.fr www.laposte.fr www.free.fr www.ameli.fr www.leboncoin.fr www.lefigaro.fr" ;;
    PL) echo "www.onet.pl www.wp.pl www.interia.pl www.allegro.pl www.gov.pl" ;;
    GB) echo "www.bbc.co.uk www.gov.uk www.theguardian.com www.bt.com" ;;
    *)  echo "" ;;
  esac
}

# сначала сайты страны сервера, потом международные; выбирается самый быстрый с HTTP/2 + TLS 1.3
pick_sni() {  # pick_sni НОМЕР_СЕРВЕРА КОД_СТРАНЫ
  { echo "L='$(sni_list "$2")' D='$SNI_DEFAULT'"
    echo 'source /root/vpn-funcs.sh; x=""; [ -n "$L" ] && x=$(best_sni $L); [ -n "$x" ] || x=$(best_sni $D); echo "$x"'; } | rs "$1"
}

choose_addr() {
  local t6=closed t4
  [ -n "${V6[2]:-}" ] && t6=$(tcp 1 "${V6[2]}" 443)
  t4=$(tcp 1 "${HOST[2]}" 443)
  log "Порт 443 сервера 2 с сервера 1: по IPv6 = $t6, по IPv4 = $t4"
  if [ "$t6" = open ]; then CASC_ADDR="${V6[2]}"; CASC_MODE=ipv6
  elif [ "$t4" = open ]; then CASC_ADDR="${HOST[2]}"; CASC_MODE=ipv4
  else log "СТОП: сервер 1 не достаёт до порта 443 сервера 2 ни по IPv6, ни по IPv4"; return 1; fi
  log "Каскад пойдёт по: $CASC_MODE ($CASC_ADDR)"
}

stage_cascade() {
  local n out LINK ADDR_LINK
  choose_addr || return 1
  C1=$(country_of "${HOST[1]}"); C2=$(country_of "${HOST[2]}")
  log "Страны: сервер 1 = ${C1:-?}, сервер 2 = ${C2:-?}"
  for n in 1 2; do put $n "$BASE_DIR/vpn-funcs.sh" /root/vpn-funcs.sh; done
  put 1 "$BASE_DIR/vendor/cascad" /root/cascad

  SNI2=$(pick_sni 2 "$C2"); [ -n "$SNI2" ] || { log "СТОП: на сервере 2 не нашёлся сайт маскировки"; return 1; }
  out=$(r 2 "source /root/vpn-funcs.sh; set_sni $SNI2" | tail -n1)
  [ "$out" = active ] || { log "СТОП: не удалось поставить SNI на сервере 2: $out"; return 1; }
  log "Сервер 2: сайт маскировки $SNI2"

  SNI1=$(pick_sni 1 "$C1"); [ -n "$SNI1" ] || { log "СТОП: на сервере 1 не нашёлся сайт маскировки"; return 1; }
  out=$(r 1 "source /root/vpn-funcs.sh; set_sni $SNI1" | tail -n1)
  [ "$out" = active ] || { log "СТОП: не удалось поставить SNI на сервере 1: $out"; return 1; }
  log "Сервер 1: сайт маскировки $SNI1"

  out=$(r 1 "curl -4 -s -o /dev/null -m 10 --resolve $SNI2:443:${HOST[2]} -w 'verify=%{ssl_verify_result} code=%{http_code}' https://$SNI2")
  log "Проверка сервера 2 с сервера 1: $out"
  { echo "$out" | grep -q 'verify=0' && ! echo "$out" | grep -q 'code=000'; } \
    || { log "СТОП: сервер 2 не отвечает корректно на $SNI2 (сертификат или соединение)"; return 1; }

  ADDR_LINK=$CASC_ADDR; [ "${CASC_MODE:-}" = ipv6 ] && ADDR_LINK="[$CASC_ADDR]"
  LINK=$(r 2 "source /root/vpn-funcs.sh; FIRST=\$(list_users | head -n1); mklink \"\$FIRST\" \"$ADDR_LINK\"")
  case "$LINK" in vless://*) ;; *) log "СТОП: ссылка каскада не собралась"; return 1;; esac
  echo "$LINK" | grep -q "sni=$SNI2" || { log "СТОП: в ссылке каскада не тот sni"; return 1; }

  log "Запускаю каскад на сервере 1"
  out=$({ echo "export LINK='$LINK' CASC_ADDR='$CASC_ADDR' SNI2='$SNI2'"; cat "$BASE_DIR/cascade_remote.sh"; } | rs 1)
  unset LINK
  echo "$out" | sed 's/^/  сервер 1: /' | tee -a "$LOG"
  echo "$out" | grep -q "FAIL" && { log "СТОП: проверка каскада не прошла"; return 1; }
  echo "$out" | grep -q "ОШИБКА" && { log "СТОП: Xray отверг конфиг"; return 1; }
  r 2 'source /root/vpn-funcs.sh; xray_ok' | sed 's/^/  сервер 2: /' | tee -a "$LOG"
  log "Каскад собран и проверен"
}

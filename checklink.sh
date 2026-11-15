#!/bin/bash
# checklink.sh: проверка vless-ссылки настоящим клиентом (ссылка вводится скрыто)
BASE_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$BASE_DIR/lib.sh"
read -r -s -p "Вставьте vless-ссылку (не отображается): " LINK; echo
case "$LINK" in vless://*) ;; *) echo "Это не vless-ссылка"; exit 1;; esac
echo "Куда ведёт ссылка: $(LINK="$LINK" python3 -c 'import os;from urllib.parse import urlparse as p;u=p(os.environ["LINK"].strip());print(u.hostname, u.port)')"
echo "IP через ссылку: $(ext_check "$LINK" 10809)"
unset LINK

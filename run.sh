#!/bin/bash
# run.sh: точка входа. Спрашивает данные серверов (пароли не видны и не пишутся в файлы).
# SCRIPT=full.sh (по умолчанию) | final.sh | passwd.sh | reset.sh | inspect.sh
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$HERE"

# Запуск внутри tmux: обрыв SSH-соединения не убьёт процесс (вернуться: tmux attach -t cascade)
if [ -z "${TMUX:-}" ] && [ -z "${NO_TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s cascade "NO_TMUX=1 TZ_OFFSET='${TZ_OFFSET:-}' FORCE_RU='${FORCE_RU:-}' SKIP_EXT='${SKIP_EXT:-}' SCRIPT='${SCRIPT:-full.sh}' bash '$HERE/run.sh'; echo; read -r -p 'Нажмите Enter, чтобы закрыть окно (вместе с ним исчезнет и вывод): ' _"
fi

parse() {  # "ssh root@1.2.3.4 -p 2222" -> "1.2.3.4 2222"
  local s="$1" p=22 h="" w prev=""
  for w in $s; do
    if [ "$prev" = "-p" ]; then p=$w; prev=""; continue; fi
    case "$w" in
      ssh) ;;
      -p) prev="-p" ;;
      -p*) p=${w#-p} ;;
      -*) ;;
      *) h=${w#*@} ;;
    esac
  done
  echo "${h:-INVALID} $p"
}

if [ -z "${S1_HOST:-}" ]; then
  read -r -p "Сервер 1 (входящий, куда подключаются клиенты), как для ssh, например root@1.2.3.4: " t1
  read -r -s -p "Пароль сервера 1: " S1_PASS; echo
  read -r -p "Сервер 2 (выходной, откуда трафик выходит в интернет): " t2
  read -r -s -p "Пароль сервера 2: " S2_PASS; echo
  read -r S1_HOST S1_PORT < <(parse "$t1")
  read -r S2_HOST S2_PORT < <(parse "$t2")
fi
if [ -z "${N_USERS:-}" ]; then read -r -p "Сколько пользователей (ссылок) создать [1]: " N_USERS; fi
N_USERS=${N_USERS:-1}
if [ -z "${TZ_OFFSET:-}" ]; then read -r -p "Ваш часовой пояс относительно UTC для расписания обновления геоданных (Москва = 3) [0]: " TZ_OFFSET; fi
TZ_OFFSET=${TZ_OFFSET:-0}

[[ ${S1_PORT:-22} =~ ^[0-9]+$ && ${S2_PORT:-22} =~ ^[0-9]+$ && "$S1_HOST" =~ ^[A-Za-z0-9._:-]+$ && "$S2_HOST" =~ ^[A-Za-z0-9._:-]+$ && "$S1_HOST" != INVALID && "$S2_HOST" != INVALID ]] || { echo "Не удалось разобрать адрес или порт сервера"; exit 1; }
export S1_HOST S1_PORT S1_PASS S2_HOST S2_PORT S2_PASS N_USERS TZ_OFFSET FORCE_RU SKIP_EXT
exec "./${SCRIPT:-full.sh}"

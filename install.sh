#!/bin/bash
# install.sh: установка из клонированного репозитория. Запуск от root: bash install.sh
set -e
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SHA_X=45ec2de9e68c2d31ca5957614e86f6ba564f5bef
SHA_C=66b6f133da514434f1c5ecf2471977445a060a3a
H_X=01545a7f2c2a621eb2db6483b083f9d0aadbcac6edd4ec355e228489ba0131a8
H_C=74076fa18375abbe8a963b6266a3cb28674fd03acd08829d2f6f0234b0cd9a2a

[ "$(id -u)" = 0 ] || { echo "Запустите от root"; exit 1; }
. /etc/os-release
case "$ID" in ubuntu|debian) ;; *) echo "Нужна Ubuntu или Debian (у вас: $ID)"; exit 1;; esac
[ -f "$DIR/run.sh" ] && [ -f "$DIR/full.sh" ] || { echo "Запускайте install.sh из каталога репозитория"; exit 1; }

echo "[1/4] Устанавливаю пакеты"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y >/dev/null
apt-get install -y sshpass openssh-client jq curl wget python3 openssl tmux unzip ca-certificates psmisc >/dev/null

echo "[2/4] Скачиваю установщики Xray (версии зафиксированы, проверяю хэши)"
chmod +x "$DIR"/*.sh
mkdir -p "$DIR/vendor" "$DIR/jobs"; chmod 700 "$DIR/jobs"
cd "$DIR/vendor"
wget -q -O xhttp-install "https://raw.githubusercontent.com/ServerTechnologies/simple-xray-core/$SHA_X/xhttp-xray-install"
wget -q -O cascad "https://raw.githubusercontent.com/ServerTechnologies/cascade-for-x-ray/$SHA_C/cascad"
printf '%s  xhttp-install\n%s  cascad\n' "$H_X" "$H_C" > SHA256SUMS
sha256sum -c SHA256SUMS >/dev/null || { echo "ОШИБКА: установщики не совпали с хэшами, установка остановлена"; exit 1; }

echo "[3/4] Скачиваю клиент Xray для проверки ссылок"
mkdir -p "$DIR/xray-test"; cd "$DIR/xray-test"
case "$(uname -m)" in aarch64|arm64) Z=Xray-linux-arm64-v8a.zip;; *) Z=Xray-linux-64.zip;; esac
if wget -q -O x.zip "https://github.com/XTLS/Xray-core/releases/latest/download/$Z" && unzip -qo x.zip xray; then
  rm -f x.zip; ./xray version | head -n1
else
  rm -f x.zip; echo "ВНИМАНИЕ: клиент не скачался, внешняя проверка ссылок будет пропускаться"
fi

echo "[4/4] Проверка и команда запуска"
cd "$DIR"
for f in *.sh; do bash -n "$f" || { echo "ОШИБКА синтаксиса в $f"; exit 1; }; done
ln -sf "$DIR/run.sh" /usr/local/bin/cascade-vpn
echo "Готово. Версия $(cat "$DIR/VERSION"). Запуск: cascade-vpn"

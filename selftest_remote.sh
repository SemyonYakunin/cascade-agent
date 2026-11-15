# на сервере 1; ожидает переменную U (имя пользователя)
source /root/vpn-funcs.sh
IN='.inbounds[] | select(.streamSettings.realitySettings != null)'
UUID=$(jq -r --arg e "$U" "$IN | .settings.clients[] | select(.email==\$e) | .id" $CFG)
PBK=$(xray x25519 -i "$(jq -r "$IN | .streamSettings.realitySettings.privateKey" $CFG)" | grep -iE "public|password" | awk '{print $NF}')
SID=$(jq -r "$IN | .streamSettings.realitySettings.shortIds[0]" $CFG)
SNI1=$(jq -r "$IN | .streamSettings.realitySettings.serverNames[0]" $CFG)
cat > /tmp/client.json <<EOS
{"log":{"loglevel":"warning"},
 "inbounds":[{"listen":"127.0.0.1","port":10808,"protocol":"socks","settings":{"udp":false}}],
 "outbounds":[{"protocol":"vless","settings":{"address":"127.0.0.1","port":443,"id":"$UUID","encryption":"none"},
  "streamSettings":{"network":"xhttp","security":"reality",
   "realitySettings":{"serverName":"$SNI1","fingerprint":"chrome","publicKey":"$PBK","shortId":"$SID","spiderX":"/"},
   "xhttpSettings":{"path":"/","mode":"auto"}}}]}
EOS
nohup xray run -config /tmp/client.json > /tmp/client.log 2>&1 < /dev/null &
echo $! > /tmp/client.pid
sleep 3
IPOUT=$(timeout 30 curl -s --socks5-hostname 127.0.0.1:10808 -m 20 https://api.ipify.org)
echo "SELFTEST_IP=$IPOUT"
[ -n "$IPOUT" ] || tail -n 5 /tmp/client.log
kill $(cat /tmp/client.pid) 2>/dev/null; rm -f /tmp/client.json /tmp/client.log /tmp/client.pid

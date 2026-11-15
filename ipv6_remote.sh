IFACE=$(ip route show default | awk '{print $5; exit}')
cat > /etc/sysctl.d/99-ipv6-enable.conf <<EOS
net.ipv6.conf.$IFACE.disable_ipv6 = 0
net.ipv6.conf.$IFACE.accept_ra = 2
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.all.addr_gen_mode = 0
net.ipv6.conf.$IFACE.use_tempaddr = 0
EOS
rm -f /etc/sysctl.d/11-disable-ipv6.conf
sysctl --system >/dev/null 2>&1
echo "IPv6 настроен: accept_ra=$(sysctl -n net.ipv6.conf.$IFACE.accept_ra) forwarding=$(sysctl -n net.ipv6.conf.all.forwarding)"

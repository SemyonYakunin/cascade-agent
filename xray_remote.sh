export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
rm -f /root/step.done
bash /root/xhttp-install > /root/install.log 2>&1 < /dev/null
echo $? > /root/step.done

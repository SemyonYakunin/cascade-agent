#!/bin/bash
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
rm -f /root/step.done
main() {
  if [ -z "$(swapon --show)" ]; then
    fallocate -l 1G /swapfile || return 1
    chmod 600 /swapfile; mkswap /swapfile || return 1; swapon /swapfile || return 1
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
  apt-get -o DPkg::Lock::Timeout=600 update || return 1
  apt-get -o DPkg::Lock::Timeout=600 -y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef upgrade || return 1
  apt-get -o DPkg::Lock::Timeout=600 -y install jq wget curl python3 openssl ca-certificates || return 1
}
main > /root/step.log 2>&1
echo $? > /root/step.done

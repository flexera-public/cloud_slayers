#!/usr/bin/env bash

set -ex

if [ `lsb_release -is` == "Ubuntu" ]; then
  if [ `lsb_release -rs | grep -o '^[0-9]*'` == "14" ]; then
    apt-get install -y apparmor
    apt-get install -y docker.io
  elif [ `lsb_release -rs | grep -o '^[0-9]*'` == "12" ]; then
    apt-get install -y apt-transport-https apparmor
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
    echo "deb https://get.docker.com/ubuntu docker main" > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y lxc-docker
  fi
elif [ `lsb_release -is` == "CentOS" ] || [ `lsb_release -is` == "RedHat" ]; then
  if [ `lsb_release -rs | grep -o '^[0-9]*'` == "6" ]; then
    yum install -y docker-io
    chkconfig --add docker
    service docker start
  elif [ `lsb_release -rs | grep -o '^[0-9]*'` == "7" ]; then
    yum install -y docker e2fsprogs
    systemctl enable docker
    systemctl start docker
  fi
else
  echo "Unsupported distro"
fi

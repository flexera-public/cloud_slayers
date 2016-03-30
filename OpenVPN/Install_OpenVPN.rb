#!/bin/bash

set -ex

if [ -d /etc/apt ]; then
  sudo apt-get install -y openvpn
elif [ -d /etc/yum.repos.d ]; then
  yum install -y openvpn
else
  echo "unsupported distribution!"
  exit 1
fi

sudo /usr/bin/gem install s3
sudo /usr/bin/gem install right_api_client

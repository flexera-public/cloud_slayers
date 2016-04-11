#!/bin/bash
# ---
# RightScript Name: Install OpenVPN
# Description: (put your description here, it can be multiple lines using YAML syntax)
# Inputs: {}
# Attachments: []
# ...

set -ex

if [ -d /etc/apt ]; then
  sudo apt-get install -y openvpn
elif [ -d /etc/yum.repos.d ]; then
  yum install -y openvpn
else
  echo "unsupported distribution!"
  exit 1
fi

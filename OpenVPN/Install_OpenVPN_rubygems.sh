#!/bin/bash
# ---
# RightScript Name: Install OpenVPN Rubygems
# Description: (put your description here, it can be multiple lines using YAML syntax)
# Inputs: {}
# Attachments: []
# ...

set -ex

if [ -d /etc/apt ]; then
  sudo apt-get install -y openvpn rubygems
elif [ -d /etc/yum.repos.d ]; then
  yum install -y openvpn rubygems
else
  echo "unsupported distribution!"
  exit 1
fi

sudo /usr/bin/gem install s3
sudo /usr/bin/gem install right_api_client

#!/usr/bin/env bash

# RightScript Name: Run Puppet Agent
# Description: Run puppet agent and install if needed
# Packages: puppet
# Inputs:
#   PUPPET_SERVER:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: The puppet master server to which the puppet agent should connect.
#     Required: true
#     Advanced: true
#   DAEMONIZE:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: Whether to send the process into the background.
#     Required: no
#     Advanced: no
#   WAITFORCERT:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: How frequently puppet agent should ask for a signed certificate. Default 0
#     Required: no
#     Advanced: no
#   RUNINTERVAL:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: How often puppet agent applies the catalog. Default 30m
#     Required: no
#     Advanced: no
# ...

set -ex

args="--server $PUPPET_SERVER"

if [ ! -e /usr/bin/puppet ]; then
  echo "/usr/bin/puppet not found. Installing now."
  if [ -d /etc/apt ]; then
    RELEASE=`lsb_release  -cs`
    wget -P /tmp https://apt.puppetlabs.com/puppetlabs-release-$RELEASE.deb
    dpkg -i /tmp/puppetlabs-release-$RELEASE.deb
    apt-get update
    apt-get -y install puppet
  elif [ -d /etc/yum.repos.d ]; then
    RELEASE=`lsb_release -r | grep -o [0-9] | head -1`
    wget -P /tmp http://yum.puppetlabs.com/puppetlabs-release-el-$RELEASE.noarch.rpm
    rpm -i /tmp/puppetlabs-release-el-$RELEASE.noarch.rpm
    yum -y install puppet
  else
    echo "Unsupported distro"
    exit 1
  fi
  echo "Install complete"
fi

#If DAEMONIZE is set to a non-positive value, unset the variable
if [[ $DAEMONIZE == 0 || $DAEMONIZE == "false" ]]; then
  unset DAEMONIZE
fi

if [ -n "$DAEMONIZE" ] && [ -n "$RUNINTERVAL" ]; then
  args="$args --runinterval $RUNINTERVAL"
elif [ -z "$DAEMONIZE" ]; then
  args="$args --onetime --no-daemonize"
fi

if [ -n "$WAITFORCERT" ]; then
  args="$args --waitforcert $WAITFORCERT"
fi

puppet agent $args

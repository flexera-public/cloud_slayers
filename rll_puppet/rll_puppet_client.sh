#!/usr/bin/env bash

set -ex

ARGS="--server ${PUPPET_SERVER}"

if [ ! -e /usr/bin/puppet ]; then
  echo "/usr/bin/puppet not found. Installing now."
  if [ -d /etc/apt ]; then
    RELEASE=`lsb_release  -cs`
    wget -P /tmp https://apt.puppetlabs.com/puppetlabs-release-${RELEASE}.deb
    dpkg -i /tmp/puppetlabs-release-${RELEASE}.deb
    apt-get update
    apt-get -y install puppet
  elif [ -d /etc/yum.repos.d ]; then
    RELEASE=`lsb_release -r | grep -o [0-9] | head -1`
    wget -P /tmp http://yum.puppetlabs.com/puppetlabs-release-el-${RELEASE}.noarch.rpm
    rpm -i /tmp/puppetlabs-release-el-${RELEASE}.noarch.rpm
    yum -y install puppet
  else
    echo "Unsupported distro"
    exit 1
  fi
  echo "Install complete"
fi

#If DAEMONIZE is set to a negative value, unset the variable
if [[ ${DAEMONIZE} == 0 || ${DAEMONIZE} == "false" ]]; then
  unset DAEMONIZE
fi

#DAEMONIZE determines if puppet agent should run as a daemon
#RUNINTERVAL is how often puppet should check in with the puppet master
if [ -e "${DAEMONIZE}" ] && [ -e "${RUNINTERVAL}" ]; then
  ARGS="${ARGS} --runinterval ${RUNINTERVAL}"
elif [ -z "${DAEMONIZE}" ]; then
  ARGS="${ARGS} --onetime --no-daemonize"
fi

#WAITFORCERT is the amount of time to wait for signed cert from puppet master
#Set to 0 to fail on connection error
if [ -e "${WAITFORCERT}" ]; then
  ARGS="${ARGS} --waitforcert ${WAITFORCERT}"
fi

echo "Running: puppet agent ${ARGS}"

puppet agent ${ARGS}

#!/usr/bin/env bash

ARGS="--server $PUPPET_SERVER"

if [ ! -e /usr/bin/puppet ]; then
  echo "/usr/bin/puppet not found. Installing now."
  if [ -d /etc/apt ]; then
    RELEASE=`lsb_release  -cs | xargs echo -n`
    wget -P /tmp https://apt.puppetlabs.com/puppetlabs-release-${RELEASE}.deb
    dpkg -i /tmp/puppetlabs-release-${RELEASE}.deb
    apt-get update
    apt-get -y install puppet
  elif [ -d /etc/yum.repos.d ]; then
    RELEASE=`lsb_release -r | grep -o [0-9] | head -1 | xargs echo -n`
    wget -P /tmp http://yum.puppetlabs.com/puppetlabs-release-el-${RELEASE}.noarch.rpm
    rpm -i /tmp/puppetlabs-release-el-${RELEASE}.noarch.rpm
    yum -y install puppet
  else
    echo "Unsupported distro"
    exit 1
  fi
  echo "Install complete"
fi

if [[ $DAEMONIZE == 0 || $DAEMONIZE == "false" ]]; then
  unset DAEMONIZE
fi

if [ ! -z "$DAEMONIZE" ] && [ ! -z "$RUNINTERVAL" ]; then
  ARGS="${ARGS} --runinterval $RUNINTERVAL"
elif [ -z "$DAEMONIZE" ]; then
  ARGS="${ARGS} --onetime --no-daemonize"
fi

if [ ! -z "$WAITFORCERT" ]; then
  ARGS="${ARGS} --waitforcert ${WAITFORCERT}"
fi

echo "Running: puppet agent ${ARGS}"

puppet agent ${ARGS}

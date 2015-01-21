#!/bin/bash

set -ex

if [ -d /etc/apt ]; then
  apt-get install -y curl
elif [ -d /etc/yum.repos.d ]; then
  yum install -y curl
else
  echo "unsupported distribution!"
  exit 1
fi

install_chef(){
  if [[ -z $CHEF_VERSION ]]; then
    curl -L https://www.opscode.com/chef/install.sh | bash
  else
    curl -L https://www.opscode.com/chef/install.sh | bash -s -- -v $CHEF_VERSION
  fi

  if  [ $? -ne 0 ]; then
    echo "Error:  Chef failed to install"
    exit 1
  fi
}

create_chef_config_file(){
  if [[ ! -d /etc/chef ]]; then
    mkdir -p /etc/chef
  fi
  if [[ -z $CHEFNODENAME ]]; then
    CHEFNODENAME=`hostname -f`
  fi

  # Generate run list of roles
  for x in `echo $CHEFROLES |tr -d ' '| tr , '\n'`
  do
    ROLES+=" \"role[$x]\","
  done
  ROLES=$( sed 's/,$//' <<< $ROLES )
  echo $ROLES

  cat >/etc/chef/client.rb <<EOF
log_level                $LOGLEVEL
log_location             "$LOGLOCATION"
chef_server_url          "$CHEFSERVER"
validation_client_name   "$CHEFVALIDATIONNAME"
validation_key           "/etc/chef/validation_key.pem"
ssl_verify_mode          $CHEFSSLVERIFY
EOF
  chmod 0644 /etc/chef/client.rb
  cat > /etc/chef/runlist.json <<EOF
{
  "name": "$CHEFNODENAME",
  "normal": {
    "company": "$CHEFCOMPANYNAME",
    "tags": [ ]
    },
  "chef_environment": "$CHEFENVIRONMENT",
  "run_list": [ $ROLES ]
}
EOF
  chmod 0440 /etc/chef/runlist.json
  cat > /etc/chef/validation_key.pem <<EOF
$CHEFVALIDATIONKEY
EOF
  chmod 0600 /etc/chef/validation_key.pem
}

install_chef

create_chef_config_file

if  [ $? -ne 0 ]; then
  echo "Chef failed to be configured"
  exit 1
else
  chef-client -j /etc/chef/runlist.json -l debug
fi

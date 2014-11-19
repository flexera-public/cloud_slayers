#!/bin/bash

if [[ ! -f /usr/bin/curl ]]; then
  echo "Error: Please install curl"
  exit 1
fi

install_chef(){
  if [[ -z $CHEF_VERSION ]]; then
    curl -L https://www.opscode.com/chef/install.sh | bash
  else
    curl -L https://www.opscode.com/chef/install.sh | bash -s -- -v $CHEF_VERSION
  fi

  if  [ $? -ne 0 ]; then
    echo "Error:  Chef failed to instal"
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
  cat >/etc/chef/client.rb <<EOF
log_level              $LOGLEVEL
log_location             "$LOGLOCATION"
chef_server_url          "$CHEFSERVER"
validation_client_name   "$CHEFVALIDATIONNAME"
validation_key            /etc/chef/validation_key.pem
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
"run_list": [ ROLESTOBEFILLED ]
}" 
EOF
  chmod 0440 /etc/chef/runlist.json
  echo $CHEFVALIDATIONKEY > /etc/chef/validation_key.pem
  chmod 0600 /etc/chef/validation_key.pem
}

role_list_creation(){
  for x in `echo $CHEFROLES | tr , '\n'`
  do
    ROLE=" \\\"role[ $x ]\\\","
    ROLES=$ROLES$ROLE
  done
  CHEFROLESOUTPUT=${ROLES%,}
  COMMAND="sed -i 's/ROLESTOBEFILLED/${CHEFROLESOUTPUT}/g' /etc/chef/runlist.json"
  eval $COMMAND
}

install_chef

create_chef_config_file && role_list_creation

if  [ $? -ne 0 ]; then
  echo "Chef failed to be configured"
  exit 1
else
  chef-client -j /etc/chef/runlist.json
fi

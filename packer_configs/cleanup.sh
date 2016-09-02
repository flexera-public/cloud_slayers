#!/bin/bash -ex
#Regnerate machine-id on systemd vms
[[ -e /etc/machine-id ]] && sed -i -e 's/ExecStart.*/& --setup-machine-id/' /usr/lib/systemd/system/systemd-firstboot.service

if `which waagent &> /dev/null`; then
  sudo /usr/sbin/waagent -force -deprovision+user
else
  sudo rm -Rf  /var/lib/waagent/.rnd \
    /var/lib/waagent/GoalState.*.xml \
    /var/lib/waagent/ExtensionsConfig.*.xml \
    /var/lib/waagent/Certificates.xml \
    /var/lib/waagent/TransportCert.pem \
    /var/lib/waagent/SharedConfig.xml \
    /var/lib/waagent/HostingEnvironmentConfig.xml \
    /var/lib/waagent/ovf-env.xml \
    /var/lib/waagent/*.crt \
    /var/lib/waagent/Certificates.pem \
    /var/lib/waagent/Certificates.p7m \
    /var/lib/waagent/GoalState.*.xml \
    /var/lib/waagent/provisioned \
    /var/lib/waagent/TransportPrivate.pem \
    /var/lib/waagent/CustomData \
    /var/lib/waagent/ExtensionsConfig.*.xml \
    /var/lib/waagent/*.prv \
    /var/log/waagent.log \
    /root/.bash_history \
    /etc/resolv.conf \
    /etc/machine-id

  sudo rm -rf /var/lib/cloud/ /tmp/*
  sudo rm -f /var/log/cloud-init* /etc/udev/rules.d/70-persistent-net.rules
  sudo find /root -name authorized_keys -type f -exec rm -f {} \;
  sudo find /home -name authorized_keys -type f -exec rm -f {} \;
  sudo find /var/log -type f -exec cp /dev/null {} \;
  history -c
  sync
fi

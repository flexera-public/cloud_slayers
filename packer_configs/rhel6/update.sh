#!/bin/bash

if `which yum &> /dev/null`; then
  echo "Updating yum based system"
  sudo rm -fr /var/cache/yum/*
  sudo yum clean all
  sudo yum update -y
elsif `which apt-get &> /dev/null`; then
  echo "Updating debian based system"
  sudo apt-get update
  sudo apt-get dist-upgrade -y
else
  echo "Uknown package manager. No updates will run"
fi

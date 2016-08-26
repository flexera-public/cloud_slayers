#!/bin/bash

sudo rm -fr /var/cache/yum/*
sudo yum clean all
sudo yum update -y

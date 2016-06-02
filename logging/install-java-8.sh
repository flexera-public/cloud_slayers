#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: Install Java 8
# Description: Installs Java 8 for logging server
# Inputs: {}
# Attachments: []
# ...
/usr/bin/add-apt-repository -y ppa:webupd8team/javaa 
/usr/bin/apt-get update
/bin/echo debconf shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
/bin/echo debconf shared/accepted-oracle-license-v1-1 seen true |  /usr/bin/debconf-set-selections
/usr/bin/apt-get -y install oracle-java8-installer

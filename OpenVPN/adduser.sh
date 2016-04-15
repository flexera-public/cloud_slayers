#!/bin/bash
# ---
# RightScript Name: Adds qa_nightly user
# Description: < Adds required qa_nightly user for jump boxes
# Inputs:
#   HASHED_PASSWORD:
#     Category: Credentials
#     Input Type: single
#     Required: true
#     Advanced: false
# Attachments: []
# ...

password = $HASHED_PASSWORD

/bin/useradd -m qa_nightly -p $password
/bin/sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
/bin/sed -i '/PasswordAuthentication no/d' /etc/ssh/sshd_config

service sshd restart

#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: Install OpenVPN Client
# Description: (put your description here, it can be multiple lines using YAML syntax)
# Inputs:
#   CA_CRT:
#     Category: (put your input category here)
#     Description: (put your input description here, it can be multiple lines using
#       YAML syntax)
#     Input Type: single
#     Required: false
#     Advanced: false
#   HOSTNAME:
#     Category: (put your input category here)
#     Description: (put your input description here, it can be multiple lines using
#       YAML syntax)
#     Input Type: single
#     Required: false
#     Advanced: false
#   SERVER_CRT:
#     Category: (put your input category here)
#     Description: (put your input description here, it can be multiple lines using
#       YAML syntax)
#     Input Type: single
#     Required: false
#     Advanced: false
#   SERVER_IP:
#     Category: (put your input category here)
#     Description: (put your input description here, it can be multiple lines using
#       YAML syntax)
#     Input Type: single
#     Required: false
#     Advanced: false
#   SERVER_KEY:
#     Category: (put your input category here)
#     Description: (put your input description here, it can be multiple lines using
#       YAML syntax)
#     Input Type: single
#     Required: false
#     Advanced: false
# Attachments: []
# ...

set -ex

if [ -d /etc/apt ]; then
  sudo apt-get install -y openvpn
elif [ -d /etc/yum.repos.d ]; then
  yum install -y openvpn
else
  echo "unsupported distribution!"
  exit 1
fi

mkdir -p /etc/openvpn

#   Create Server Cert
cat <<EOF > /etc/openvpn/$HOSTNAME.crt
$SERVER_CRT
EOF
chmod 600 /etc/openvpn/$HOSTNAME.crt


# Create Server Key
cat <<EOF > /etc/openvpn/$HOSTNAME.key
$SERVER_KEY
EOF
chmod 600 /etc/openvpn/$HOSTNAME.key

# Create Server conf 
cat <<EOF > /etc/openvpn/server.conf
client
dev tun
proto udp
remote $SERVER_IP 1194
nobind
user nobody
group nobody
persist-key
persist-tun
ca ca.crt
cert $HOSTNAME.crt
key $HOSTNAME.key
;ns-cert-type server
cipher AES-256-CBC 
comp-lzo
verb 3
mute 20
EOF

# Create ca crt
cat <<EOF > /etc/openvpn/ca.crt
$CA_CRT
EOF
chmod 600 /etc/openvpn/ca.crt

service openvpn start

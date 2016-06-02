#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: Install Nginx
# Description: installs nginx to act as a reverse proxy fo kibana with a password
# Inputs:
#   NGINX_PASSWD:
#     Category: PASSWORD
#     Description: Password for nginx access
#     Input Type: single
#     Required: true
#     Advanced: false
# Attachments: []
# ...

/usr/bin/apt-get -y install nginx apache2-utils
/usr/bin/htpasswd -bc /etc/nginx/htpasswd.users rightscale $NGINX_PASSWD
/bin/rm /etc/nginx/sites-available/default
cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 80;

    server_name logserver.test.rightscale.com;

    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/htpasswd.users;

    location / {
        proxy_pass http://localhost:5601;
        proxy_http_version 1.1;
        #proxy_set_header Upgrade $http_upgrade;
        #proxy_set_header Connection 'upgrade';
        #proxy_set_header Host $host;
        #proxy_cache_bypass $http_upgrade;
    }
}
EOF
/usr/sbin/service nginx restart

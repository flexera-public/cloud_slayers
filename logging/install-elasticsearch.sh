#! /usr/bin/sudo /bin/bash

/usr/bin/wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | /usr/bin/apt-key add -
/bin/echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" | /usr/bin/tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
/usr/bin/apt-get update
/usr/bin/apt-get -y install elasticsearch

echo <<EOF > /etc/elasticsearch/elasticsearch.yml
path.data: /log/elasticsearch
path.logs: /log/elasticsearch
network.host: 0.0.0.0
http.port: 8125
EOF

/usr/sbin/service elasticsearch start
/usr/sbin/update-rc.d elasticsearch defaults 95 10

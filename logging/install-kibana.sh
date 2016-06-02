#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: Install Kibana
# Description: Installs Kibana and configures it for CloudSlayer use
# Inputs: {}
# Attachments: []
# ...

#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: Install Kibana
# Description: Installs Kibana and configures it for CloudSlayer use
# Inputs: {}
# Attachments: []
# ...

/usr/sbin/groupadd -g 1999 kibana
/usr/sbin/useradd -u 1999 -g 1999 kibana
/bin/mkdir -p /opt/kibana

cd /tmp
/usr/bin/wget https://download.elastic.co/kibana/kibana/kibana-4.3.0-linux-x64.tar.gz
/bin/tar xvf kibana-*.tar.gz && /bin/cp -R kibana-4.3.0-linux-x64/* /opt/kibana/
/bin/cp -R kibana-4.3.0-linux-x64/* /opt/kibana/
/bin/chown -R kibana: /opt/kibana

cd /etc/init.d 
/usr/bin/curl -o kibana https://gist.githubusercontent.com/thisismitch/8b15ac909aed214ad04a/raw/fc5025c3fc499ad8262aff34ba7fde8c87ead7c0/kibana-4.x-init
cd /etc/default 
/usr/bin/curl -o kibana https://gist.githubusercontent.com/thisismitch/8b15ac909aed214ad04a/raw/fc5025c3fc499ad8262aff34ba7fde8c87ead7c0/kibana-4.x-default

/bin/chmod +x /etc/init.d/kibana

cat <<EOF > /opt/kibana/config/kibana.yml
port: 5601
host: "localhost"
elasticsearch_url: "http://localhost:9200"
elasticsearch_preserve_host: true
kibana_index: ".kibana"
default_app_id: "discover"
request_timeout: 300000
shard_timeout: 0
verify_ssl: true
bundled_plugin_ids:
 - plugins/dashboard/index
 - plugins/discover/index
 - plugins/doc/index
 - plugins/kibana/index
 - plugins/markdown_vis/index
 - plugins/metric_vis/index
 - plugins/settings/index
 - plugins/table_vis/index
 - plugins/vis_types/index
 - plugins/visualize/index
EOF

/usr/sbin/update-rc.d kibana defaults 96 9
/usr/sbin/service kibana start

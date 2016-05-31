#! /usr/bin/sudo /bin/bash

/bin/echo 'deb http://packages.elasticsearch.org/logstash/2.1/debian stable main' | /usr/bin/tee /etc/apt/sources.list.d/logstash.list
/usr/bin/apt-get update
/usr/bin/apt-get install logstash

cat <<EOF > /etc/logstash/conf.d/10-consumelogs.conf
input {
  file {
    path => "/log/cinder/*.log"
    path => "/log/cloudplatform/*.log"
    path => "/log/esx/*.log"
    path => "/log/glance/*.log"
    path => "/log/keystone/*.log"
    path => "/log/neutron/*.log"
    path => "/log/nova/*.log"
    exclude => "*.gz"
       }
}
EOF

cat <<EOF > /etc/logstash/conf.d/20-logs.conf
filter {
  if [type] == "syslog" {
    grok {
      match => { "message" => "%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}" }
      add_field => [ "received_at", "%{@timestamp}" ]
      add_field => [ "received_from", "%{host}" ]
    }
    syslog_pri { }
    date {
      match => [ "syslog_timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
    }
  }
}
EOF

cat <<EOF > /etc/logstash/conf.d/30-elasticsearch-output.conf
output {
  elasticsearch_http { host => localhost }
  stdout { codec => rubydebug }
}
EOF

/usr/sbin/service logstash start
/usr/sbin/update-rc.d logstash defaults 96 9

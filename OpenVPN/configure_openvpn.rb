#!/usr/bin/env ruby

require 'fileutils'

$hostname=ENV['HOSTNAME']
$server_ip=ENV['SERVER_IP']
server_role=ENV['SERVER_ROLE']
client_config_routing=ENV['CLIENT_CONFIG_ROUTING']
ca_crt=ENV['CA_CRT']
dh_pem=ENV['DH_PEM']
server_crt=ENV['SERVER_CRT']
server_key=ENV['SERVER_KEY']


raise "ERROR: you must set hostname" unless $hostname 
raise "ERROR: you must set server_role" unless $server_role 
raise "ERROR: you must set server_ip" unless server_ip 
raise "ERROR: you must set ca_crt" unless ca_crt
raise "ERROR: you must set server_crt" unless server_crt
raise "ERROR: you must set server_key" unless server_key 
raise "ERROR: you must set client_config_routing" unless client_config_routing

$base_config="""proto udp
dev tun
nobind
user nobody
group nobody
persist-key
persist-tun
ca ca.crt
cert #{hostname}
key #{hostname}.key
;ns-cert-type server
cipher AES-256-CBC
comp-lzo
verb 3
mute 20
"""

$server_config"""local #{server_ip}
port 1194
management #{server_ip} 4505 /etc/openvpn/management-password
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
client-config-dir ccd
client-to-client
keepalive 10 120
status      /var/log/openvpn-status.log
log         /var/log/openvpn.log
verb 3
mute 20
"""

$client_config="remote 173.227.0.228 1194"

def generate_conf( server_role )
  if server_role == "server"
    config=$server_config+$baseconfig
  end
  if server_role == "client"
    config=$client_config+$base_config
  end
  return config
end
  
def install_conf_for_server( server_role )  
  unless File.directory?('/etc/openvpn')
    FileUtils.mkdir_p('/etc/openvpn')
  end
  if server_role == 'server'
    unless File.directory?('/etc/openvpn/ccd')
      FileUtils.mkdir_p('/etc/openvpn/ccd')
    end
    begin
      File.open('/etc/openvpn/server.conf', a+) {|f| f.write( generate_conf( server_role ) )}
    rescue
      puts "failed to create conf file"
    end
  end
end

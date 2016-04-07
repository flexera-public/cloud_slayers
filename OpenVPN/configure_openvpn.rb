#!/usr/bin/env ruby

require 'fileutils'

$hostname = ENV['HOSTNAME']
$server_ip = ENV['SERVER_IP']
server_role = ENV['SERVER_ROLE']
client_config_routing = ENV['CLIENT_CONFIG_ROUTING']
$ca_crt = ENV['CA_CRT']
$dh_pem = ENV['DH_PEM']
$server_crt = ENV['SERVER_CRT']
$server_key = ENV['SERVER_KEY']
management_password = ENV['MANAGEMENT_PASSWORD']

raise 'ERROR: you must set hostname' unless $hostname
raise 'ERROR: you must set server_role' unless $server_role
raise 'ERROR: you must set server_ip' unless server_ip
raise 'ERROR: you must set ca_crt' unless $ca_crt
raise 'ERROR: you must set server_crt' unless $server_crt
raise 'ERROR: you must set server_key' unless $server_key
raise 'ERROR: you must set client_config_routing' unless client_config_routing

$base_config = """proto udp
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

$server_config = """local #{server_ip}
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

$client_config = 'remote 173.227.0.228 1194'

def generate_conf(server_role)
  if server_role == 'server'
    config = $server_config + $baseconfig
  end
  if server_role == 'client'
    config = $client_config + $base_config
  end
  return config
end

def install_conf(server_role)
  config = generate_conf(server_role)
  unless File.directory?('/etc/openvpn')
    FileUtils.mkdir_p('/etc/openvpn')
  end
  if server_role == 'server'
    unless File.directory?('/etc/openvpn/ccd')
      FileUtils.mkdir_p('/etc/openvpn/ccd')
    end
    begin
      File.open('/etc/openvpn/server.conf', 'a+') { |f| f.write(config) }
    rescue
      puts 'Failed to create conf file'
    end
  end
  if server_role == 'client'
    begin
      File.open('/etc/openvpn/client.conf', 'a+') { |f| f.write(config) }
    rescue
      puts 'Failed to create conf file'
    end
  end
end

def install_certs(server_role)
  if server_role == 'server'
    begin 
      File.open('/etc/openvpn/dh.pem', 'a+') { |f| f.write($dh_pem) }
      File.chmod(0600, '/etc/openvpn/dh.pem')
    rescue
      puts 'Unable to create dh.pem file'
    end
  end
  begin
    File.open('/etc/openvpn/ca.crt', 'a+') { |f| f.write($ca_crt) }
    File.chmod(0600, '/etc/openvpn/ca.crt')
    File.open("/etc/openvpn/#{$hostname}.crt", 'a+') { |f| f.write($server_crt) }
    File.chmod(0600, "/etc/openvpn/#{$hostname}.crt")
    File.open("/etc/openvpn/#{$hostname}.key", 'a+') { |f| f.write($server_key) }
    File.chmod(0600, "/etc/openvpn/#{$hostname}.key")
  rescue
    puts 'Unable to create required cert files'
  end
end

def install_ccd_files(client_config_routing)
  client_config_routing.split(';').each do |route|
    host = route.split('=')
    begin
      File.open("/etc/openvpn/ccd/#{host[0]}", 'a+') { |f| f.write("iroute #{host[1].gsub(/,/, '\niroute ')}") }
    rescue
      puts 'Cannot create CCD files'
    end
  end
end

def install_management_password(management_password)
  begin
    File.open('/etc/openvpn/management-password', 'a+') { |f| f.write(management_password) }
    File.chmod(0600, '/etc/openvpn/management-password')
  rescue
    puts 'Cannot create management-password file'
  end
end

def enable_ip_forwarding
  begin
    contents = File.read('/etc/sysctl.conf')
    updated = contents.gsub(/net.ipv4.ip_forward = 0/, 'net.ipv4.ip_forward = 1')
    File.open('/etc/sysctl.conf', 'w') { |f| f.puts updated }
    `/sbin/sysctl -p /etc/sysctl.conf`
  rescue
    puts 'Unable to enable ip forwarding'
  end
end

def update_iptables
  begin
    `iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o ! tun0 -j MASQUERADE`
  rescue
    puts 'Unable to add iptables rule for masquerading'
  end
end

install_conf(server_role)
install_certs(server_role)
if server_role == 'server'
  install_ccd_files(client_config_routing)
  install_management_password(management_password)
end
enable_ip_forwarding
update_iptables

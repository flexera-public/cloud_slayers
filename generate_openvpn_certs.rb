#!/usr/bin/env ruby

# ---
# RightScript Name: Generate_OpenVPN_Certs
# Description: Generates host crts and config for openvpn
# Inputs:
#   HOSTNAME:
#     Input Type: single
#     Category: VPN
#     Description: Hostname
#     Required: true
#     Default: blank
#   S3KEY:
#     Input Type: single
#     Category: VPN
#     Description: S3KEY
#     Required: true
#     Default: cred:AWS_ACCESS_KEY_ID_PUBLISH
#   S3_SECRET:
#     Input Type: single
#     Category: VPN
#     Description: S3_SECRET
#     Required: true
#     Default: cred:AWS_SECRET_ACCESS_KEY_PUBLISH
#   CA_PASSWORD:
#     Input Type: single
#     Category: VPN
#     Description: CA_PASSWORD
#     Required: true
#     Default: cred:PASS
# ...

require 'rubygems'
require 's3'
require 'pty'
require 'expect'

hostname = ENV['HOSTNAME']
s3_key = ENV['S3KEY']
s3_secret = ENV['S3_SECRET']
ca_password = ENV['CA_PASSWORD']

@conf = "client
dev tun
proto udp
remote 173.227.0.228 1194
nobind
user nobody
group nobody
persist-key
persist-tun
ca ca.crt
cert #{hostname}.crt
key #{hostname}.key
;ns-cert-type server
cipher AES-256-CBC
comp-lzo
verb 3
mute 20"

def is_hostname_taken?(hostname)
  if File.file?("/etc/openvpn/easyrsa/pki/issued/#{hostname}.crt")
    puts 'Cert already exists'
    return TRUE
  end
  if File.file?("/etc/openvpn/easyrsa/pki/private/#{hostname}.key")
    puts 'Cert already exists'
    return TRUE
  end
  if File.file?("/etc/openvpn/easyrsa/pki/reqs/#{hostname}.req")
    puts 'Cert already exists'
    return TRUE
  end
  false
end

def create_server_cert(hostname, ca_password)
  Dir.chdir '/etc/openvpn/easy-rsa'
  begin
    PTY.spawn("/etc/openvpn/easy-rsa/easyrsa build-client-full #{hostname} nopass") do |easy_out, easy_in, _pid|
    easy_out.expect(/ca\.key\:/) { |r| easy_in.printf(ca_password) }
    easy_out.expect(/Data Base Updated/)
    end
    return TRUE
  rescue
    puts 'Something failed in the generation of the certificate'
    return FALSE
  end
end

def create_conf_bundle(hostname)
  `cp /etc/openvpn/easy-rsa/pki/issued/#{hostname}.crt /tmp && cp /etc/openvpn/easy-rsa/pki/private/#{hostname}.key /tmp && cp /etc/openvpn/ca.crt /tmp && cp /tmp/#{hostname}.conf /tmp`
  `cd /tmp && tar -cvzf /tmp/#{hostname}.tar.gz #{hostname}.crt #{hostname}.key #{hostname}.conf ca.crt`
  File.delete("/tmp/#{hostname}.crt")
  File.delete("/tmp/#{hostname}.key")
  File.delete("/tmp/#{hostname}.conf")
  File.delete('/tmp/ca.crt')
  return TRUE
rescue
  puts 'Bundle creation failed'
  false
end

def create_server_conf(hostname)
  if File.file?("/tmp/#{hostname}.conf")
    File.delete("/tmp/#{hostname}.conf")
  end
  File.open("/tmp/#{hostname}.conf", 'w+') { |f| f.write(@conf) }
  return TRUE
rescue
  puts 'Conf file creation failed'
  return FALSE
end

def deliver_package(hostname, s3_key, s3_secret)
  service = S3::Service.new(access_key_id: s3_key, secret_access_key: s3_secret)
  privatecloudtools = service.buckets.find('privatecloudtools')
  conffile = privatecloudtools.objects.build("OpenVPN_Certs/#{hostname}.tar.gz")
  conffile.content = open("/tmp/#{hostname}.tar.gz")
  conffile.save
  return TRUE
rescue
  puts 'Something went wrong with transfering config bundle to s3'
  false
end

if is_hostname_taken?(hostname)
  puts 'Hostname already taken'
  exit 1
end

if create_server_cert(hostname, ca_password) == FALSE
  puts 'Cert creation failed'
  exit 1
end

if create_server_conf(hostname) == FALSE
  puts 'Conf File creation failed'
  exit 1
end
if create_conf_bundle(hostname) == FALSE
  puts 'Creating cert/conf bundle failed'
  exit 1
end

if deliver_package(hostname, s3_key, s3_secret) == FALSE
  puts 'Uploading cert/conf bundle to S3 failed'
  exit 1
end

#!/usr/bin/env ruby

require 'pty'
require 'expect'

hostname = ENV['HOSTNAME']
ca_password = ENV['CA_PASSWORD']

def revoke_cert( hostname, ca_password )
  Dir.chdir '/etc/openvpn/easy-rsa'
  begin
    PTY.spawn("/etc/openvpn/easy-rsa/easyrsa revoke #{hostname}") do |easy_out, easy_in, _pid|
      easy_out.expect(/revocation\:/) {easy_in.print "yes\n" }
      easy_out.expect(/ca\.key\:/) { easy_in.print "#{ca_password}\n" }
    end 
  rescue
    puts 'Something failed in the generation of the certificate'
    return 1
  end 
end

def delete_certs( hostname )
  begin
    File.delete("/etc/openvpn/easy-rsa/pki/issued/#{hostname}.crt")
    File.delete("/etc/openvpn/easy-rsa/pki/private/#{hostname}.key")
    File.delete("/etc/openvpn/easy-rsa/pki/reqs/#{hostname}.req")
  rescue
    puts "Something failed in the deletion of the old keys"
    return 1
  end
end

if revoke_cert( hostname, ca_password )
  delete_certs( hostname )
end


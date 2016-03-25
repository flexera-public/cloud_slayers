#!/usr/bin/env ruby

require 'fileutils'
require 's3'
require 'right_api_client'

refresh_token = ENV['refresh_token']
hostname = ENV['hostname']
s3key = ENV['S3KEY']
s3_secret = ENV['S3_SECRET']


def generate_certs(hostname, refresh_token)
  begin
    @client = RightApi::Client.new(:api_url => 'https://us-4.rightscale.com', :account_id => '2901', :refresh_token => refresh_token )
    script_href = 'right_script_href=/api/right_scripts/558239004'
    server=@client.servers(:id => '1259193004').show
    server.show.current_instance.show.run_executable(script_href + "&inputs[HOSTNAME]=text:#{hostname}&inputs[CA_PASSWORD]=cred:CA_CREDENTIAL&inputs[S3KEY]=cred:AWS_ACCESS_KEY_ID_PUBLISH&inputs[S3_SECRET]=cred:AWS_SECRET_ACCESS_KEY_PUBLISH")
    sleep(10)
  rescue
    puts 'Something failed with the execution of the remote script.'
    return 1
  end
end

def get_cert_bundle(hostname, s3key, s3_secret)
  begin
    service = S3::Service.new(:access_key_id => s3key, :secret_access_key => s3_secret)
    privatecloudtools = service.buckets.find('privatecloudtools')
    object = privatecloudtools.objects.find("#{hostname}.tar.gz")
    File.open("/tmp/#{hostname}.tar.gz", 'w+') { |file| file.write(object.content) }
  rescue
    puts 'Failed to save conf bundle from S3'
    return 1
  end
end

def install_cert_bundle(hostname)
  begin
    `tar -xvf /tmp/#{hostname}.tar.gz -C /etc/openvpn`
  rescue
    puts 'Failed to instal cert bundle'
    return 1
  end
end

if generate_certs(hostname, refresh_token)
  if get_cert_bundle(hostname, s3key, s3_secret)
    install_cert_bundle
  end
end

#!/usr/bin/env ruby

require 'right_api_client';

@client = RightApi::Client.new(:email => "#{ENV['email']}", :password => "#{ENV['password']}", :account_id => "#{ENV['account_id']}")
servers = @client.servers.index(:filter => ["cloud_href==/api/clouds/#{ENV['cloud_id']}"])
servers.each do |server|
	puts "#{server.name}\t#{server.state}"
end

#!/usr/bin/env ruby

require 'sinatra'
set :bind, '0.0.0.0'

def process_leases
	guestinfo = File.open('/etc/guestinfo.sh', 'r')

	guestinfo.each do |line|
		if line =~ /ovf_rs_dhcp_Range="([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3},[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})"/
			(rstart, rend) = $1.split(/,/)
			$base = "#{rstart.split(/\./)[0]}.#{rstart.split(/\./)[1]}.#{rstart.split(/\./)[2]}"
			$first_fourth = "#{rstart.split(/\./)[3]}".to_i
			$last_fourth = "#{rend.split(/\./)[3]}".to_i
		end
	end

	guestinfo.close

	content = "<http><head><title>DHCP LEASES</title></head><body><table><tr align='center'><td><b>IP Address</b></td><td><b>MAC Address</b></td><td><b>Name</b></td><td><b>Time to Lease Expiration</b></td></tr>"
	($first_fourth..$last_fourth).each do |fourth|
		leasefile = File.open("/var/lib/misc/dnsmasq.leases", 'r')
		mac = ""
		name = ""
		expire_date = ""
		leasefile.each do |line|
			if line =~ /#{$base}.#{fourth}/
				expire_date= line.split(/\s/)[0].to_i
				mac=line.split(/\s/)[1]
				name=line.split(/\s/)[3]
			end
		end
		mac = "FREE" if mac == ""
		tte = "#{expire_date - Time.now().to_i} seconds" if expire_date != ""
		content = "#{content}<tr align='center'><td>#{$base}.#{fourth}</td><td>#{mac}</td><td>#{name}</td><td>#{tte}</td></tr>\n"
	end
	content = "#{content}</table></body></html>"
	return content
end


get "/what" do
end

get '/leases' do
	"#{process_leases}"
end

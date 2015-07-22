#!/usr/bin/env ruby

require 'cloudstack_ruby_client'

URL = "http://#{ARGV[0]}:8080/client/api"
API_KEY = ENV["API_KEY"]
API_SECRET = ENV["API_SECRET"]
TEMPLATE = ARGV[1]
client = CloudstackRubyClient::Client.new(URL, API_KEY, API_SECRET, false)

jobid = client.extract_template({:id => TEMPLATE, :mode => "HTTP_DOWNLOAD"})["jobid"]
sleep 5
result = client.query_async_job_result({:jobid => jobid})
url =  result["jobresult"]["template"]["url"]
name = result["jobresult"]["template"]["name"]
ext = url.split(//).last(3).join
name = 
`curl #{url} -o "#{name}.#{ext}"`

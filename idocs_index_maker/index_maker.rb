#!/usr/bin/ruby

require 'aws-sdk-v1'
require 'erb'
require 'json'

ENV["AWS_REGION"]='us-west-2'

s3 = AWS::S3.new( :access_key_id => ENV['access_key_id'], :secret_access_key => ENV['secret_access_key'])

bucket = s3.buckets[ENV['bucket']]

@template = File.read('/root/index.html.erb')

@contents = nil

bucket.objects.select{ |object| object.key =~ /.*?\/production\/swagger\.json/}.each do |object|
	object.key =~ /(.*?)\/production\/swagger\.json/
	repo_name = $1
	repo_title = JSON.parse(object.read)['info']['title']
	@contents = "#{@contents}                                    <li><a class=\"btn btn-default\" href=\"https://idocs.rightscale.com/swagger/#{repo_name}/production\"><span><img
                                            src=\"./icon-notes.svg\">#{repo_title}</span></a></li>
"
end

file = File.open('/tmp/idocs/swagger/index.html', 'w') 
file.write ERB.new(@template).result
file.close


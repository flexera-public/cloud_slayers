#!/usr/bin/env ruby

require 'rbvmomi'
vcenter_host, vcenter_user, vcenter_pass = ARGV

vim = RbVmomi::VIM.connect :host => vcenter_host, :user => vcenter_user, :password => vcenter_pass, :insecure => true
dc = vim.serviceInstance.find_datacenter

dc.hostFolder.children.each do |folder|
	folder.host.each do |host|
		puts host.name
	end
end

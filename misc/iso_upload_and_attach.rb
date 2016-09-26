#!/usr/bin/ruby

require 'rbvmomi'
require 'trollop'

opts = Trollop::options do
	opt :host, "vCenter address", :type => :string
	opt :password, "vCenter password", :type => :string
	opt :username, "vCenter username", :type => :string
	opt :cluster, "Cluster name", :type => :string
	opt :datastore, "Datastore name", :type => :string
	opt :vm, "VM name", :type => :string
	opt :iso, "CD image location", :type => :string
	opt :folder, "vCenter folder that contains VM", :type => :string
end



vim = RbVmomi::VIM.connect host: opts[:host], user: opts[:username], password: opts[:password], :insecure => true
dc = vim.rootFolder.children.first

ds = dc.datastore.select {|ds| ds.name == opts[:datastore]}.first

ds.upload("/vscale/#{opts[:iso]}", opts[:iso])


cluster = dc.hostFolder.children.select {|c| c.name == opts[:cluster]}.first

folder = dc.vmFolder.children.select{|item| item.name == opts[:folder]}.first
vm = folder.children.select{ |item| item.name == opts[:vm] }.first

devices = vm.config.hardware.device
operation = devices ? :edit : :add

type = RbVmomi::VIM::VirtualCdrom
controller_type = RbVmomi::VIM::VirtualIDEController
controller = devices.find{|device| device.is_a? controller_type }

device = type.new(connectable: RbVmomi::VIM::VirtualDeviceConnectInfo(allowGuestControl: true, startConnected: false, connected: false),key: -100,controllerKey: controller.key)
device.connectable.connected = true
device.connectable.startConnected = true

device.backing = RbVmomi::VIM.VirtualCdromIsoBackingInfo(:fileName => "[#{opts[:datastore]}] vscale/#{opts[:iso]}")

vm.ReconfigVM_Task(:spec => {:deviceChange => [{:operation => :add, :device => device}]})



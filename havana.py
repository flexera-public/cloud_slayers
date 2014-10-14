#! /usr/bin/python
import sys
import os
import time
import fcntl
import struct
import socket
import subprocess

# These are module names which are not installed by default.
# These modules will be loaded later after downloading
iniparse = None
psutil = None

service_tenant = None

def get_ip_address(ifname):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            return socket.inet_ntoa(fcntl.ioctl(s.fileno(),
                0x8915,  # SIOCGIFADDR
                struct.pack('256s', ifname[:15])
            )[20:24])
        except Exception:
            print "Cannot get IP Address for Interface %s" % ifname
            sys.exit(1)

def delete_file(file_path):
    if os.path.isfile(file_path):
        os.remove(file_path)
    else:
        print("Error: %s file not found" % file_path)

def write_to_file(file_path, content):
    open(file_path, "a").write(content)

def add_to_conf(conf_file, section, param, val):
    config = iniparse.ConfigParser()
    config.readfp(open(conf_file))
    if not config.has_section(section):
        config.add_section(section)
        val += '\n'
    config.set(section, param, val)
    with open(conf_file, 'w') as f:
        config.write(f)

def print_format(string):
    print "+%s+" %("-" * len(string))
    print "|%s|" % string
    "+%s+" %("-" * len(string))

def execute(command, display=False):
    print_format("Executing  :  %s " % command)
    process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if display:
        while True:
            nextline = process.stdout.readline()
            if nextline == '' and process.poll() != None:
                break
            sys.stdout.write(nextline)
            sys.stdout.flush()
        output, stderr = process.communicate()
        exitCode = process.returncode
    else:
        output, stderr = process.communicate()
        exitCode = process.returncode
    if (exitCode == 0):
        return output.strip()
    else:
        print "Error", stderr
        print "Failed to execute command %s" % command
        print exitCode, output
        raise Exception(output)


def execute_db_commands(mysql_ip, mysql_password, command):
    cmd = """mysql -h%s -uroot -p%s -e "%s" """ % (mysql_ip, mysql_password, command)
    output = execute(cmd)
    return output


def initialize_system():
    if not os.geteuid() == 0:
        sys.exit('Please re-run the script with root user')

    execute("apt-get clean" , True)
    execute("apt-get autoclean -y" , True)
    execute("apt-get update -y" , True)
    execute("apt-get install ubuntu-cloud-keyring python-setuptools python-iniparse python-psutil python-mysqldb -y", True)
    delete_file("/etc/apt/sources.list.d/havana.list")
    execute("echo deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/havana main >> /etc/apt/sources.list.d/havana.list")
    execute("apt-get update -y", True)

    global iniparse
    if iniparse is None:
        iniparse = __import__('iniparse')

    global psutil
    if psutil is None:
        psutil = __import__('psutil')
#=================================================================================
#==================   Components Installation Starts Here ========================
#=================================================================================

def install_rabbitmq():
    execute("apt-get install rabbitmq-server -y", True)
    execute("service rabbitmq-server restart", True)
    time.sleep(2)

def create_keystone_users( keystone_ip_address, keystone_ip_address_mgmt, nova_ip_address, nova_ip_address_mgmt, cinder_ip_address, cinder_ip_address_mgmt, glance_ip_address, glance_ip_address_mgmt, neutron_ip_address, neutron_ip_address_mgmt ):
    os.environ['SERVICE_TOKEN'] = 'ADMINTOKEN'
    os.environ['SERVICE_ENDPOINT'] = 'http://%s:35357/v2.0'% keystone_ip_address
    os.environ['no_proxy'] = "localhost,127.0.0.1,%s" % keystone_ip_address
    execute("env | grep OS")
    global service_tenant

    admin_tenant = execute("keystone tenant-create --name admin --description 'Admin Tenant' --enabled true |grep ' id '|awk '{print $4}'")
    admin_user = execute("keystone user-create --tenant_id %s --name admin --pass secret --enabled true|grep ' id '|awk '{print $4}'" % admin_tenant)
    admin_role = execute("keystone role-create --name admin|grep ' id '|awk '{print $4}'")
    execute("keystone user-role-add --user_id %s --tenant_id %s --role_id %s" % (admin_user, admin_tenant, admin_role))

    service_tenant = execute("keystone tenant-create --name service --description 'Service Tenant' --enabled true |grep ' id '|awk '{print $4}'")

    #keystone
    keystone_service = execute("keystone service-create --name=keystone --type=identity --description='Keystone Identity Service'|grep ' id '|awk '{print $4}'")
    execute("keystone endpoint-create --region region --service_id=%s --publicurl=http://%s:5000/v2.0 --internalurl=http://%s:5000/v2.0 --adminurl=http://%s:35357/v2.0" % (keystone_service, keystone_ip_address,keystone_ip_address_mgmt,keystone_ip_address_mgmt))

    #Glance
    glance_user = execute("keystone user-create --tenant_id %s --name glance --pass glance --enabled true|grep ' id '|awk '{print $4}'" % service_tenant)
    execute("keystone user-role-add --user_id %s --tenant_id %s --role_id %s" % (glance_user, service_tenant, admin_role))
    glance_service = execute("keystone service-create --name=glance --type=image --description='Glance Image Service'|grep ' id '|awk '{print $4}'")
    execute("keystone endpoint-create --region region --service_id=%s --publicurl=http://%s:9292/v2 --internalurl=http://%s:9292/v2 --adminurl=http://%s:9292/v2" % (glance_service, glance_ip_address, glance_ip_address_mgmt, glance_ip_address_mgmt) )

    #nova
    nova_user = execute("keystone user-create --tenant_id %s --name nova --pass nova --enabled true|grep ' id '|awk '{print $4}'" % service_tenant)
    execute("keystone user-role-add --user_id %s --tenant_id %s --role_id %s" % (nova_user, service_tenant, admin_role))
    nova_service = execute("keystone service-create --name=nova --type=compute --description='Nova Compute Service'|grep ' id '|awk '{print $4}'")
    execute("keystone endpoint-create --region region --service_id=%s --publicurl='http://%s:8774/v2/$(tenant_id)s' --internalurl='http://%s:8774/v2/$(tenant_id)s' --adminurl='http://%s:8774/v2/$(tenant_id)s'" % (nova_service, nova_ip_address, nova_ip_address_mgmt, nova_ip_address_mgmt) )

    #neutron
    neutron_user = execute("keystone user-create --tenant_id %s --name neutron --pass neutron --enabled true|grep ' id '|awk '{print $4}'" % service_tenant)
    execute("keystone user-role-add --user_id %s --tenant_id %s --role_id %s" % (neutron_user, service_tenant, admin_role))
    neutron_service = execute("keystone service-create --name=neutron --type=network  --description='OpenStack Networking service'|grep ' id '|awk '{print $4}'")
    execute("keystone endpoint-create --region region --service_id=%s --publicurl=http://%s:9696/ --internalurl=http://%s:9696/ --adminurl=http://%s:9696/" % (neutron_service, neutron_ip_address, neutron_ip_address_mgmt, neutron_ip_address_mgmt) )

    #Cinder
    cinder_user = execute("keystone user-create --tenant_id %s --name cinder --pass cinder --enabled true| grep ' id ' | awk '{print $4}'" % service_tenant)
    execute("keystone user-role-add --user_id %s --tenant_id %s --role_id %s" % (cinder_user, service_tenant, admin_role))
    cinder_service = execute("keystone service-create --name=cinder --type=volume --description='Cinder Volume Service' | grep ' id ' | awk '{print $4}'")
    execute("keystone endpoint-create --region region --service_id %s --publicurl 'http://%s:8776/v1/$(tenant_id)s' --adminurl 'http://%s:8776/v1/$(tenant_id)s' --internalurl 'http://%s:8776/v1/$(tenant_id)s'" % (cinder_service, cinder_ip_address, cinder_ip_address_mgmt, cinder_ip_address_mgmt) )

    #write a rc file
    openrc = "/root/openrc"
    delete_file(openrc)
    write_to_file(openrc, "export OS_USERNAME=admin\n")
    write_to_file(openrc, "export OS_PASSWORD=secret\n")
    write_to_file(openrc, "export OS_TENANT_NAME=admin\n")
    write_to_file(openrc, "export OS_AUTH_URL=http://%s:5000/v2.0\n" % keystone_ip_address)

def install_and_configure_keystone( keystone_ip_address, keystone_ip_address_mgmt, nova_ip_address, nova_ip_address_mgmt, cinder_ip_address, cinder_ip_address_mgmt, glance_ip_address, glance_ip_address_mgmt, mysql_ip, mysql_password ):
    keystone_conf = "/etc/keystone/keystone.conf"
    template_conf = "/etc/keystone/default_catalog.templates"

    execute("apt-get install mysql-client -y")

    execute_db_commands( mysql_ip, mysql_password, "DROP DATABASE IF EXISTS keystone;" )
    execute_db_commands( mysql_ip, mysql_password, "CREATE DATABASE keystone;" )
    execute_db_commands( mysql_ip, mysql_password, "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'keystone';" )
    execute_db_commands( mysql_ip, mysql_password, "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'keystone';" )

    execute("apt-get install keystone -y", True)
    execute( "echo '[TEST]' > /etc/keystone/default_catalog.templates")

    add_to_conf( keystone_conf, "DEFAULT", "admin_token", "ADMINTOKEN")
    add_to_conf( keystone_conf, "DEFAULT", "admin_port", "35357")
    add_to_conf( keystone_conf, "DEFAULT", "public_endpoint", "http://{0}:\%(public_port)s/".format(keystone_ip_address))
    add_to_conf( keystone_conf, "DEFAULT", "admin_endpoint", "http://{0}:\%(admin_port)s/".format(keystone_ip_address_mgmt))
    add_to_conf( keystone_conf, "sql", "connection", "mysql://keystone:keystone@%s/keystone" % mysql_ip)

    add_to_conf( template_conf, "TEST", "catalog.region.identity.publicURL" , "http://%s:$(public_port)s/v2.0" % keystone_ip_address )
    add_to_conf( template_conf, "TEST", "catalog.region.identity.adminURL" , "http://%s:$(admin_port)s/v2.0" % keystone_ip_address_mgmt )
    add_to_conf( template_conf, "TEST", "catalog.region.identity.internalURL" , "http://%s:$(public_port)s/v2.0" % keystone_ip_address_mgmt )
    add_to_conf( template_conf, "TEST", "catalog.region.identity.name" , "Identity Service" )

    add_to_conf( template_conf, "TEST", "catalog.region.compute.publicURL" , "http://%s:$(compute_port)s/v1.1/$(tenant_id)s" % nova_ip_address )
    add_to_conf( template_conf, "TEST", "catalog.region.compute.adminURL" , "http://%s:$(compute_port)s/v1.1/$(tenant_id)s" % nova_ip_address_mgmt )
    add_to_conf( template_conf, "TEST", "catalog.region.compute.internalURL" , "http://%s:$(compute_port)s/v1.1/$(tenant_id)s" % nova_ip_address_mgmt )
    add_to_conf( template_conf, "TEST", "catalog.region.compute.name" , "Compute Service" )

    add_to_conf( template_conf, "TEST", "catalog.region.volume.publicURL" , "http://%s:8776/v1/$(tenant_id)s" % cinder_ip_address )
    add_to_conf( template_conf, "TEST", "catalog.region.volume.adminURL" , "http://%s:8776/v1/$(tenant_id)s" % cinder_ip_address_mgmt )
    add_to_conf( template_conf, "TEST", "catalog.region.volume.internalURL" , "http://%s:8776/v1/$(tenant_id)s" % cinder_ip_address_mgmt )
    add_to_conf( template_conf, "TEST", "catalog.region.volume.name" , "Volume Service" )

    add_to_conf( template_conf, "TEST", "catalog.region.ec2.publicURL" , "http://%s:8773/services/Cloud" % keystone_ip_address )
    add_to_conf( template_conf, "TEST", "catalog.region.ec2.adminURL" , "http://%s:8773/services/Admin" % keystone_ip_address_mgmt )
    add_to_conf( template_conf, "TEST", "catalog.region.ec2.internalURL" , "http://%s:8773/services/Cloud" % keystone_ip_address_mgmt )
    add_to_conf( template_conf, "TEST", "catalog.region.ec2.name" , "EC2 Service" )

    add_to_conf( template_conf, "TEST", "catalog.region.image.publicURL" , "http://%s:9292/v1" % glance_ip_address )
    add_to_conf( template_conf, "TEST", "catalog.region.image.adminURL" , "http://%s:9292/v1" % glance_ip_address_mgmt )
    add_to_conf( template_conf, "TEST", "catalog.region.image.internalURL" , "http://%s:9292/v1" % glance_ip_address_mgmt )
    add_to_conf( template_conf, "TEST", "catalog.region.image.name" , "Image Service" )

    execute( "sed -i 's/\[TEST\]//g' /etc/keystone/default_catalog.templates" )
    execute("keystone-manage db_sync")
    execute("service keystone restart", True)
    time.sleep(3)

def install_and_configure_glance( keystone_ip_address, mysql_ip, mysql_password ):
    glance_api_conf = "/etc/glance/glance-api.conf"
    glance_registry_conf = "/etc/glance/glance-registry.conf"
    glance_api_paste_conf = "/etc/glance/glance-api-paste.ini"
    glance_registry_paste_conf = "/etc/glance/glance-registry-paste.ini"

    execute("apt-get install mysql-client -y")

    execute_db_commands( mysql_ip, mysql_password,"DROP DATABASE IF EXISTS glance;")
    execute_db_commands( mysql_ip, mysql_password,"CREATE DATABASE glance;")
    execute_db_commands( mysql_ip, mysql_password,"GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'glance';")
    execute_db_commands( mysql_ip, mysql_password,"GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'glance';")

    execute("apt-get install glance -y", True)

    add_to_conf(glance_api_paste_conf, "filter:authtoken", "auth_host", keystone_ip_address)
    add_to_conf(glance_api_paste_conf, "filter:authtoken", "auth_port", "35357")
    add_to_conf(glance_api_paste_conf, "filter:authtoken", "auth_protocol", "http")
    add_to_conf(glance_api_paste_conf, "filter:authtoken", "admin_tenant_name", "service")
    add_to_conf(glance_api_paste_conf, "filter:authtoken", "admin_user", "glance")
    add_to_conf(glance_api_paste_conf, "filter:authtoken", "admin_password", "glance")

    add_to_conf(glance_registry_paste_conf, "filter:authtoken", "auth_host", keystone_ip_address)
    add_to_conf(glance_registry_paste_conf, "filter:authtoken", "auth_port", "35357")
    add_to_conf(glance_registry_paste_conf, "filter:authtoken", "auth_protocol", "http")
    add_to_conf(glance_registry_paste_conf, "filter:authtoken", "admin_tenant_name", "service")
    add_to_conf(glance_registry_paste_conf, "filter:authtoken", "admin_user", "glance")
    add_to_conf(glance_registry_paste_conf, "filter:authtoken", "admin_password", "glance")

    add_to_conf(glance_api_conf, "DEFAULT", "sql_connection", "mysql://glance:glance@%s/glance" % mysql_ip)
    add_to_conf(glance_api_conf, "paste_deploy", "flavor", "keystone")
    add_to_conf(glance_api_conf, "DEFAULT", "verbose", "true")
    add_to_conf(glance_api_conf, "DEFAULT", "debug", "true")
    add_to_conf(glance_api_conf, "DEFAULT", "db_enforce_mysql_charset", "false")

    add_to_conf(glance_registry_conf, "DEFAULT", "sql_connection", "mysql://glance:glance@%s/glance" % mysql_ip)
    add_to_conf(glance_registry_conf, "paste_deploy", "flavor", "keystone")
    add_to_conf(glance_registry_conf, "DEFAULT", "verbose", "true")
    add_to_conf(glance_registry_conf, "DEFAULT", "debug", "true")

    execute("glance-manage db_sync")

    execute("service glance-api restart", True)
    execute("service glance-registry restart", True)

def install_and_configure_nova( keystone_ip_address_mgmt, nova_ip_address, rabbit_ip_address_mgmt, glance_ip_address_mgmt, neutron_ip_address_mgmt, mysql_ip, mysql_password ):
    nova_conf = "/etc/nova/nova.conf"
    nova_paste_conf = "/etc/nova/api-paste.ini"

    execute("apt-get install mysql-client -y")

    execute_db_commands( mysql_ip, mysql_password, "DROP DATABASE IF EXISTS nova;" )
    execute_db_commands( mysql_ip, mysql_password, "CREATE DATABASE nova;" )
    execute_db_commands( mysql_ip, mysql_password, "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'nova';" )
    execute_db_commands( mysql_ip, mysql_password, "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'nova';" )

    execute( "apt-get install nova-api nova-cert nova-scheduler nova-conductor novnc nova-consoleauth nova-novncproxy -y", True )


    add_to_conf( nova_paste_conf, "filter:authtoken", "auth_host", keystone_ip_address_mgmt )
    add_to_conf( nova_paste_conf, "filter:authtoken", "auth_port", "35357" )
    add_to_conf( nova_paste_conf, "filter:authtoken", "auth_protocol", "http" )
    add_to_conf( nova_paste_conf, "filter:authtoken", "admin_tenant_name", "service" )
    add_to_conf( nova_paste_conf, "filter:authtoken", "admin_user", "nova" )
    add_to_conf( nova_paste_conf, "filter:authtoken", "admin_password", "nova" )


    add_to_conf( nova_conf, "DEFAULT", "logdir", "/var/log/nova" )
    add_to_conf( nova_conf, "DEFAULT", "lock_path", "/var/lib/nova" )
    add_to_conf( nova_conf, "DEFAULT", "root_helper", "sudo nova-rootwrap /etc/nova/rootwrap.conf" )
    add_to_conf( nova_conf, "DEFAULT", "verbose", "True" )
    add_to_conf( nova_conf, "DEFAULT", "debug", "True" )
    add_to_conf( nova_conf, "DEFAULT", "rabbit_host", rabbit_ip_address_mgmt )
    add_to_conf( nova_conf, "DEFAULT", "rpc_backend", "nova.rpc.impl_kombu" )
    add_to_conf( nova_conf, "DEFAULT", "sql_connection", "mysql://nova:nova@%s/nova" % mysql_ip )
    add_to_conf( nova_conf, "DEFAULT", "glance_api_servers", "%s:9292" % glance_ip_address_mgmt )
    add_to_conf( nova_conf, "DEFAULT", "dhcpbridge_flagfile", "/etc/nova/nova.conf" )
    add_to_conf( nova_conf, "DEFAULT", "auth_strategy", "keystone" )
    add_to_conf( nova_conf, "DEFAULT", "novnc_enabled", "true" )
    add_to_conf( nova_conf, "DEFAULT", "novncproxy_base_url", "http://%s:6080/vnc_auto.html" % nova_ip_address )
    add_to_conf( nova_conf, "DEFAULT", "vncserver_proxyclient_address", nova_ip_address )
    add_to_conf( nova_conf, "DEFAULT", "novncproxy_port", "6080" )
    add_to_conf( nova_conf, "DEFAULT", "vncserver_listen", "0.0.0.0" )
    add_to_conf( nova_conf, "DEFAULT", "network_api_class", "nova.network.neutronv2.api.API" )
    add_to_conf( nova_conf, "DEFAULT", "neutron_admin_username", "neutron" )
    add_to_conf( nova_conf, "DEFAULT", "neutron_admin_password", "neutron" )
    add_to_conf( nova_conf, "DEFAULT", "neutron_admin_tenant_name", "service" )
    add_to_conf( nova_conf, "DEFAULT", "neutron_admin_auth_url", "http://%s:5000/v2.0/" % keystone_ip_address_mgmt )
    add_to_conf( nova_conf, "DEFAULT", "neutron_auth_strategy", "keystone" )
    add_to_conf( nova_conf, "DEFAULT", "neutron_url", "http://%s:9696/" % neutron_ip_address_mgmt )
    add_to_conf( nova_conf, "DEFAULT", "firewall_driver", "nova.virt.firewall.NoopFirewallDriver" )
    add_to_conf( nova_conf, "DEFAULT", "security_group_api", "neutron" )

    execute( "nova-manage db sync" )
    execute( "service nova-api restart", True )
    execute( "service nova-cert restart", True )
    execute( "service nova-scheduler restart", True )
    execute( "service nova-conductor restart", True )
    execute( "service nova-consoleauth restart", True )
    execute( "service nova-novncproxy restart", True )

def install_and_configure_neutron( neutron_ip_address, neutron_ip_address_mgmt, keystone_ip_address_mgmt, rabbit_ip_address_mgmt, mysql_ip, mysql_password ):
    neutron_conf = "/etc/neutron/neutron.conf"
    neutron_plugin_conf = "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"
    neutron_l3_conf = "/etc/neutron/l3_agent.ini"
    neutron_dhcp_conf = "/etc/neutron/dhcp_agent.ini"
    neutron_metadata_conf = "/etc/neutron/metadata_agent.ini"

    execute("apt-get install mysql-client -y")

    execute_db_commands( mysql_ip, mysql_password, "DROP DATABASE IF EXISTS neutron;" )
    execute_db_commands( mysql_ip, mysql_password, "CREATE DATABASE neutron;" )
    execute_db_commands( mysql_ip, mysql_password, "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'neutron';" )
    execute_db_commands( mysql_ip, mysql_password, "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'neutron';" )

    execute( "apt-get install neutron-server -y", True )
    execute( "apt-get install neutron-plugin-openvswitch-agent neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent -y",True )

    add_to_conf( neutron_metadata_conf, "DEFAULT", "auth_url" , "http://%s:5000/v2.0" % keystone_ip_address_mgmt )
    add_to_conf( neutron_metadata_conf, "DEFAULT", "auth_region" , "region" )
    add_to_conf( neutron_metadata_conf, "DEFAULT", "admin_tenant_name" , "%SERVICE_TENANT_NAME%" )
    add_to_conf( neutron_metadata_conf, "DEFAULT", "admin_user" , "%SERVICE_USER%" )
    add_to_conf( neutron_metadata_conf, "DEFAULT", "admin_password" , "%SERVICE_PASSWORD%" )

    add_to_conf( neutron_conf, "DEFAULT", "core_plugin", "neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2" )
    add_to_conf( neutron_conf, "DEFAULT", "verbose", "True" )
    add_to_conf( neutron_conf, "DEFAULT", "debug", "True" )
    add_to_conf( neutron_conf, "DEFAULT", "auth_strategy", "keystone" )
    add_to_conf( neutron_conf, "DEFAULT", "rabbit_host", rabbit_ip_address_mgmt )
    add_to_conf( neutron_conf, "DEFAULT", "rabbit_port", "5672" )
    add_to_conf( neutron_conf, "DEFAULT", "allow_overlapping_ips", "False" )
    add_to_conf( neutron_conf, "DEFAULT", "allow_bulk", "True" )
    add_to_conf( neutron_conf, "DEFAULT", "root_helper", "sudo neutron-rootwrap /etc/neutron/rootwrap.conf" )
    add_to_conf( neutron_conf, "keystone_authtoken", "auth_host", keystone_ip_address_mgmt )
    add_to_conf( neutron_conf, "keystone_authtoken", "auth_port", "35357" )
    add_to_conf( neutron_conf, "keystone_authtoken", "auth_protocol", "http" )
    add_to_conf( neutron_conf, "keystone_authtoken", "admin_tenant_name", "service" )
    add_to_conf( neutron_conf, "keystone_authtoken", "admin_user", "neutron" )
    add_to_conf( neutron_conf, "keystone_authtoken", "admin_password", "neutron" )
    add_to_conf( neutron_conf, "keystone_authtoken", "signing_dir", "$state_path/keystone-signing" )
    add_to_conf( neutron_conf, "database", "connection", "mysql://neutron:neutron@%s/neutron" % mysql_ip )

    add_to_conf( neutron_plugin_conf, "securitygroup", "firewall_driver", "neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver" )
    add_to_conf( neutron_plugin_conf, "ovs", "tenant_network_type", "gre" )
    add_to_conf( neutron_plugin_conf, "ovs", "tunnel_type", "gre" )
    add_to_conf( neutron_plugin_conf, "ovs", "integration_bridge", "br-int" )
    add_to_conf( neutron_plugin_conf, "ovs", "tunnel_bridge", "br-tun" )
    add_to_conf( neutron_plugin_conf, "ovs", "local_ip", neutron_ip_address_mgmt )
    add_to_conf( neutron_plugin_conf, "ovs", "tunnel_id_ranges", "1000:2000" )

    add_to_conf( neutron_dhcp_conf, "DEFAULT", "interface_driver", "neutron.agent.linux.interface.OVSInterfaceDriver" )
    add_to_conf( neutron_dhcp_conf, "DEFAULT", "dhcp_driver", "neutron.agent.linux.dhcp.Dnsmasq" )
    add_to_conf( neutron_dhcp_conf, "DEFAULT", "use_namespaces", "True" )
    add_to_conf( neutron_dhcp_conf, "DEFAULT", "enable_isolated_metadata", "True" )
    add_to_conf( neutron_dhcp_conf, "DEFAULT", "dnsmasq_config_file", "/etc/neutron/dnsmasq-neutron.conf" )

    add_to_conf( neutron_l3_conf, "DEFAULT", "interface_driver", "neutron.agent.linux.interface.OVSInterfaceDriver" )
    add_to_conf( neutron_l3_conf, "DEFAULT", "use_namespaces", "True" )
    add_to_conf( neutron_l3_conf, "DEFAULT", "gateway_external_network_id", "" )
    add_to_conf( neutron_l3_conf, "DEFAULT", "external_network_bridge", "br-ex" )
    add_to_conf( neutron_l3_conf, "DEFAULT", "metadata_port", "9697" )
    add_to_conf( neutron_l3_conf, "DEFAULT", "metadataip", neutron_ip_address )
    execute( "echo 'dhcp-option-force=26,1400' > /etc/neutron/dnsmasq-neutron.conf" )
    execute( "service neutron-server restart", True )
    execute( "service neutron-plugin-openvswitch-agent restart", True )
    execute( "service neutron-l3-agent restart", True )
    execute( "service neutron-metadata-agent restart", True )

def install_and_configure_cinder( keystone_ip_address_mgmt, cinder_ip_address_mgmt, rabbit_ip_address_mgmt, mysql_ip, mysql_password ):
    cinder_conf = "/etc/cinder/cinder.conf"
    cinder_paste_conf = "/etc/cinder/api-paste.ini"

    execute( "apt-get install cinder-api cinder-common cinder-scheduler cinder-volume python-cinder python-cinderclient open-iscsi open-iscsi-utils tgt -y", True )
    execute("apt-get install mysql-client -y")

    execute_db_commands( mysql_ip, mysql_password, "DROP DATABASE IF EXISTS cinder;" )
    execute_db_commands( mysql_ip, mysql_password, "CREATE DATABASE cinder;" )
    execute_db_commands( mysql_ip, mysql_password, "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'cinder';" )
    execute_db_commands( mysql_ip, mysql_password, "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'cinder';" )

    add_to_conf( cinder_conf, "DEFAULT", "sql_connection", "mysql://cinder:cinder@%s/cinder" % mysql_ip )
    add_to_conf( cinder_conf, "DEFAULT", "rabbit_host", rabbit_ip_address_mgmt )
    add_to_conf( cinder_conf, "DEFAULT", "volume_name_template", "volume-%s" )
    add_to_conf( cinder_conf, "DEFAULT", "volume_group", "cinder-volumes" )
    add_to_conf( cinder_conf, "DEFAULT", "storage_availability_zone", "nova" )
    add_to_conf( cinder_conf, "DEFAULT", "auth_strategy", "keystone" )
    add_to_conf( cinder_conf, "DEFAULT", "volumes_dir", "/var/lib/cinder/volumes" )
    add_to_conf( cinder_conf, "DEFAULT", "state_path", "/var/lib/cinder" )
    add_to_conf( cinder_conf, "DEFAULT", "iscsi_ip_address", "%s" % cinder_ip_address_mgmt )
    add_to_conf( cinder_conf, "DEFAULT", "verbose", "True" )
    add_to_conf( cinder_conf, "DEFAULT", "debug", "True" )

    add_to_conf( cinder_paste_conf, "filter:authtoken", "auth_host", keystone_ip_address_mgmt )
    add_to_conf( cinder_paste_conf, "filter:authtoken", "auth_port", "35357" )
    add_to_conf( cinder_paste_conf, "filter:authtoken", "auth_protocol", "http" )
    add_to_conf( cinder_paste_conf, "filter:authtoken", "admin_tenant_name", "service" )
    add_to_conf( cinder_paste_conf, "filter:authtoken", "admin_user", "cinder" )
    add_to_conf( cinder_paste_conf, "filter:authtoken", "admin_password", "cinder" )
    add_to_conf( cinder_paste_conf, "filter:authtoken", "paste.filter_factory", "keystoneclient.middleware.auth_token:filter_factory" )
    add_to_conf( cinder_paste_conf, "filter:authtoken", "service_protocol", "http" )
    add_to_conf( cinder_paste_conf, "filter:authtoken", "service_host", "%s" % keystone_ip_address_mgmt )
    add_to_conf( cinder_paste_conf, "filter:authtoken", "service_port", "5000" )
    add_to_conf( cinder_paste_conf, "filter:authtoken", "sql_connection", "mysql://cinder:cinder@%s/cinder" % mysql_ip )

    execute( "cinder-manage db sync", True )
    execute( "service cinder-api restart", True )
    execute( "service cinder-scheduler restart", True )
    execute( "service cinder-volume restart", True )

def install_and_configure_dashboard():
    execute( "apt-get install openstack-dashboard -y", True )
    execute( "service apache2 restart", True )

def install_and_configure_ovs( rabbit_ip_address_mgmt, keystone_ip_address_mgmt, neutron_ip_address, mysql_ip ):
    neutron_conf = "/etc/neutron/neutron.conf"
    neutron_plugin_conf = "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"
    neutron_l3_conf = "/etc/neutron/l3_agent.ini"

    execute("apt-get install neutron-plugin-openvswitch-agent -y", True)
    execute("apt-get install mysql-client -y")

    add_to_conf( neutron_conf, "DEFAULT", "verbose", "True" )
    add_to_conf( neutron_conf, "DEFAULT", "debug", "True")
    add_to_conf( neutron_conf, "DEFAULT", "state_path", "/var/lib/neutron")
    add_to_conf( neutron_conf, "DEFAULT", "lock_path", "$state_path/lock")
    add_to_conf( neutron_conf, "DEFAULT", "core_plugin", "neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2")
    add_to_conf( neutron_conf, "DEFAULT", "auth_strategy", "keystone")
    add_to_conf( neutron_conf, "DEFAULT", "rabbit_hosts", "%s:5672" % rabbit_ip_address_mgmt)
    add_to_conf( neutron_conf, "DEFAULT", "allow_overlapping_ips", "False")
    add_to_conf( neutron_conf, "DEFAULT", "root_helper", "sudo neutron-rootwrap /etc/neutron/rootwrap.conf")
    add_to_conf( neutron_conf, "DEFAULT", "notification_driver", "neutron.openstack.common.notifier.rpc_notifier")
    add_to_conf( neutron_conf, "keystone_authtoken", "auth_host", keystone_ip_address_mgmt)
    add_to_conf( neutron_conf, "keystone_authtoken", "auth_port", "35357")
    add_to_conf( neutron_conf, "keystone_authtoken", "auth_protocol", "http")
    add_to_conf( neutron_conf, "keystone_authtoken", "admin_tenant_name", "service")
    add_to_conf( neutron_conf, "keystone_authtoken", "admin_user", "neutron")
    add_to_conf( neutron_conf, "keystone_authtoken", "admin_password", "neutron")
    add_to_conf( neutron_conf, "database", "connection", "mysql://neutron:neutron@%s/neutron" % mysql_ip )

    add_to_conf( neutron_plugin_conf, "securitygroup", "firewall_driver", "neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver")
    add_to_conf( neutron_plugin_conf, "ovs", "tenant_network_type", "gre")
    add_to_conf( neutron_plugin_conf, "ovs", "tunnel_type", "gre")
    add_to_conf( neutron_plugin_conf, "ovs", "integration_bridge", "br-int")
    add_to_conf( neutron_plugin_conf, "ovs", "tunnel_bridge", "br-tun")
    add_to_conf( neutron_plugin_conf, "ovs", "local_ip", keystone_ip_address_mgmt)
    add_to_conf( neutron_plugin_conf, "ovs", "tunnel_id_ranges", "1000:2000")

    execute( "echo \[DEFAULT\] > /etc/neutron/l3_agent.ini" )
    add_to_conf( neutron_l3_conf, "DEFAULT", "interface_driver", "neutron.agent.linux.interface.OVSInterfaceDriver" )
    add_to_conf( neutron_l3_conf, "DEFAULT", "use_namespaces", "True" )
    add_to_conf( neutron_l3_conf, "DEFAULT", "gateway_external_network_id", "" )
    add_to_conf( neutron_l3_conf, "DEFAULT", "external_network_bridge", "br-ex" )
    add_to_conf( neutron_l3_conf, "DEFAULT", "metadata_port", "9697" )
    add_to_conf( neutron_l3_conf, "DEFAULT", "metadataip", neutron_ip_address )

    execute( "service neutron-server restart", True )
    execute( "service neutron-plugin-openvswitch-agent restart", True )

def install_and_configure_nova_compute( keystone_ip_address_mgmt, nova_ip_address, rabbit_ip_address_mgmt, glance_ip_address_mgmt, neutron_ip_address, neutron_ip_address_mgmt, my_ip, mysql_ip, ):
    nova_conf = "/etc/nova/nova.conf"
    nova_paste_conf = "/etc/nova/api-paste.ini"
    nova_compute_conf = "/etc/nova/nova-compute.conf"

    execute( "apt-get install qemu-kvm libvirt-bin python-libvirt -y" )
    execute( "apt-get install nova-compute-kvm novnc -y", True )
    execute("apt-get install mysql-client -y")

    add_to_conf( nova_paste_conf, "filter:authtoken", "auth_host", keystone_ip_address_mgmt )
    add_to_conf( nova_paste_conf, "filter:authtoken", "auth_port", "35357" )
    add_to_conf( nova_paste_conf, "filter:authtoken", "auth_protocol", "http" )
    add_to_conf( nova_paste_conf, "filter:authtoken", "admin_tenant_name", "service" )
    add_to_conf( nova_paste_conf, "filter:authtoken", "admin_user", "nova" )
    add_to_conf( nova_paste_conf, "filter:authtoken", "admin_password", "nova" )
    add_to_conf( nova_paste_conf, "filter:authtoken", "paste.filter_factory", "keystoneclient.middleware.auth_token:filter_factory" )

    add_to_conf( nova_conf, "DEFAULT", "debug", "true" )
    add_to_conf( nova_conf, "DEFAULT", "logdir", "/var/log/nova" )
    add_to_conf( nova_conf, "DEFAULT", "state_path", "/var/lib/nova" )
    add_to_conf( nova_conf, "DEFAULT", "lock_path", "/var/lock/nova" )
    add_to_conf( nova_conf, "DEFAULT", "force_dhcp_release", "True" )
    add_to_conf( nova_conf, "DEFAULT", "iscsi_helper", "tgtadm" )
    add_to_conf( nova_conf, "DEFAULT", "libvirt_use_virtio_for_bridges", "True" )
    add_to_conf( nova_conf, "DEFAULT", "connection_type", "libvirt" )
    add_to_conf( nova_conf, "DEFAULT", "root_helper", "sudo nova-rootwrap /etc/nova/rootwrap.conf" )
    add_to_conf( nova_conf, "DEFAULT", "verbose", "True" )
    add_to_conf( nova_conf, "DEFAULT", "ec2_private_dns_show_ip", "True" )
    add_to_conf( nova_conf, "DEFAULT", "api_paste_config", "/etc/nova/api-paste.ini" )
    add_to_conf( nova_conf, "DEFAULT", "volumes_path", "/var/lib/nova/volumes" )
    add_to_conf( nova_conf, "DEFAULT", "rabbit_host", rabbit_ip_address_mgmt )
    add_to_conf( nova_conf, "DEFAULT", "sql_connection ", " mysql://nova:nova@%s/nova" % mysql_ip )
    add_to_conf( nova_conf, "DEFAULT", "auth_strategy", "keystone" )
    add_to_conf( nova_conf, "DEFAULT", "glance_host", glance_ip_address_mgmt )
    add_to_conf( nova_conf, "DEFAULT", "node_availability_zone", "nova" )
    add_to_conf( nova_conf, "DEFAULT", "cinder_catalog_info", "'volume:cinder:internalURL'" )
    add_to_conf( nova_conf, "DEFAULT", "volume_api_class", "nova.volume.cinder.API" )
    add_to_conf( nova_conf, "DEFAULT", "osapi_volume_listen_port", "5900" )
    add_to_conf( nova_conf, "DEFAULT", "novnc_enabled", "true" )
    add_to_conf( nova_conf, "DEFAULT", "novncproxy_base_url", "http://%s:6080/vnc_auto.html" % nova_ip_address )
    add_to_conf( nova_conf, "DEFAULT", "vncserver_proxyclient_address", my_ip )
    add_to_conf( nova_conf, "DEFAULT", "vncserver_listen", my_ip )
    add_to_conf( nova_conf, "DEFAULT", "my_ip", my_ip )
    add_to_conf( nova_conf, "DEFAULT", "rpc_response_timeout", "1800" )
    add_to_conf( nova_conf, "DEFAULT", "network_api_class", "nova.network.neutronv2.api.API" )
    add_to_conf( nova_conf, "DEFAULT", "#libvirt_vif_driver ", " nova.virt.libvirt.vif.NeutronLinuxBridgeVIFDriver" )
    add_to_conf( nova_conf, "DEFAULT", "#linuxnet_interface_driver", "nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver" )
    add_to_conf( nova_conf, "DEFAULT", "libvirt_vif_driver ", " nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver" )
    add_to_conf( nova_conf, "DEFAULT", "network_manager", "nova.network.neutron.manager.NeutronManager" )
    add_to_conf( nova_conf, "DEFAULT", "neutron_url", "http://%s:9696" % neutron_ip_address_mgmt )
    add_to_conf( nova_conf, "DEFAULT", "neutron_auth_strategy", "keystone" )
    add_to_conf( nova_conf, "DEFAULT", "neutron_admin_tenant_name", "service" )
    add_to_conf( nova_conf, "DEFAULT", "neutron_admin_username", "neutron" )
    add_to_conf( nova_conf, "DEFAULT", "neutron_admin_password", "neutron" )
    add_to_conf( nova_conf, "DEFAULT", "neutron_admin_auth_url", "http://%s:35357/v2.0" % neutron_ip_address_mgmt )
    add_to_conf( nova_conf, "DEFAULT", "linuxnet_interface_driver ", " nova.network.linux_net.LinuxOVSInterfaceDriver" )
    add_to_conf( nova_conf, "DEFAULT", "security_group_api", "neutron" )
    add_to_conf( nova_conf, "DEFAULT", "firewall_driver", "nova.virt.firewall.NoopFirewallDriver" )

    add_to_conf( nova_compute_conf, "DEFAULT", "libvirt_type", "kvm" )
    add_to_conf( nova_compute_conf, "DEFAULT", "compute_driver", "libvirt.LibvirtDriver" )

    execute( "service libvirt-bin restart", True )
    execute( "service nova-compute restart", True )


# -*- mode: ruby -*-
# vi: set ft=ruby :
# on win10, you need `vagrant plugin install vagrant-vbguest --plugin-version 0.21` and change synced_folder.type="virtualbox"
# reference `https://www.dissmeyer.com/2020/02/11/issue-with-centos-7-vagrant-boxes-on-windows-10/`


Vagrant.configure("2") do |config|
  config.vm.box_check_update = false
  #config.vm.provider 'hyperv' do |vb|
  #  vb.customize [ "guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 1000 ]
  #end
  config.vm.synced_folder ".", "/vagrant"
  $num_instances = 4
  # curl https://discovery.etcd.io/new?size=3
  $etcd_cluster = "node1=http://10.129.0.21:2380"
  (1..$num_instances).each do |i|
    nodeID="node#{i}"
    config.vm.define nodeID do |node|
      node.vm.box = "centos/7"
      #node.vbguest.installer_options = { allow_kernel_upgrade: true }
      node.vm.box_version = "1804.02"
      node.vm.hostname = nodeID
      ip = "10.129.0.#{i+20}"
      node.vm.network "public_network", ip:ip , bridge: "VLAN1-V"
      #node.vm.network "public_network", ip:ip , bridge: "Default Switch"
      #https://github.com/hashicorp/vagrant/issues/8384
      # 实际关键是配置正确的SSH连接地址，这个脚本在WaitForIPAddress后调用就可以， 所以用after脚本就行。 before执行未生效。 WaitForIPAddress首先会自动初始化ipv6地址。 //by mr
      # config.trigger.before :"VagrantPlugins::HyperV::Action::WaitForIPAddress", type: :action do |t|
      config.trigger.after :"VagrantPlugins::HyperV::Action::WaitForIPAddress", type: :action do |t|
        t.only_on = nodeID
        t.info = "-----------------------------------Configure IP for #{nodeID}----------------------------"
        t.run = {
        inline: "scripts/SetGuestStaticIP.ps1 -VirtualMachine #{nodeID} -IPAddress #{ip} -NetMask 24 -DefaultGateway 10.129.0.254 -DNSServer 10.33.250.1"
        }
      end

      # https://developer.hashicorp.com/vagrant/docs/providers/hyperv/configuration
      node.vm.provider "hyperv" do |h|
        h.memory = "2048"
        h.maxmemory = "8192"
        h.cpus = 2
        h.vlan_id = 129
        h.linked_clone = true
        h.vm_integration_services = {
          guest_service_interface: true
        }
        h.vmname = nodeID
        h.ip_address_timeout = 240
      end
      node.vm.provision "shell", path: "install.sh", args: [i, ip, $etcd_cluster]
    end
  end
end

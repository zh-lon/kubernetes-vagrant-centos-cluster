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
  $num_instances = 3
  # curl https://discovery.etcd.io/new?size=3
  $etcd_cluster = "node1=http://192.168.99.101:2380"
  (1..$num_instances).each do |i|
    nodeID="node#{i}"
    config.vm.define nodeID do |node|
      node.vm.box = "centos/7"
      #node.vbguest.installer_options = { allow_kernel_upgrade: true }
      node.vm.box_version = "1804.02"
      node.vm.hostname = nodeID
      ip = "192.168.99.#{i+100}"
      node.vm.network "public_network", ip:ip , bridge: "k8s-Switch"
      #node.vm.network "public_network", ip:ip , bridge: "Default Switch"
      #https://github.com/hashicorp/vagrant/issues/8384
      config.trigger.before :"VagrantPlugins::HyperV::Action::WaitForIPAddress", type: :action do |t|
        t.only_on = nodeID
        t.info = "-----------------------------------Configure IP for #{nodeID}----------------------------"
        t.run = {
        inline: "scripts/SetGuestStaticIP.ps1 -VirtualMachine #{nodeID} -Username vagrant -Password vagrant -IPAddress #{ip} -NetMask 255.255.255.0 -DefaultGateway 192.168.99.1 -DNSServer 114.114.114.114"
        }
      end


      #node.vm.provision "shell", run: "always", inline: "echo set ipv4 temp"
      #node.vm.provision "shell", run: "always", inline: "yum install net-tools -y"
      #node.vm.provision "shell", run: "always", inline: "ifconfig eth0 192.168.99.#{i+100} netmask 255.255.250.0 up"
      #node.vm.provision "shell",  run: "always",inline: "route add -net 0.0.0.0 netmask 0.0.0.0 gw 192.168.99.1 dev eth0"
      # node.vm.provider "virtualbox" do |vb|
      #   vb.memory = "3072"
      #   vb.cpus = 1
      #   vb.name = "node#{i}"
      # end
      node.vm.provider "hyperv" do |h|
        h.memory = "3072"
        h.cpus = 2
        h.vm_integration_services = {
          guest_service_interface: true
        }
        h.vmname = nodeID
      end
      node.vm.provision "shell", path: "install.sh", args: [i, ip, $etcd_cluster]
    end
  end
end

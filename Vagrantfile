# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.require_version ">= 2.3.7"
Vagrant.configure("2") do |config|
  script_choice = ENV['VAGRANT_SETUP_CHOICE'] || 'none'
  vm_box = ENV['VAGRANT_BOX'] || 'ubuntu/jammy64'
  vm_cpus = ENV['VAGRANT_CPUS'] || '8'
  vm_memory = ENV['VAGRANT_MEMORY'] || '24576'
  vm_disk_size = ENV['VAGRANT_DISK_SIZE'] || '500GB'
  vm_name = ENV['VAGRANT_NAME'] || 'Malcolm-Helm'

  config.vm.box = vm_box
  config.disksize.size = vm_disk_size

  # NIC 1: Static IP with port forwarding
  if script_choice == 'use_istio'
    config.vm.network "forwarded_port", guest: 443, host: 8443, guest_ip: "10.0.2.100"
    # config.vm.network "forwarded_port", guest: 8080, host: 8080, guest_ip: "10.0.2.100"
  else
    config.vm.network "forwarded_port", guest: 80, host: 8080
  end

  # NIC 2: Promiscuous mode
  config.vm.network "private_network", type: "dhcp", virtualbox__intnet: "promiscuous", auto_config: false

  config.vm.provider "virtualbox" do |vb|
    vb.gui = true
    vb.customize ['modifyvm', :id, '--ioapic', 'on']
    vb.customize ['modifyvm', :id, '--accelerate3d', 'off']
    vb.customize ['modifyvm', :id, '--graphicscontroller', 'vboxsvga']
    vb.name = vm_name
    vb.memory = vm_memory.to_i
    vb.cpus = vm_cpus
  end

  config.vm.provision "shell", inline: <<-SHELL
    echo "Updating the kernel..."
    apt-get update
    apt-get upgrade -y
    apt-get install -y linux-oem-22.04d
    echo "Rebooting the VM"
  SHELL

  config.vm.provision "reload"

  config.vm.provision "shell", inline: <<-SHELL
    RKE2_VERSION=v1.32.3+rke2r1

    /sbin/rcvboxadd quicksetup all

    # Turn off password authentication to make it easier to login
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

    # Configure promisc iface
    cp /vagrant/vagrant_dependencies/set-promisc.service /etc/systemd/system/set-promisc.service
    systemctl enable set-promisc.service

    # Setup RKE2
    curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=$RKE2_VERSION sh -
    mkdir -p /etc/rancher/rke2
    echo "cni: calico" > /etc/rancher/rke2/config.yaml

    systemctl start rke2-server.service
    systemctl enable rke2-server.service

    mkdir /root/.kube
    mkdir /home/vagrant/.kube

    cp /etc/rancher/rke2/rke2.yaml /home/vagrant/.kube/config
    cp /etc/rancher/rke2/rke2.yaml /root/.kube/config
    chmod 0600 /home/vagrant/.kube/config
    chmod 0600 /root/.kube/config
    chown -R vagrant:vagrant /home/vagrant/.kube

    ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
    snap install helm --classic
    node_name=$(kubectl get nodes -o jsonpath="{.items[0].metadata.name}")
    kubectl label nodes $node_name cnaps.io/node-type=Tier-1
    kubectl label nodes $node_name cnaps.io/suricata-capture=true
    kubectl label nodes $node_name cnaps.io/zeek-capture=true
    kubectl label nodes $node_name cnaps.io/arkime-capture=true

    kubectl apply -f /vagrant/vagrant_dependencies/sc.yaml

    grep -qxF 'alias k="kubectl"' /home/vagrant/.bashrc || cat /vagrant/scripts/bash_convenience >> /home/vagrant/.bashrc

    # Load specific settings sysctl settings needed for opensearch
    grep -qxF 'fs.file-max=2097152' /etc/sysctl.conf || echo 'fs.file-max=2097152' >> /etc/sysctl.conf
    grep -qxF 'fs.inotify.max_queued_events=131072' /etc/sysctl.conf || echo 'fs.inotify.max_queued_events=131072' >> /etc/sysctl.conf
    grep -qxF 'fs.inotify.max_user_instances=8192' /etc/sysctl.conf || echo 'fs.inotify.max_user_instances=8192' >> /etc/sysctl.conf
    grep -qxF 'fs.inotify.max_user_watches=131072' /etc/sysctl.conf || echo 'fs.inotify.max_user_watches=131072' >> /etc/sysctl.conf
    grep -qxF 'kernel.dmesg_restrict=0' /etc/sysctl.conf || echo 'kernel.dmesg_restrict=0' >> /etc/sysctl.conf
    grep -qxF 'vm.dirty_background_ratio=40' /etc/sysctl.conf || echo 'vm.dirty_background_ratio=40' >> /etc/sysctl.conf
    grep -qxF 'vm.dirty_ratio=80' /etc/sysctl.conf || echo 'vm.dirty_ratio=80' >> /etc/sysctl.conf
    grep -qxF 'vm.max_map_count=262144' /etc/sysctl.conf || echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
    grep -qxF 'vm.swappiness=1' /etc/sysctl.conf || echo 'vm.swappiness=1' >> /etc/sysctl.conf
    sysctl -p
    if [[ ! -f /etc/security/limits.d/limits.conf ]]; then
      mkdir -p /etc/security/limits.d/
      echo '* soft nofile 65535' > /etc/security/limits.d/limits.conf
      echo '* hard nofile 65535' >> /etc/security/limits.d/limits.conf
      echo '* soft memlock unlimited' >> /etc/security/limits.d/limits.conf
      echo '* hard memlock unlimited' >> /etc/security/limits.d/limits.conf
      echo '* soft nproc 262144' >> /etc/security/limits.d/limits.conf
      echo '* hard nproc 524288' >> /etc/security/limits.d/limits.conf
    fi
    sed -i 's/GRUB_CMDLINE_LINUX="[^"]*/& elevator=deadline systemd.unified_cgroup_hierarchy=1 cgroup_enable=memory swapaccount=1 cgroup.memory=nokmem random.trust_cpu=on preempt=voluntary/' /etc/default/grub
    update-grub

    # Add kernel modules needed for istio
    grep -qxF 'xt_REDIRECT' /etc/modules || echo 'xt_REDIRECT' >> /etc/modules
    grep -qxF 'xt_connmark' /etc/modules || echo 'xt_connmark' >> /etc/modules
    grep -qxF 'xt_mark' /etc/modules || echo 'xt_mark' >> /etc/modules
    grep -qxF 'xt_owner' /etc/modules || echo 'xt_owner' >> /etc/modules
    grep -qxF 'iptable_mangle' /etc/modules || echo 'iptable_mangle' >> /etc/modules

    # Update coredns so that hostname will resolve to their perspective IPs by enabling the host plugin
    myip_string=$(hostname -I)
    read -ra my_hostips <<< $myip_string
    cp /vagrant/vagrant_dependencies/Corefile.yaml /tmp/Corefile.yaml
    sed -i "s/###NODE_IP_ADDRESS###/${my_hostips[0]}/g" /tmp/Corefile.yaml
    kubectl replace -f /tmp/Corefile.yaml
    sleep 5
    echo "Rebooting the VM"

  SHELL

  config.vm.provision "reload"

  if script_choice == 'use_istio'
    config.vm.provision "shell", inline: <<-SHELL
      ISTIO_VERSION=1.25.1

      # Setup metallb
      helm repo add metallb https://metallb.github.io/metallb
      helm repo update metallb
      echo "Sleep for one minute before installing metallb"
      sleep 60
      helm install metallb metallb/metallb -n metallb-system --create-namespace
      echo "Sleep for three minutes for cluster to come back up"
      sleep 180
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=900s --namespace metallb-system
      kubectl apply -f /vagrant/vagrant_dependencies/ipaddress-pool.yml
      kubectl apply -f /vagrant/vagrant_dependencies/l2advertisement.yaml

      # Delete rke ingress controller so it does not conflict with istio service mesh
      kubectl delete daemonset rke2-ingress-nginx-controller -n kube-system

      # Install istio service mesh
      helm repo add istio https://istio-release.storage.googleapis.com/charts
      helm repo update istio

      helm install istio istio/base --version $ISTIO_VERSION -n istio-system --create-namespace
      helm install istiod istio/istiod --version $ISTIO_VERSION -n istio-system --wait
      helm install tenant-ingressgateway istio/gateway --version $ISTIO_VERSION -n istio-system
      kubectl apply -f /vagrant/vagrant_dependencies/tenant-gateway.yaml

      # Create the certs
      mkdir certs

      # TODO this is not the right way to generate the certs I need to go back and fix this later.
      openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=bigbang Inc./CN=bigbang.vp.dev' -keyout certs/ca.key -out certs/ca.crt
      openssl req -out certs/bigbang.vp.dev.csr -newkey rsa:2048 -nodes -keyout certs/bigbang.vp.dev.key -config /vagrant/vagrant_dependencies/req.conf -extensions 'v3_req'
      openssl x509 -req -sha256 -days 365 -CA certs/ca.crt -CAkey certs/ca.key -set_serial 0 -in certs/bigbang.vp.dev.csr -out certs/bigbang.vp.dev.crt

      cat certs/bigbang.vp.dev.crt > certs/chain.crt
      cat certs/ca.crt >> certs/chain.crt

      # openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout certs/istio.key -out certs/istio.crt -config /vagrant/vagrant_dependencies/req.conf -extensions 'v3_req'
      # Setup istio gateway with certs
      # kubectl create -n istio-system secret tls tenant-cert --key=certs/istio.key --cert=certs/istio.crt
      kubectl create -n istio-system secret tls tenant-cert --key=certs/bigbang.vp.dev.key --cert=certs/chain.crt

      # Install Malcolm enabling istio
      helm install malcolm /vagrant/chart -n malcolm --create-namespace --set istio.enabled=true --set ingress.enabled=false --set pcap_capture_env.pcap_iface=enp0s8
      # kubectl apply -f /vagrant/vagrant_dependencies/test-gateway.yml
      grep -qxF '10.0.2.100 malcolm.vp.bigbang.dev malcolm.test.dev' /etc/hosts || echo '10.0.2.100 malcolm.vp.bigbang.dev malcolm.test.dev' >> /etc/hosts
      echo "You may now ssh to your kubernetes cluster using ssh -p 2222 vagrant@localhost"
      hostname -I
    SHELL
  else
    config.vm.provision "shell", inline: <<-SHELL
      echo "Sleep for three minutes for cluster to come back up"
      sleep 180
      helm install malcolm /vagrant/chart -n malcolm --create-namespace --set istio.enabled=false --set ingress.enabled=true --set pcap_capture_env.pcap_iface=enp0s8
      echo "You may now ssh to your kubernetes cluster using ssh -p 2222 vagrant@localhost"
      hostname -I
    SHELL
  end

end

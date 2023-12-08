# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.require_version ">= 2.3.7"
Vagrant.configure("2") do |config|
  script_choice = ENV['VAGRANT_SETUP_CHOICE'] || 'none'
  config.vm.box = "ubuntu/jammy64"
  config.disksize.size = '500GB'

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
    # Customize the amount of memory on the VM:
    vb.name = "Malcolm-Helm"
    vb.memory = "16192"
    vb.cpus = 8
  end

  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get upgrade -y

    # Turn off password authentication to make it easier to login
    sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

    # Configure promisc iface
    cp /vagrant/vagrant_dependencies/set-promisc.service /etc/systemd/system/set-promisc.service
    systemctl enable set-promisc.service

    # Setup RKE2
    curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=v1.26.6+rke2r1 sh -
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

    kubectl apply -f /vagrant/vagrant_dependencies/sc.yaml

    grep -qxF 'alias k="kubectl"' /home/vagrant/.bashrc || echo 'alias k="kubectl"' >> /home/vagrant/.bashrc

    # Load specific settings sysctl settings needed for opensearch
    grep -qxF 'fs.inotify.max_user_instances=8192' /etc/sysctl.conf || echo 'fs.inotify.max_user_instances=8192' >> /etc/sysctl.conf
    grep -qxF 'fs.file-max=1000000' /etc/sysctl.conf || echo 'fs.file-max=1000000' >> /etc/sysctl.conf
    grep -qxF 'vm.max_map_count=1524288' /etc/sysctl.conf || echo 'vm.max_map_count=1524288' >> /etc/sysctl.conf
    sysctl -p

    # Add kernel modules needed for istio 
    grep -qxF 'xt_REDIRECT' /etc/modules || echo 'xt_REDIRECT' >> /etc/modules
    grep -qxF 'xt_connmark' /etc/modules || echo 'xt_connmark' >> /etc/modules
    grep -qxF 'xt_mark' /etc/modules || echo 'xt_mark' >> /etc/modules
    grep -qxF 'xt_owner' /etc/modules || echo 'xt_owner' >> /etc/modules
    grep -qxF 'iptable_mangle' /etc/modules || echo 'iptable_mangle' >> /etc/modules

  SHELL

  config.vm.provision "reload"

  if script_choice == 'use_istio'
    config.vm.provision "shell", inline: <<-SHELL
      # Setup metallb
      helm repo add metallb https://metallb.github.io/metallb
      helm repo update metallb
      helm install metallb metallb/metallb -n metallb-system --create-namespace
      echo "Sleep for two minutes for cluster to come back up"
      sleep 120
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=900s --namespace metallb-system
      kubectl apply -f /vagrant/vagrant_dependencies/ipaddress-pool.yml
      kubectl apply -f /vagrant/vagrant_dependencies/l2advertisement.yaml

      # Delete rke ingress controller so it does not conflict with istio service mesh
      kubectl delete daemonset rke2-ingress-nginx-controller -n kube-system

      # Install istio service mesh
      helm repo add istio https://istio-release.storage.googleapis.com/charts
      helm repo update istio

      helm install istio istio/base --version 1.18.2 -n istio-system --create-namespace
      helm install istiod istio/istiod --version 1.18.2 -n istio-system --wait
      helm install tenant-ingressgateway istio/gateway --version 1.18.2 -n istio-system
      kubectl apply -f /vagrant/vagrant_dependencies/tenant-gateway.yaml      

      # Create the certs
      mkdir certs

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
      helm install malcolm /vagrant/chart -n malcolm --create-namespace --set istio.enabled=false --set ingress.enabled=true --set pcap_capture_env.pcap_iface=enp0s8
      echo "You may now ssh to your kubernetes cluster using ssh -p 2222 vagrant@localhost"
      hostname -I
    SHELL
  end

end

# -*- mode: ruby -*-
# vi: set ft=ruby :

def using_provider?(name)
  ENV["VAGRANT_DEFAULT_PROVIDER"] == name || ARGV.any? { |a| a.include?("--provider=#{name}") }
end

def parse_disk_size(size_str)
  size_str = size_str.strip.upcase
  if size_str =~ /^(\d+)(GB?)$/
    return $1.to_i * 1024
  elsif size_str =~ /^(\d+)(MB?)$/
    return $1.to_i
  else
    raise "Unrecognized disk size format: #{size_str}"
  end
end

Vagrant.require_version ">= 2.3.7"
Vagrant.configure("2") do |config|
  script_choice = ENV['VAGRANT_SETUP_CHOICE'] || 'none'
  vm_box = ENV['VAGRANT_BOX'] || 'bento/debian-12'
  vm_cpus = ENV['VAGRANT_CPUS'] || '8'
  vm_memory = ENV['VAGRANT_MEMORY'] || '24576'
  vm_disk_size = ENV['VAGRANT_DISK_SIZE'] || '400GB'
  vm_name = ENV['VAGRANT_NAME'] || 'Malcolm-Helm'
  vm_gui = ENV['VAGRANT_GUI'] || 'true'
  vm_ssd = ENV['VAGRANT_SSD'] || 'on'

  config.vm.define vm_name
  config.vm.box = vm_box

  # NIC 1: Static IP with port forwarding
  if script_choice == 'use_istio'
    config.vm.network "forwarded_port", guest: 443, host: 8443, guest_ip: "10.0.2.100"
    # config.vm.network "forwarded_port", guest: 8080, host: 8080, guest_ip: "10.0.2.100"
  else
    config.vm.network "forwarded_port", guest: 80, host: 8080
  end

  if using_provider?("virtualbox")
    config.vm.disk :disk, name: "extra", size: vm_disk_size

    # NIC 2: Promiscuous mode (TODO: can I do this for other providers?)
    config.vm.network "private_network", type: "dhcp", virtualbox__intnet: "promiscuous", auto_config: false

    config.vm.provider "virtualbox" do |vb|
      vb.gui = (vm_gui.to_s.downcase == 'true')
      vb.customize ['modifyvm', :id, '--memory', vm_memory]
      vb.customize ['modifyvm', :id, '--cpus', vm_cpus]
      vb.customize ['modifyvm', :id, '--ioapic', 'on']
      vb.customize ['modifyvm', :id, '--accelerate3d', 'off']
      vb.customize ['modifyvm', :id, '--graphicscontroller', 'vboxsvga']
      vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 0, "--device", 0, "--nonrotational", vm_ssd]
      vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 1, "--device", 0, "--nonrotational", vm_ssd]
      vb.name = vm_name
    end
  end

  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "kvm"
    libvirt.cpus = vm_cpus.to_i
    libvirt.memory = vm_memory.to_i
    libvirt.machine_arch = 'x86_64'
    libvirt.machine_type = "q35"
    libvirt.nic_model_type = "virtio"
    libvirt.cpu_mode = 'host-model'
    libvirt.cpu_fallback = 'forbid'
    libvirt.channel :type  => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
    libvirt.random :model => 'random'
    libvirt.disk_bus = "virtio"
    libvirt.storage :file, :size => vm_disk_size
  end

  if using_provider?("vmware_desktop")
    config.vm.network "private_network", type: "dhcp", auto_config: false
    config.vm.provider "vmware_desktop" do |vm|
      vm.vmx["displayName"] = vm_name
      vm.vmx["memsize"] = vm_memory.to_s
      vm.vmx["numvcpus"] = vm_cpus.to_s
      if vm_ssd.to_s.downcase == "on" || vm_ssd.to_s.downcase == "true"
        vm.vmx["scsi0:0.virtualSSD"] = "1"
      end
      # TODO: vmware doesn't support adding a second disk with the official vagrant plugin
      #   so this just resizes the primary disk. however, we're not automatically
      #   resizing the primary disk partition in the VM so this isn't really done yet.
      v.vmx["disk.size"] = parse_disk_size(vm_disk_size).to_s
    end
  end

  config.vm.provision "shell", inline: <<-SHELL
    set -euo pipefail

    apt-get update -y
    apt-get install -y build-essential git iptables linux-headers-$(uname -m | sed 's/^x86_64$/amd64/') qemu-guest-agent

    ALL_DISKS=($(lsblk --nodeps --noheadings --output NAME --paths))
    for DISK in "${ALL_DISKS[@]}"; do
        if [[ "$(lsblk --noheadings --output MOUNTPOINT "${DISK}" | grep -vE "^$")" == "" ]] && \
           [[ "$(lsblk --noheadings --output FSTYPE "${DISK}" | grep -vE "^$")" == "" ]]; then
            mkfs.ext4 "${DISK}"
            tune2fs -o journal_data_writeback "${DISK}"
            MOUNT_POINT=/mnt/"$(basename "${DISK}")"
            mkdir -p "${MOUNT_POINT}"
            grep -qs "$MOUNT_POINT" /etc/fstab || echo -e "# Disk added by Vagrant\n${DISK} ${MOUNT_POINT} ext4 defaults,relatime,errors=remount-ro 0 0" >> /etc/fstab
        fi
    done
    mount -a

    [[ -x /sbin/rcvboxadd ]] && /sbin/rcvboxadd quicksetup all >/dev/null 2>&1 || true
    systemctl enable qemu-guest-agent >/dev/null 2>&1 || true
  SHELL

  config.vm.provision "reload"

  config.vm.provision "shell", inline: <<-SHELL
    RKE2_DATA_DRIVE="$(grep -A 1 "Disk added by Vagrant" /etc/fstab | grep -v '^#' | head -n 1 | awk '{print $2}')"
    [[ -d "${RKE2_DATA_DRIVE}" ]] && RKE2_DATA_DIR="${RKE2_DATA_DRIVE}"/rke2 || RKE2_DATA_DIR=
    [[ -n "${RKE2_DATA_DIR}" ]] && mkdir -p "${RKE2_DATA_DIR}"

    # Turn off password authentication to make it easier to login
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

    # Configure promisc iface
    cp /vagrant/vagrant_dependencies/set-promisc.service /etc/systemd/system/set-promisc.service
    systemctl enable set-promisc.service

    # Setup RKE2
    curl -fsSL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.32.3+rke2r1 sh -
    mkdir -p /etc/rancher/rke2
    echo "cni: calico" > /etc/rancher/rke2/config.yaml
    [[ -n "${RKE2_DATA_DIR}" ]] && echo "data-dir: ${RKE2_DATA_DIR}" >> /etc/rancher/rke2/config.yaml

    systemctl start rke2-server.service
    systemctl enable rke2-server.service

    mkdir /root/.kube
    mkdir /home/vagrant/.kube

    cp /etc/rancher/rke2/rke2.yaml /home/vagrant/.kube/config
    cp /etc/rancher/rke2/rke2.yaml /root/.kube/config
    chmod 0600 /home/vagrant/.kube/config
    chmod 0600 /root/.kube/config
    chown -R vagrant:vagrant /home/vagrant/.kube

    if [[ -n "${RKE2_DATA_DIR}" ]]; then
      find "${RKE2_DATA_DIR}"/data -type f -executable -name kubectl -print0 | head -z -n 1 | xargs -r -0 -I XXX ln -v -s "XXX" /usr/local/bin/kubectl
    else
      ln -v -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
    fi
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -
    node_name=$(kubectl get nodes -o jsonpath="{.items[0].metadata.name}")
    kubectl label nodes $node_name cnaps.io/node-type=Tier-1
    kubectl label nodes $node_name cnaps.io/suricata-capture=true
    kubectl label nodes $node_name cnaps.io/zeek-capture=true
    kubectl label nodes $node_name cnaps.io/arkime-capture=true

    cp /vagrant/vagrant_dependencies/sc.yaml /tmp/sc.yaml
    if [[ -d "${RKE2_DATA_DRIVE}" ]]; then
      mkdir -p "${RKE2_DATA_DRIVE}"/local-path-provisioner
      chmod 777 "${RKE2_DATA_DRIVE}"/local-path-provisioner
      sed -i "s@/opt/local-path-provisioner@${RKE2_DATA_DRIVE}/local-path-provisioner@g" /tmp/sc.yaml
    fi
    kubectl apply -f /tmp/sc.yaml

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
    grep -qxF 'vm.swappiness=0' /etc/sysctl.conf || echo 'vm.swappiness=0' >> /etc/sysctl.conf
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
    until kubectl get configmaps --namespace kube-system 2>/dev/null | grep -q rke2-coredns-rke2-coredns; do
      echo "Waiting for rke2-coredns-rke2-coredns..." >&2
      sleep 20
    done
    myip_string=$(hostname -I)
    read -ra my_hostips <<< $myip_string
    cp /vagrant/vagrant_dependencies/Corefile.yaml /tmp/Corefile.yaml
    sed -i "s/###NODE_IP_ADDRESS###/${my_hostips[0]}/g" /tmp/Corefile.yaml
    kubectl replace -f /tmp/Corefile.yaml
    sleep 5
    echo "Rebooting..." >&2
  SHELL

  config.vm.provision "reload"

  if script_choice == 'use_istio'
    config.vm.provision "shell", inline: <<-SHELL
      echo "Wait for cluster to become ready..." >&2
      until kubectl wait --for=condition=Ready nodes --all --timeout=19s >/dev/null 2>&1; do
        sleep 1
      done
      # Setup metallb
      helm repo add metallb https://metallb.github.io/metallb
      helm repo update metallb
      helm install metallb metallb/metallb -n metallb-system --create-namespace
      echo "Wait for metallb-system controller to become ready..." >&2
      until kubectl get namespaces 2>/dev/null | grep -q metallb-system; do
        sleep 20
      done
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=900s --namespace metallb-system
      kubectl apply -f /vagrant/vagrant_dependencies/ipaddress-pool.yml
      kubectl apply -f /vagrant/vagrant_dependencies/l2advertisement.yaml

      # Delete rke ingress controller so it does not conflict with istio service mesh
      kubectl delete daemonset rke2-ingress-nginx-controller -n kube-system

      # Install istio service mesh
      helm repo add istio https://istio-release.storage.googleapis.com/charts
      helm repo update istio

      ISTIO_VERSION=1.25.1
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
      echo "You may now ssh to your kubernetes cluster using ssh -p 2222 vagrant@localhost" >&2
      hostname -I
    SHELL
  else
    config.vm.provision "shell", inline: <<-SHELL
      until kubectl get endpoints --namespace kube-system 2>/dev/null | grep -Pq "rke2-ingress-nginx-controller-admission\s+.+:\d+"; do
        echo "Waiting for rke2-ingress-nginx-controller-admission..." >&2
        sleep 20
      done
      sleep 5
      helm install malcolm /vagrant/chart -n malcolm --create-namespace --set istio.enabled=false --set ingress.enabled=true --set pcap_capture_env.pcap_iface=enp0s8
      echo "You may now ssh to your kubernetes cluster using ssh -p 2222 vagrant@localhost" >&2
      hostname -I
    SHELL
  end

end

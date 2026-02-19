# -*- mode: ruby -*-
# vi: set ft=ruby :

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
  vm_box = ENV['VAGRANT_BOX'] || 'bento/debian-13'
  vm_cpus = ENV['VAGRANT_CPUS'] || '8'
  vm_memory = ENV['VAGRANT_MEMORY'] || '24576'
  vm_disk_size = ENV['VAGRANT_DISK_SIZE'] || '400GB'
  vm_name = ENV['VAGRANT_NAME'] || 'Malcolm-Helm'
  vm_gui = ENV['VAGRANT_GUI'] || 'true'
  vm_ssd = ENV['VAGRANT_SSD'] || 'on'
  vm_nic = ENV['VAGRANT_NIC'] || 'enp0s8'
  libvirt_machine_arch = ENV['VAGRANT_LIBVIRT_MACHINE_ARCH'] || 'x86_64'
  libvirt_machine_type = ENV['VAGRANT_LIBVIRT_MACHINE_TYPE'] || 'q35'
  libvirt_ovmf_code = ENV['VAGRANT_LIBVIRT_LOADER'] || ''
  libvirt_ovmf_vars = ENV['VAGRANT_LIBVIRT_NVRAM'] || ''
  malcolm_username = ENV['MALCOLM_USERNAME'] || 'malcolm'
  malcolm_password = ENV['MALCOLM_PASSWORD'] || 'malcolm'
  malcolm_namespace = ENV['MALCOLM_NAMESPACE'] || 'malcolm'

  config.vm.define vm_name
  config.vm.box = vm_box

  # NIC 1: Static IP with port forwarding
  if script_choice == 'use_istio'
    config.vm.network "forwarded_port", guest: 443, host: 8443, guest_ip: "10.0.2.100"
  else
    config.vm.network "forwarded_port", guest: 80, host: 8080
  end

  config.vm.provider "virtualbox" do |vb, override|
    override.vm.disk :disk, name: "extra", size: vm_disk_size
    override.vm.network "private_network", type: "dhcp", virtualbox__intnet: "promiscuous", auto_config: false

    vb.gui = (vm_gui.to_s.downcase == 'true')
    vb.customize ['modifyvm', :id, '--memory', vm_memory]
    vb.customize ['modifyvm', :id, '--cpus', vm_cpus]
    vb.customize ['modifyvm', :id, '--ioapic', 'on']
    vb.customize ['modifyvm', :id, '--accelerate3d', 'off']
    vb.customize ['modifyvm', :id, '--graphicscontroller', 'vboxsvga']
    vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 1, "--device", 0, "--nonrotational", vm_ssd]
    vb.name = vm_name
  end

  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "kvm"
    libvirt.cpus = vm_cpus.to_i
    libvirt.memory = vm_memory.to_i
    libvirt.machine_arch = libvirt_machine_arch
    libvirt.machine_type = libvirt_machine_type
    libvirt.loader = libvirt_ovmf_code if libvirt_ovmf_code && !libvirt_ovmf_code.empty?
    libvirt.nvram  = libvirt_ovmf_vars if libvirt_ovmf_vars && !libvirt_ovmf_vars.empty?
    libvirt.nic_model_type = "virtio"
    libvirt.cpu_mode = 'host-model'
    libvirt.cpu_fallback = 'forbid'
    libvirt.channel :type  => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
    libvirt.random :model => 'random'
    libvirt.disk_bus = "virtio"
    libvirt.storage :file, :size => vm_disk_size
  end

  config.vm.provider "vmware_desktop" do |vm, override|
    override.vm.network "private_network", type: "dhcp", auto_config: false
    vm.vmx["displayName"] = vm_name
    vm.vmx["memsize"] = vm_memory.to_s
    vm.vmx["numvcpus"] = vm_cpus.to_s
    if vm_ssd.to_s.downcase == "on" || vm_ssd.to_s.downcase == "true"
      vm.vmx["scsi0:0.virtualSSD"] = "1"
    end
    # TODO: vmware doesn't support adding a second disk with the official vagrant plugin
    #   so this just resizes the primary disk. however, we're not automatically
    #   resizing the primary disk partition in the VM so this isn't really done yet.
    vm.vmx["disk.size"] = parse_disk_size(vm_disk_size).to_s
  end

  config.vm.provision "shell", inline: <<-SHELL
    set -euo pipefail

    apt-get update -y
    apt-get install -y build-essential git iptables linux-headers-$(uname -m | sed 's/^x86_64$/amd64/') qemu-guest-agent apache2-utils openssl jq

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

    # Turn on password authentication to make it easier to login
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

    # Configure promiscuous NIC for capture
    cp /vagrant/vagrant_dependencies/set-promisc.service /etc/systemd/system/set-promisc.service
    sed -i "s/enp0s8/#{vm_nic}/g" /etc/systemd/system/set-promisc.service
    systemctl enable set-promisc.service

    # Setup RKE2
    curl -fsSL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.35.0+rke2r1 sh -
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
    touch /home/vagrant/.hushlogin
    chown -R vagrant:vagrant /home/vagrant/.kube /home/vagrant/.hushlogin

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

    LINUX_CPU=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')

    YQ_VERSION="4.52.2"
    YQ_URL="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${LINUX_CPU}"
    curl -fsSL -o /usr/local/bin/yq "${YQ_URL}"
    chmod 755 /usr/local/bin/yq
    chown root:root /usr/local/bin/yq

    STERN_VERSION=1.33.1
    STERN_URL="https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_${LINUX_CPU}.tar.gz"
    cd /tmp
    mkdir -p ./stern
    curl -L "${STERN_URL}" | tar xzf - -C ./stern
    mv ./stern/stern /usr/local/bin/stern
    chmod 755 /usr/local/bin/stern
    chown root:root /usr/local/bin/stern
    rm -rf /tmp/stern*

    K9S_VERSION=0.50.18
    K9S_URL="https://github.com/derailed/K9S/releases/download/v${K9S_VERSION}/k9s_Linux_${LINUX_CPU}.tar.gz"
    cd /tmp
    mkdir -p ./K9S
    curl -L "${K9S_URL}" | tar xzf - -C ./K9S
    mv ./K9S/k9s /usr/local/bin/k9s
    chmod 755 /usr/local/bin/k9s
    chown root:root /usr/local/bin/k9s
    rm -rf /tmp/K9S*

    KUBECONFORM_VERSION=0.7.0
    KUBECONFORM_URL="https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-${LINUX_CPU}.tar.gz"
    cd /tmp
    mkdir -p ./KUBECONFORM
    curl -L "${KUBECONFORM_URL}" | tar xzf - -C ./KUBECONFORM
    mv ./KUBECONFORM/kubeconform /usr/local/bin/kubeconform
    chmod 755 /usr/local/bin/kubeconform
    chown root:root /usr/local/bin/kubeconform
    rm -rf /tmp/KUBECONFORM*

    grep -qxF 'alias k="kubectl"' /home/vagrant/.bashrc || cat /vagrant/vagrant_dependencies/bash_convenience >> /home/vagrant/.bashrc
    sed -i "s/KUBESPACE=malcolm/KUBESPACE=#{malcolm_namespace}/g" /home/vagrant/.bashrc

    # Load specific settings sysctl settings needed for opensearch
    if [[ ! -f /etc/sysctl.d/performance.conf ]]; then
      mkdir -p /etc/sysctl.d/
      echo 'fs.file-max=2097152' > /etc/sysctl.d/performance.conf
      echo 'fs.inotify.max_queued_events=131072' >> /etc/sysctl.d/performance.conf
      echo 'fs.inotify.max_user_instances=8192' >> /etc/sysctl.d/performance.conf
      echo 'fs.inotify.max_user_watches=131072' >> /etc/sysctl.d/performance.conf
      echo 'kernel.dmesg_restrict=0' >> /etc/sysctl.d/performance.conf
      echo 'vm.dirty_background_ratio=5' >> /etc/sysctl.d/performance.conf
      echo 'vm.dirty_ratio=10' >> /etc/sysctl.d/performance.conf
      echo 'vm.max_map_count=524288' >> /etc/sysctl.d/performance.conf
      echo 'vm.swappiness=0' >> /etc/sysctl.d/performance.conf
      sysctl -p
    fi
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
    echo "Waiting for rke2-coredns-rke2-coredns..." >&2
    until kubectl get configmaps --namespace kube-system 2>/dev/null | grep -q rke2-coredns-rke2-coredns; do
      sleep 20
    done
    echo "rke2-coredns-rke2-coredns is present" >&2
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
      echo "Cluster nodes are ready" >&2
      # Setup metallb
      helm repo add metallb https://metallb.github.io/metallb
      helm repo update metallb
      helm install metallb metallb/metallb -n metallb-system --create-namespace
      echo "Wait for metallb-system namespace..." >&2
      until kubectl get namespaces 2>/dev/null | grep -q metallb-system; do
        sleep 20
      done
      sleep 10
      echo "metallb-system namespace exists" >&2
      echo "Wait for metallb-system controller to become ready..." >&2
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=900s --namespace metallb-system
      sleep 10
      echo "metallb-system controller pod exists" >&2
      kubectl apply -f /vagrant/vagrant_dependencies/ipaddress-pool.yml
      kubectl apply -f /vagrant/vagrant_dependencies/l2advertisement.yaml

      # Delete rke ingress controller so it does not conflict with istio service mesh
      kubectl delete daemonset rke2-ingress-nginx-controller -n kube-system

      # Install istio service mesh
      helm repo add istio https://istio-release.storage.googleapis.com/charts
      helm repo update istio

      ISTIO_VERSION=1.28.3
      helm install istio istio/base --version $ISTIO_VERSION -n istio-system --create-namespace
      helm install istiod istio/istiod --version $ISTIO_VERSION -n istio-system --wait
      helm install tenant-ingressgateway istio/gateway --version $ISTIO_VERSION -n istio-system
      kubectl apply -f /vagrant/vagrant_dependencies/tenant-gateway.yaml

      # Create the certs
      mkdir certs

      # TODO: this is not the right way to generate the certs I need to go back and fix this later.
      openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=bigbang Inc./CN=bigbang.vp.dev' -keyout certs/ca.key -out certs/ca.crt
      openssl req -out certs/bigbang.vp.dev.csr -newkey rsa:2048 -nodes -keyout certs/bigbang.vp.dev.key -config /vagrant/vagrant_dependencies/req.conf -extensions 'v3_req'
      openssl x509 -req -sha256 -days 365 -CA certs/ca.crt -CAkey certs/ca.key -set_serial 0 -in certs/bigbang.vp.dev.csr -out certs/bigbang.vp.dev.crt

      cat certs/bigbang.vp.dev.crt > certs/chain.crt
      cat certs/ca.crt >> certs/chain.crt

      # Setup istio gateway with certs
      kubectl create -n istio-system secret tls tenant-cert --key=certs/bigbang.vp.dev.key --cert=certs/chain.crt

      echo "Installing Malcolm..." >&2
      kubectl create namespace #{malcolm_namespace}

      # create secret for auth
      kubectl create secret generic -n #{malcolm_namespace} malcolm-auth \
        --from-literal=username="#{malcolm_username}" \
        --from-literal=openssl_password="$(openssl passwd -1 '#{malcolm_password}' | tr -d '\n' | base64 | tr -d '\n')" \
        --from-literal=htpass_cred="$(htpasswd -bnB '#{malcolm_username}' '#{malcolm_password}' | head -n1)"

      # Install Malcolm enabling istio (commented out for dev/testing so I can deploy it manually)
      helm lint /vagrant/chart || echo "Helm linting failed!" >&2
      helm template malcolm /vagrant/chart -n #{malcolm_namespace} >/tmp/malcolm_rendered.yaml
      kubeconform -strict -ignore-missing-schemas /tmp/malcolm_rendered.yaml || echo "kubeconfirm failed!" >&2
      rm -f /tmp/malcolm_rendered.yaml
      helm install malcolm /vagrant/chart -n #{malcolm_namespace} --dry-run --set auth.existingSecret=malcolm-auth --set istio.enabled=true --set ingress.enabled=false --set pcap_capture_env.pcap_iface=#{vm_nic} >/dev/null || echo "Helm install --dry-run failed!" >&2
      helm install malcolm /vagrant/chart -n #{malcolm_namespace} --set auth.existingSecret=malcolm-auth --set istio.enabled=true --set ingress.enabled=false --set pcap_capture_env.pcap_iface=#{vm_nic}

      grep -qxF '10.0.2.100 malcolm.vp.bigbang.dev malcolm.test.dev' /etc/hosts || echo '10.0.2.100 malcolm.vp.bigbang.dev malcolm.test.dev' >> /etc/hosts
      echo "You may now ssh to your kubernetes cluster using ssh -p 2222 vagrant@localhost" >&2
      hostname -I
    SHELL
  else
    config.vm.provision "shell", inline: <<-SHELL
      echo "Waiting for rke2-ingress-nginx-controller-admission..." >&2
      until kubectl get endpoints --namespace kube-system 2>/dev/null | grep -Pq "rke2-ingress-nginx-controller-admission\\s+.+:\\d+"; do
        sleep 20
      done
      echo "rke2-ingress-nginx-controller-admission is present" >&2
      sleep 5

      echo "Installing Malcolm..." >&2
      kubectl create namespace #{malcolm_namespace}

      # create secret for auth
      kubectl create secret generic -n #{malcolm_namespace} malcolm-auth \
        --from-literal=username="#{malcolm_username}" \
        --from-literal=openssl_password="$(openssl passwd -1 '#{malcolm_password}' | tr -d '\n' | base64 | tr -d '\n')" \
        --from-literal=htpass_cred="$(htpasswd -bnB '#{malcolm_username}' '#{malcolm_password}' | head -n1)"

      # Install Malcolm (commented out for dev/testing so I can deploy it manually)
      helm lint /vagrant/chart || echo "Helm linting failed!" >&2
      helm template malcolm /vagrant/chart -n #{malcolm_namespace} >/tmp/malcolm_rendered.yaml
      kubeconform -strict -ignore-missing-schemas /tmp/malcolm_rendered.yaml || echo "kubeconfirm failed!" >&2
      rm -f /tmp/malcolm_rendered.yaml
      helm install malcolm /vagrant/chart -n #{malcolm_namespace} --dry-run --set auth.existingSecret=malcolm-auth --set istio.enabled=false --set ingress.enabled=true --set pcap_capture_env.pcap_iface=#{vm_nic} >/dev/null || echo "Helm install --dry-run failed!" >&2
      helm install malcolm /vagrant/chart -n #{malcolm_namespace} --set auth.existingSecret=malcolm-auth --set istio.enabled=false --set ingress.enabled=true --set pcap_capture_env.pcap_iface=#{vm_nic}

      echo "You may now ssh to your kubernetes cluster using ssh -p 2222 vagrant@localhost" >&2
      hostname -I
    SHELL
  end

end

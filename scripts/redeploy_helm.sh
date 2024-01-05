#!/bin/bash

kubectl delete namespace malcolm
helm install malcolm /vagrant/chart -n malcolm --create-namespace --set istio.enabled=false --set ingress.enabled=true --set pcap_capture_env.pcap_iface=enp0s8
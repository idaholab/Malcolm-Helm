#!/bin/bash
namespace="malcolm"
pod_names=$(kubectl get pod -n "$namespace" -o jsonpath='{.items[*].metadata.name}')

IFS=" " read -ra names <<< "$pod_names"

for name in "${names[@]}"; do
  echo "Pod Name: $name"
  kubectl exec $name -n $namespace -- supervisorctl status
  echo ""
done

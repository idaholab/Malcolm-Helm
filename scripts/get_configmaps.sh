#!/bin/bash
namespace="malcolm"
config_map_file_name="malcolm_configmapsv2.yaml"
configmap_names=$(kubectl get configmaps -n "$namespace" -o jsonpath='{.items[*].metadata.name}')

IFS=" " read -ra names <<< "$configmap_names"


rm -f $config_map_file_name
for name in "${names[@]}"; do
  echo "ConfigMap Name: $name"
  # You can perform actions on each ConfigMap here
  # For example, you can kubectl describe, kubectl edit, or any other operation
  echo "---" >> $config_map_file_name
  kubectl get configmap $name -n $namespace -o yaml >> $config_map_file_name
  echo "" >> $config_map_file_name
done

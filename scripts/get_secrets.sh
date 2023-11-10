#!/bin/bash
namespace="malcolm"
secret_file_name="malcolm_secrets.yaml"
secret_names=$(kubectl get secret -n "$namespace" -o jsonpath='{.items[*].metadata.name}')

IFS=" " read -ra names <<< "$secret_names"


rm -f $secret_file_name
for name in "${names[@]}"; do
  echo "ConfigMap Name: $name"
  # You can perform actions on each ConfigMap here
  # For example, you can kubectl describe, kubectl edit, or any other operation
  echo "---" >> $secret_file_name
  kubectl get secret $name -n $namespace -o yaml >> $secret_file_name
  echo "" >> $secret_file_name
done

#!/bin/bash

# Create the configmap for the arkime config.ini file from the patch.
set -o errexit -o nounset -o pipefail

if [ $# != 1 ]; then
    >&2 echo "Usage: $0 <originalArkimeConfig>"
    exit 1
fi

original_config_path="$1"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
base_dir=$(readlink -f "$script_dir/../..")
template_path="$script_dir/arkime-ini.yml"
patch_path="$script_dir/patch.txt"
output_path="$base_dir/chart/templates/arkime-ini.yml"

# Create the patched file.
patched_path="/tmp/create-arkime-config/config.ini"
mkdir -p "$(dirname "$patched_path")"
patch -o "$patched_path" "$original_config_path" "$patch_path"

# Create the configmap from the template and the patched config.ini file.
yq  eval ".data[\"config.ini\"] |= load_str(\"$patched_path\")" "$template_path" > "$output_path"

# View the result using the following:
yq '.data["config.ini"]' "$output_path"

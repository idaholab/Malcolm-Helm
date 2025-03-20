#!/bin/bash

# Create the patch used to update the arkime configuration.
set -o errexit -o nounset -o pipefail

if [ $# != 3 ]; then
    >&2 echo "Usage: $0 <originalArkimeConfig> <updatedArkimeConfig> <patchFile>"
    exit 1
fi

original_path="$1"
updated_path="$2"
patch_path="$3"

diff -u "$original_path" "$updated_path" > "$patch_path"

#!/bin/zsh
source "$PWD/functions.zsh"

# config_file="config.yaml"
# query=".jdk.version"
# yq_path="./yq_darwin_arm64"
# result=$(get_config_value "$config_file" "$query" "./yq_darwin_arm64")
# echo "Result (yq installed): $result"


#cat "$config_file" | "$yq_path" "$query" | echo
#toolchain_path=~/ds/toolchain

# toolchain_path=$HOME/ds/toolchain
# expanded_path=$(get_expanded_home_folder "$toolchain_path")

# echo "$expanded_path"

if [[ ! -x "yq" ]]; then
    echo "yq not found"
else
    echo "yq found"
fi

if command_exists "yq"; then
    echo "command yq exists"
fi 

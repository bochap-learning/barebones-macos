#!/bin/zsh
source "$PWD/functions.zsh"
set -e

install_yq() {
  if command_exists "yq"; then
    echo "yq already installed"
    return 0
  fi
  local app="yq"  
  local version="v4.44.6"
  local binary="yq_darwin_arm64"
  local temp_folder=$(generate_temp_folder)
  local parser="$temp_folder/$app"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
  local url="https://github.com/mikefarah/yq/releases/download/$version/$binary"
  if ! install_curled_binary "$parser" "$app" "$profile_file" "$url" "$temp_folder"; then
    return 1
  fi
  return  0
}

uninstall_yq() {
  if ! command_exists "yq"; then
    echo "yq not installed"
    return 0
  fi
  local app="yq"
  if ! uninstall_curled_binary "yq" "$app" "$profile_file"; then
    return 1
  fi
  return  0    
}

required_setup() {
  install_yq
  # source "$profile_file"    # Additional source to pick up yq used by the rest of the code
}

required_cleanup() {
  uninstall_yq
}

typeset action=$1
typeset config_file=$2
typeset profile_file=$3

echo "Started prerequisites $action"
result=0
case "$action" in
provision)
  if ! required_setup; then
    result=1
  fi
  ;;
deprovision)
  if ! required_cleanup; then
    result=1
  fi
  ;;  
*)
  echo "Error: Invalid action. Must be 'provision' or 'deprovision'." >&2
  result=1 # Invalid action
  ;;
esac
echo "Completed prerequisites $action"
return $result

#!/bin/zsh
source "$PWD/functions.zsh"
set -e

typeset action="$1"
typeset config_file="$2"
typeset profile_file="$3"

typeset pyenv_root="${HOME}/.pyenv"

install_pyenv() {
  if [[ -d "$pyenv_root" ]]; then
   echo "pyenv is already installed at $pyenv_root. Skipping installation." >&2
   return 0
  fi

  if ! curl https://pyenv.run | bash; then
   echo "Unable to install pyenv." >&2
   return 1
  fi

  local section="pyenv"
  local content=$(cat << EOF
export PYENV_ROOT="\$HOME/.pyenv"
[[ -d \$PYENV_ROOT/bin ]] && export PATH="\$PYENV_ROOT/bin:\$PATH"
eval "\$(pyenv init -)"
EOF
  )
  if ! add_profile_section "$profile_file" "$section" "$content"; then
    return 1
  fi

  # Reload .zshrc
  source ~/.zshrc

  if ! command -v pyenv &> /dev/null; then
    echo "pyenv installation failed. Please check the output for errors."
    return 1
  fi

  echo "Updating pyenv plugins..."
  if ! pyenv update; then
    echo "Error: pyenv update failed." >&2
    return 1
  fi

  local python_version=$(pyenv install --list | grep --extended-regexp "^\s*[0-9][0-9.]*[0-9]\s*$" | tail -1 | tr -d ' ')
  echo "Latest Python version available: $python_version"

  # Check if the Python version is already installed
  if pyenv versions | grep -q "$python_version"; then
    echo "Python $python_version is already installed."
  else
    # Install the latest Python version
    echo "Installing Python $python_version..."
    if ! pyenv install "$python_version"; then
      echo "Error: Installation of Python $python_version failed." >&2
      return 1
    fi
  fi

  # Set the local pyenv version (important!)
  echo "Setting local pyenv version to $python_version..."
  if ! pyenv local "$python_version"; then
    echo "Error: Setting local pyenv version failed." >&2
    return 1
  fi

  # Set the global pyenv version (important!)
  echo "Setting global pyenv version to $python_version..."
  if ! pyenv global "$python_version"; then
    echo "Error: Setting global pyenv version failed." >&2
    return 1
  fi

  echo "pyenv installed successfully."
  return 0
}

uninstall_pyenv() {
  if [[ ! -d "$pyenv_root" ]]; then
    echo "pyenv not installed" >&2
    return 0
  fi

  rm -rf "$pyenv_root"
  if [[ $? -ne 0 ]]; then
      echo "Error removing pyenv directory"
      return 1
  fi
  # Remove pyenv shims (if they exist)
  local pyenv_shims="/usr/local/bin/pyenv" # Common location
  if [[ -e "$pyenv_shims" ]]; then
      echo "Removing pyenv shims: $pyenv_shims"
      sudo rm -f "$pyenv_shims"
      if [[ $? -ne 0 ]]; then
          echo "Error removing pyenv shims"
          return 1
      fi
  fi

  local pyenv_shims_other=$(find /usr/local/bin -name "pyenv")
  if [[ -n "$pyenv_shims_other" ]]; then
      echo "Removing pyenv shims: $pyenv_shims_other"
      sudo rm -f "$pyenv_shims_other"
      if [[ $? -ne 0 ]]; then
          echo "Error removing pyenv shims"
          return 1
      fi
  fi
  local section="pyenv"
  if ! remove_section "$profile_file" "$section"; then
    return 1
  fi
}

install_kn() {
  if command_exists "kn"; then
    echo "kn already installed"
    return 0
  fi
  local app="kn"  
  local temp_folder=$(generate_temp_folder)
  if [[ $? -ne 0 ]]; then
    return 1
  fi
  local url="https://github.com/knative/client/releases/download/knative-v1.16.1/kn-darwin-arm64"
  if ! install_curled_binary "yq" "$app" "$profile_file" "$url" "$temp_folder"; then
    return 1
  fi
  return  0
}

uninstall_kn() {
  if ! command_exists "kn"; then
    echo "kn not installed"
    return 0
  fi
  local app="kn"
  if ! uninstall_curled_binary "yq" "$app" "$profile_file"; then
    return 1
  fi
  return  0    
}

install_jq() {
  if command_exists "jq"; then
    echo "jq already installed"
    return 0
  fi
  local app="jq"  
  local temp_folder=$(generate_temp_folder)
  if [[ $? -ne 0 ]]; then
    return 1
  fi
  local url="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-arm64"
  if ! install_curled_binary "yq" "$app" "$profile_file" "$url" "$temp_folder"; then
    return 1
  fi
  return  0
}

uninstall_jq() {
  if ! command_exists "jq"; then
    echo "jq not installed"
    return 0
  fi
  local app="jq"
  if ! uninstall_curled_binary "yq" "$app" "$profile_file"; then
    return 1
  fi
  return  0    
}

typeset VENV_NAME="data_platform"

setup_venv() {
  local env_folder=$(get_config_value "$config_file" "$QUERY_ENV_PATH" "yq")
  local venv_path="${HOME}/$env_folder/$VENV_NAME"
  echo "$venv_path setup started..."  
  
  # Check if pyenv is installed
  if ! command -v pyenv >/dev/null 2>&1; then
    echo "Error: pyenv is not installed. Please install pyenv first." >&2
    return 1
  fi

  if [[ -d $venv_path ]]; then
    echo "$venv_path already setup." >&2
    return 0
  fi

  python -m venv "$venv_path"
  source "$venv_path/bin/activate"
  $venv_path/bin/pip install -U pip setuptools
  $venv_path/bin/pip install poetry
  $venv_path/bin/pip install temporalio
  $venv_path/bin/pip install alembic
  $venv_path/bin/pip install python-dotenv
  $venv_path/bin/pip install oci-cli

  local section="venv"
  local content=$(cat << EOF
source "$venv_path/bin/activate"
EOF
  )
  if ! add_profile_section "$profile_file" "$section" "$content"; then
    return 1
  fi

  # Reload .zshrc
  source ~/.zshrc
  echo "$venv_path setup completed"
}

cleanup_venv() {
  local section="venv"
  local env_folder=$(get_config_value "$config_file" "$QUERY_ENV_PATH" "yq")
  local venv_path="${HOME}/$env_folder/$VENV_NAME"
  echo "$venv_path cleanup started..."
  if ! [[ -d $venv_path ]]; then
    echo "$venv_path not setup." >&2
    return 0
  fi
  rm -rf "$venv_path"
  if ! remove_section "$profile_file" "$section"; then
    return 1
  fi
  echo "$venv_path cleanup completed"
  return 0
}


clone_repositories() {
  local query_path=$(get_config_value "$config_file" "$QUERY_REPO_PATH" "yq")
  local root_path="${HOME}/$query_path"
  # Check if destination directory exists and create it if not
  mkdir -p "$root_path"

  local repo_path
  # Extract repositories using yq and loop through them
  yq eval '.repository[]' "$config_file" | while read -r repo; do
    local repo_name="${repo##*/}" # Extract repository name
    repo_name="${repo_name%.git}" # Remove .git extension
    local repo_path="$root_path/$repo_name"

    if [[ -d "$repo_path" ]]; then
      echo "Repository '$repo_path' already exists. Skipping clone."
      continue # Skip to the next repository
    fi

    echo "Cloning '$repo' to '$repo_path'..."
    git clone "$repo" "$repo_path"
    if [[ $? -ne 0 ]]; then
      echo "Error cloning '$repo'. Continuing with other repositories..." >&2
    fi
  done
  return 0
}

cleanup_repositories() {
  local query_path=$(get_config_value "$config_file" "$QUERY_REPO_PATH" "yq")
  local root_path="${HOME}/$query_path"
  local repo_path

  # Extract repositories using yq and loop through them
  yq eval '.repository[]' "$config_file" | while read -r repo; do
    local repo_name="${repo##*/}" # Extract repository name
    repo_name="${repo_name%.git}" # Remove .git extension
    local repo_path="$root_path/$repo_name"

    if ! [[ -d "$repo_path" ]]; then
      echo "Repository '$repo_path' doesn't exists. Skipping remove."
      continue # Skip to the next repository
    fi

    echo "Removing '$repo' at '$repo_path'..."
    rm -rf "$repo_path"
    if [[ $? -ne 0 ]]; then
      echo "Error removing '$repo'. Continuing with other repositories..." >&2
    fi
  done
  return 0
}

non_sudo_setup() {
  if ! install_pyenv; then
    return 1
  fi

  if ! install_kn; then
    return 1
  fi

  if ! setup_venv; then
    return 1
  fi

  if ! clone_repositories; then
    return 1
  fi
}

non_sudo_cleanup() {
  if ! cleanup_repositories; then
    return 1
  fi
  if ! cleanup_venv; then
    return 1
  fi

  if ! uninstall_kn; then
    return 1
  fi

  if ! uninstall_pyenv; then
    return 1
  fi    
}

echo "Started non sudo $action"
result=0
case "$action" in
provision)
  if ! non_sudo_setup; then
    result=1
  fi
  ;;
deprovision)
  if ! non_sudo_cleanup; then
    result=1
  fi
  ;;  
*)
  echo "Error: Invalid action. Must be 'provision' or 'deprovision'." >&2
  result=1 # Invalid action
  ;;
esac
echo "Completed non sudo $action"
return $result

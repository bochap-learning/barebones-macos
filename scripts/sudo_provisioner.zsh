#!/bin/zsh
source "$PWD/functions.zsh"
set -e

# Function to check if command line tools are installed
is_command_line_tools_installed() {
  if xcode-select -p &>/dev/null; then
    return 0 # Installed
  else
    return 1 # Not installed
  fi
}

# Function to install Xcode Command Line Tools unattended (as much as possible)
install_xcode_cli() {
  echo "Installing Xcode Command Line..."
  # Check if command line tools are installed
  if is_command_line_tools_installed; then
    echo "Xcode Command Line Tools are already installed."
    return 0 # Installed
  else
    # Attempt to install using xcode-select
    if xcode-select --install &>/dev/null; then
      echo "The Xcode Command Line Tools installation process has started."
      echo "A dialog box has appeared. Please click 'Install' to continue."
      # Wait for user interaction (using read)
      echo -n "Press any key to continue after completing the installation in the dialog box..." # -n prevents a newline
      read -s -n 1

      # Check installation again after user interaction
      if is_command_line_tools_installed; then
        echo "Xcode Command Line Tools installed successfully."
        return 0
      else
        echo "Error: Installation appears to have failed or was cancelled." >&2
        return 1
      fi
    else
      echo "Error: Failed to install Xcode Command Line Tools." >&2
      return 1
    fi
  fi
}

# Function to uninstall Xcode Command Line Tools unattended
uninstall_xcode_cli() {
  if is_command_line_tools_installed; then
    # Attempt to uninstall using rm -rf (requires sudo)
    local developer_dir=$(xcode-select -p 2>/dev/null)
    if [[ -n "$developer_dir" ]]; then
      sudo rm -rf "$developer_dir"
        if [[ $? -eq 0 ]]; then
            echo "Xcode Command Line Tools uninstalled successfully."
            return 0
        else
            echo "Error: Failed to uninstall Xcode Command Line Tools." >&2
            return 1
        fi
    else
        echo "Xcode Command Line Tools are not installed, nothing to uninstall."
        return 0
    fi
  else
    echo "Xcode Command Line Tools are not installed."
    return 0
  fi
}

# Function to install Docker Desktop
install_docker() {
  local app_name="Docker"
  echo "Installing $app_name..."
  if is_app_installed "$app_name"; then
    echo "$app_name is already installed."
    return 0
  fi

  local download_url=""
  local architecture="arm64"
  echo "Determining download URL..."
  # Get the latest release info from the Docker website (this is fragile and might break)
  download_url=$(curl -sL "https://desktop.docker.com/mac/main/$architecture/appcast.xml" | grep -o "https://desktop.docker.com/mac/.*/Docker.*\.dmg" | head -n 1)

  if ! install_to_applications "docker" $download_url "/Volumes/Docker" "Docker.dmg" "Docker.app"; then
   return 1
  fi

  return 0
}

# Function to uninstall Docker Desktop
uninstall_docker() {
  local app_name="Docker"
  echo "Uninstalling $app_name..."
  if ! is_app_installed "$app_name"; then
    echo "$app_name is not installed."
    return 0
  fi

  echo "Moving $app_name.app to Trash..."
  if ! stop_app  "$app_name"; then
    echo "unable to stop $app_name." >&2
    return 1
  fi

  if ! stop_app "$app_name Desktop"; then
    echo "unable to stop $app_name Desktop." >&2
    return 1
  fi  

  if ! move_app_to_trash "$app_name" "/Applications/$app_name.app"; then
    return 1
  fi
  
  # Remove Docker related files and directories (more thorough cleanup)
  echo "Removing $app_name related files and directories..."

  # Remove configuration files and other data. Be VERY CAREFUL with these paths.
  local app_paths=(
    "~/.docker"
    "~/Library/Application Scripts/com.docker.helper"
    "~/Library/Containers/com.docker.docker"
    "~/Library/Containers/com.docker.helper"
    "~/Library/Group Containers/group.com.docker"
    "~/Library/Preferences/com.docker.docker.plist"
    "~/Library/Saved Application State/com.electron.docker-frontend.savedState"
    "/Library/PrivilegedHelperTools/com.docker.socket"
    "/usr/local/bin/docker"
    "/usr/local/bin/docker-compose"
    "/usr/local/bin/docker-credential-desktop"
    "/usr/local/lib/docker"
  )
  for path in "${app_paths[@]}"; do
    if [[ -e "$path" ]]; then
      echo "Removing: $path"
      sudo rm -rf "$path"
    fi
  done

  echo "$app_name uninstallation complete."
  return 0
}

# Function to install VS Code unattended
install_vscode() {
  local app_name="Visual Studio Code"
  echo "Installing $app_name..."
  # Check if VS Code is already installed
  if is_app_installed "$app_name"; then
    echo "$app_name is already installed."
    return 0
  fi

  local temp_folder=$(generate_temp_folder)
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Download the VS Code installer
  if ! curl -o "$temp_folder/vscode.zip" -L "https://code.visualstudio.com/sha/download?build=stable&os=darwin-universal"; then
    echo "Error downloading $app_name installer."
    rm -rf "$temp_folder"
    return 1
  fi

  # Unzip the installer
  if ! unzip "$temp_folder/vscode.zip" -d "$temp_folder"; then
    echo "Error unzipping $app_name installer."
    rm -rf "$temp_folder"
    return 1
  fi

  # Move the application to the Applications folder (requires sudo)
  if ! sudo mv "$temp_folder/$app_name.app" /Applications/; then
    echo "Error installing $app_name into applications"
    rm -rf "$temp_folder"
    return 1    
  fi

  # Clean up
  rm -rf "$temp_folder"

  echo "$app_name installed successfully."
  return 0
}

# Function to uninstall VS Code unattended
uninstall_vscode() {
  local app_name="Visual Studio Code"
  echo "Uninstalling $app_name..."
  if ! is_app_installed "$app_name"; then
    echo "$app_name is not installed."
    return 0
  fi
  
  echo "Moving $app_name.app to Trash..."
  if ! stop_app  "$app_name"; then
    echo "unable to stop $app_name." >&2
    return 1
  fi

  if ! move_app_to_trash "$app_name" "/Applications/$app_name.app"; then
    return 1
  fi

  echo "$app_name uninstalled successfully."
  return 0
}

# Function to install Slack
install_slack() {
  local app_name="Slack"
  echo "Installing $app_name..."
  if is_app_installed "$app_name"; then
    echo "slack is already installed."
    return 0
  fi

  local download_url="https://slack.com/api/desktop.latestRelease?arch=universal&variant=dmg&redirect=true"
  if ! install_to_applications "slack" $download_url "/Volumes/$app_name" "$app_name.dmg" "$app_name.app"; then
   return 1
  fi
  return 0
}

uninstall_slack() {
  local app_name="Slack"
  echo "Uninstalling $app_name..."
  if ! is_app_installed "$app_name"; then
    echo "$app_name is not installed."
    return 0
  fi
  
  echo "Moving $app_name.app to Trash..."
  if ! stop_app  "$app_name"; then
    echo "unable to stop $app_name." >&2
    return 1
  fi

  if ! move_app_to_trash "$app_name" "/Applications/$app_name.app"; then
    return 1
  fi

  # Remove $app_name related files and directories (more thorough cleanup)
  echo "Removing $app_name related files and directories..."

  local app_paths=(
    "~/Library/Application Scripts/com.tinyspeck.slackmacgap"
    "~/Library/Containers/com.tinyspeck.slackmacgap"
    "~/Library/Group Containers/group.com.tinyspeck.slackmacgap"
    "~/Library/Preferences/com.tinyspeck.slackmacgap.plist"
    "~/Library/Saved Application State/com.tinyspeck.slackmacgap.savedState"
  )

  for path in "${app_paths[@]}"; do
    if [[ -e "$path" ]]; then
      echo "Removing: $path"
      sudo rm -rf "$path"
        if [[ $? -ne 0 ]]; then
            echo "Error removing $path"
            return 1
        fi
    fi
  done
  echo "$app_name uninstalled successfully."
  return 0
}

install_aws_cli() {
  local app_name="aws"
  local url="https://awscli.amazonaws.com/AWSCLIV2.pkg"
  echo "Installing $app_name..."  
  if command_exists "$app_name"; then
    echo "$app_name is already installed"
    return 0
  fi
  if ! install_curled_package "$app_name" "$url"; then
    return 1
  fi
  return 0
}

uninstall_aws_cli() {
  local app_name="aws"
  if ! command_exists "$app_name"; then
    echo "$app_name is not installed."
    return 0
  fi  
  sudo rm /usr/local/bin/aws
  if [[ -f /usr/local/bin/aws ]]; then
    echo "Error: Unabled to delete /usr/local/bin/aws" >&2
    return 1
  fi
  sudo rm /usr/local/bin/aws_completer
  if [[ -f /usr/local/bin/aws_completer ]]; then
    echo "Error: Unabled to delete /usr/local/bin/aws_completer" >&2
    return 1
  fi  
  sudo rm -rf /usr/local/aws-cli
  if [[ -d /usr/local/aws-cli ]]; then
    echo "Error: Unabled to delete /usr/local/aws-cli" >&2
    return 1
  fi      
  return 0
}


typeset JDK_FOLDER="jdk-23.0.1.jdk"
install_java() {
  local app_name="java"
  local url="https://download.java.net/java/GA/jdk23.0.1/c28985cbf10d4e648e4004050f8781aa/11/GPL/openjdk-23.0.1_macos-aarch64_bin.tar.gz"
  local filename="${url##*/}"
  echo "Installing $app_name..."
  if [[ -d "/Library/Java/JavaVirtualMachines/$JDK_FOLDER" ]]; then
    echo "$app_name is already installed"
    return 0
  fi

  local temp_folder=$(generate_temp_folder)
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  local output_path="$temp_folder/$filename"
  if ! curl -o "$output_path" -L "$url"; then
    echo "Error downloading $app."
    rm -rf "$temp_folder"
    return 1
  fi

  if ! tar -xzf "$temp_folder/$filename" -C "$temp_folder"; then
    echo "Error: Extraction failed." >&2
    return 1
  fi

  if ! sudo mv "$temp_folder/$JDK_FOLDER" "/Library/Java/JavaVirtualMachines"; then
    echo "Error: JDK installation failed." >&2
    return 1
  fi
  rm -rf "$temp_folder"
  
  local section="jdk"
  local content=$(cat << EOF
export JAVA_HOME=/Library/Java/JavaVirtualMachines/$JDK_FOLDER/Contents/Home
EOF
  )
  if ! add_profile_section "$profile_file" "$section" "$content"; then
    return 1
  fi
  return  0
}

uninstall_java() {
  if ! [[ -d "/Library/Java/JavaVirtualMachines/$JDK_FOLDER" ]]; then
    echo "$app_name is not installed"
    return 0
  fi

  if ! sudo rm -rf /Library/Java/JavaVirtualMachines/$JDK_FOLDER; then
    echo "Error: JDK uninstallation failed." >&2
    return 1  
  fi
  local section="jdk"
  if ! remove_section "$profile_file" "$section"; then
    return 1
  fi  
}

sudo_setup() {
  if ! install_xcode_cli; then
    return 1
  fi
  if ! install_docker; then
    return 1
  fi
  if ! install_aws_cli; then
    return 1
  fi
  if ! install_java; then
    return 1
  fi
  if ! install_vscode; then
    return 1
  fi
  if ! install_slack; then
    return 1
  fi
  return 0
}

sudo_cleanup() {
  if ! uninstall_slack; then
    return 1
  fi  
  if ! uninstall_vscode; then
    return 1
  fi
  if ! uninstall_java; then
    return 1
  fi  
  if ! uninstall_aws_cli; then
    return 1
  fi  
  if ! uninstall_docker; then
    return 1
  fi  
  if ! uninstall_xcode_cli; then
    return 1
  fi
  return 0  
}

typeset action=$1
typeset config_file=$2
typeset profile_file=$3

# Check if the script is being run as root
if [[ $UID -ne 0 ]]; then
  echo "This script requires root privileges."
  echo "Please run it with sudo."
  exit 1
fi

echo "Started sudo $action"
result=0
case "$action" in
provision)
  if ! sudo_setup; then
    result=1
  fi
  ;;
deprovision)
  if ! sudo_cleanup; then
    result=1
  fi
  ;;  
*)
  echo "Error: Invalid action. Must be 'provision' or 'deprovision'." >&2
  result=1 # Invalid action
  ;;
esac

echo "Completed sudo $action"
return $result


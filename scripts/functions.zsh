#!/bin/zsh

typeset QUERY_TOOLCHAIN_PATH=".general.toolchain_path"
typeset QUERY_REPO_PATH=".general.repo_path"
typeset QUERY_ENV_PATH=".general.env_path"

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check if a value is in a comma-separated string (using regex)
is_value_in_comma_delimited() {
  local value="$1"
  local string="$2"

  # Construct the regular expression
  regex="(^|,)$value(,|$)"  

  # Use the =~ operator for regex matching
  if [[ "$string" =~ $regex ]]; then
    return 0  # True
  else
    return 1  # False
  fi
}

# Function to check if a path is valid
is_valid_file() {
  local file_path="$1"

  # Check if the path exists
  if [ -e "$file_path" ]; then
    return 0  # True
  else
    return 1  # False
  fi
}

# Function to trim whitespace from from and back of string
trim_whitespace() {
  local str="$1"
  # Remove leading spaces and tabs
  str=${str##*[ \t]}
  # Remove trailing spaces and tabs
  str=${str%%[ \t]*}
  echo "$str"
}

create_file() {
  local file_path="$1"
  if ! is_valid_file $file_path; then
    touch "$file_path"
    echo "Created file: $file_path"
  fi
}

# Function to create a temporary folder and return the name
generate_temp_folder() {
  # Generate a random string using `uuidgen` and extract the first part
  local random_string=$(uuidgen | cut -d '-' -f1)
  local temp_folder="/tmp/temp_${random_string}"
  if ! create_folder "$temp_folder"; then
    echo "Error creating temp folder."
    return 1
  fi
  echo "$temp_folder"
  return 0
}

create_folder() {
  local folder_path=$1
  if mkdir -p "$folder_path"; then # Create the full path in one command
    return 0
  else
    echo "Error: Failed to create folder '$folder_path'." >&2
    return 1
  fi
}

is_valid_command_or_executable() {
  local cmd="$1"
  if ! command_exists "$cmd"; then
    if [[ ! -x "$cmd" ]]; then
      echo "Error: '$cmd' is neither a command nor an executable." >&2
      return 1
    fi
  fi
  return 0
}

get_config_value() {
  if [[ $# -lt 3 ]]; then # Check if at least 2 arguments are provided
    echo "Error: config path and query are required arguments." >&2
    return 1
  fi
  local config="$1"
  local query="$2"
  local parser="$3"

  if ! is_valid_command_or_executable "$parser"; then
    return 1
  fi

  if ! is_valid_file "$config"; then
    echo "Error: '$config' is not a valid file path." >&2
    return 1
  fi

  # Now execute yq with the correct path
  result=$(cat "$config" | "$parser" "$query")
  echo $result
  return 0
}

# Global prefixes for section markers
typeset BEGIN_PREFIX="begin_barebones_"
typeset END_PREFIX="end_barebones_"

# Function to add a section to a file with start and end markers
add_profile_section() {
  local file="$1"
  local section_name="$2"
  local section_content="$3"
  local begin_marker="# ${BEGIN_PREFIX}${section_name}"
  local end_marker="# ${END_PREFIX}${section_name}"

  # Check if the section already exists
  if grep -q "^$begin_marker$" "$file"; then
    echo "Section '$section_name' already exists in '$file'." >&2
    return 1
  fi

  # Add the section to the file
  {
    echo "$begin_marker"
    echo "$section_content"
    echo "$end_marker"
  } >> "$file"

  echo "Section '$section_name' added to '$file'."
  return 0
}

# Function to remove a section from a file
remove_section() {
  local file="$1"
  local section_name="$2"

  local begin_marker_regex="^# ${BEGIN_PREFIX}${section_name}$"
  local end_marker_regex="^# ${END_PREFIX}${section_name}$"
  # Use sed to remove the section
  if sed -i.bak -e "/$begin_marker_regex/,/$end_marker_regex/d" "$file"; then
    echo "Section '$section_name' removed from '$file'."
    return 0
  else
    echo "Section '$section_name' not found in '$file'." >&2
    return 1
  fi
}

validate_action() {
  local action=$1
  case "$action" in
    provision|deprovision)
    return 0 # Valid action
    ;;
  *)
    echo "Error: Invalid action. Must be 'provision' or 'deprovision'." >&2
    return 1 # Invalid action
    ;;
  esac
}

stop_app() {
    local app_name="$1"
    # Stop app if it's running (important!)
    if pgrep -q -f "$app_name" >/dev/null; then
      echo "Stopping $app_name..."
      osascript -e "quit app \"$app_name\""
      sleep 10 # Give it a few seconds to quit
    fi
    return 0
}

# Function to move an application to the Trash
move_app_to_trash() {
  local app_name="$1"
  local app_path="$2"

  if [[ -z "$app_path" ]]; then
    echo "Error: Application path not provided." >&2
    return 1
  fi

  if [[ ! -d "$app_path" ]]; then
    echo "Error: Application not found at: $app_path" >&2
    return 1
  fi

  # Use osascript to move to Trash (handles permissions correctly)
  if sudo osascript -e "tell application \"Finder\" to move POSIX file \"$app_path\" to trash" >/dev/null 2>&1; then
    echo "$app_path moved to Trash successfully."
    return 0
  else
    echo "Error: Failed to move $app_path to Trash." >&2
    return 1
  fi
}

# Function to install a binary using curl
install_curled_binary() {
  local parser="$1"
  local app="$2"
  local profile_file="$3"
  local url="$4"
  local temp_folder
  if [[ $# -eq 5 ]]; then
    temp_folder="$5"
  else
    temp_folder=$(generate_temp_folder)
    if [[ $? -ne 0 ]]; then
      return 1
    fi
  fi

  local output_path="$temp_folder/$app"
  local section="$app"

  if command_exists "$app"; then
    echo "$app already installed"
    return 0
  fi
  
  if ! curl -o "$output_path" -L "$url"; then
    echo "Error downloading $app."
    rm -rf "$temp_folder"
    return 1
  fi
  chmod +x "$output_path"

  local toolchain_folder=$(get_config_value "$config_file" "$QUERY_TOOLCHAIN_PATH" "$parser")
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  local app_folder="$toolchain_folder/$app"
  if ! create_folder "${HOME}/$app_folder"; then
    echo "Error creating folder for $app."
    rm -rf "$temp_folder"
    return 1
  fi

  mv "$output_path" "${HOME}/$app_folder"
  rm -rf "$temp_folder"
  
  local content='export PATH="$HOME/'"$app_folder"':$PATH"'
  if ! add_profile_section "$profile_file" "$section" "$content"; then
    return 1
  fi
  echo "$app installation completed"
  return 0
}

uninstall_curled_binary() {
  local parser="$1"
  local app="$2"
  local profile_file="$3"
  local section="$app"
  if ! command_exists "$app"; then
    echo "$app not installed"
    return 0
  fi

  local toolchain_folder=$(get_config_value "$config_file" "$QUERY_TOOLCHAIN_PATH" "$parser")
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  local app_folder="${HOME}/$toolchain_folder/$app"
  rm -rf "$app_folder"
  if ! remove_section "$profile_file" "$section"; then
    return 1
  fi
  echo "$app uninstallation completed"
  return 0
}


# Function to install a package using curl
install_curled_package() {
  local app="$1"
  local url="$2"
  local temp_folder=$(generate_temp_folder)
  local output_path="$temp_folder/$app"
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  if command_exists "$app"; then
    echo "$app already installed"
    return 0
  fi
  
  if ! curl -o "$output_path.pkg" -L "$url"; then
    echo "Error downloading $app."
    rm -rf "$temp_folder"
    return 1
  fi
  sudo installer -pkg $output_path.pkg -target /
  echo "$app installation completed"
  return 0
}

# Function to download and copy *.app into applications folder
install_to_applications() {
  local app="$1"
  local download_url="$2"
  local volume="$3"
  local dmg_name="$4"
  local app_name="$5"
  local mounted_dmg=""
  local temp_folder=$(generate_temp_folder)
  if [[ $? -ne 0 ]]; then
    return 1
  fi
  local dmg_path="$temp_folder/$dmg_name"

  if [[ -z "$download_url" ]]; then
    echo "Error: Could not determine Docker download URL. The $app website structure may have changed." >&2
    return 1
  fi

  echo "Downloading $app from: $download_url"
  # Download the DMG
  curl -L -o "$dmg_path" "$download_url"
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download $app DMG." >&2
    rm -f "$dmg_path"
    return 1
  fi

  echo "Mounting DMG..."
  hdiutil attach "$dmg_path" -nobrowse -quiet
  mounted_dmg=$(hdiutil info | grep "$volume" | awk '{print $3}')
  if [[ -z "$mounted_dmg" ]]; then
    echo "Error: Failed to mount $app DMG." >&2
    rm -f "$dmg_path"
    return 1
  fi

  echo "Copying $app to /Applications..."
  sudo ditto "$mounted_dmg/$app_name" "/Applications/$app_name"
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to copy $app to /Applications." >&2
    hdiutil detach "$mounted_dmg" -quiet
    rm -f "$dmg_path"
    return 1
  fi

  echo "Detaching DMG..."
  hdiutil detach "$mounted_dmg" -quiet
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to detach $app DMG" >&2
        rm -f "$dmg_path" # Clean up downloaded file
        return 1
    fi

  echo "Cleaning up DMG..."
  rm -f "$dmg_path"

  echo "$app installed successfully."
  return 0  
}

# Function to check if *.app is installed in applications folder
is_app_installed() {
  local app="$1"
  [[ -d "/Applications/$app.app" ]]
}
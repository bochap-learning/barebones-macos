#!/bin/zsh
source "$PWD/functions.zsh"

# Function to display usage information
usage() {
  echo "Usage: $0 [options]"
  echo "  -h, --help                      Display this help message"
  echo "  -a, --action <action>           Required: Action value (provision or deprovision)"
  echo "  -c, --config <config file path> Required: file path to configuration file."
  echo "  -v, --verbose                   Optional: Verbose mode. Defaults to not present or false"
}

parse_option() {
  local option="$1"
  local argument="$2"
  if [[ $option == "a" ]]; then
    argument=$(echo "$argument" | tr '[:upper:]' '[:lower:]')
  fi
  argument=$(trim_whitespace "$argument")
  echo "$argument"
}

# Initialize variables
option_specification="a:c:ht:v-:"
typeset -A long_options
long_options["action"]="a"
long_options["config"]="c"
long_options["help"]="h"
long_options["verbose"]="v"

typeset -A short_options
short_options["a"]="action"
short_options["c"]="config"
short_options["h"]="help"
short_options["v"]="verbose"

typeset -A supplied_options

while getopts "$option_specification" option; do
  case $option in
    -) # Long option
      long_option="${OPTARG%%=*}"            # Get long option name (before '=')
      option="${long_options["$long_option"]}" # Translate to short option
      if [[ -z "$option" ]]; then
        echo "Error: Invalid long option: --$long_option" >&2
        exit 1
      fi
      # If long option has argument, extract it
      if [[ "$OPTARG" != "$long_option" ]]; then
        OPTARG="${OPTARG#*=}" # Get value after '='
      else
        OPTARG=""
      fi
      option_value=$(parse_option $option $OPTARG)
      supplied_options["$long_option"]="$option_value"
      ;;
    a|c|h|v)      
      option_value=$(parse_option $option $OPTARG)
      long_option="${short_options["$option"]}" # Translate to long option
      supplied_options["$long_option"]="$option_value"
      ;;
    \?)
      echo "Error: Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
    :)
      echo "Error: Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1)) # Remove parsed options from command line arguments

typeset action="${supplied_options["action"]}"
typeset config_file="${supplied_options["config"]}"
typeset profile_file="${HOME}/.zshrc"

create_file "$profile_file"

# Check that the action option is supplied
if [ -z $action ]; then
  echo "Error: Option -a, --action is required." >&2
  usage
  exit 1
fi

case "$action" in
provision)
  ./required_provisioner.zsh $action $config_file $profile_file || {
    echo "Unable to setup prerequisites"
    exit 1
  }
  source "$profile_file"    # Additional source to pick up yq used by the rest of the code

  sudo ./sudo_provisioner.zsh $action $config_file $profile_file || {
    echo "Unable to setup sudo applications"
    exit 1
  }

  ./non_sudo_provisioner.zsh $action $config_file $profile_file || {
    echo "Unable to setup non sudo applications"
    exit 1
  }
  source "$profile_file"  

  exit 0
  ;;
deprovision)
  ./non_sudo_provisioner.zsh $action $config_file $profile_file || {
    echo "Unable to cleanup non sudo applications"
    exit 1
  }

  sudo ./sudo_provisioner.zsh $action $config_file $profile_file || {
    echo "Unable to cleanup sudo applications"
    exit 1
  }

  ./required_provisioner.zsh $action $config_file $profile_file || {
    echo "Unable to cleanup prerequisites"
    exit 1
  }
  source "$profile_file"

  exit 0
  ;;  
*)
  echo "Error: Invalid action. Must be 'provision' or 'deprovision'." >&2
  exit 1
  ;;
esac
echo "Close and reopen the terminal to ensure the new settings are applied"
exit 0

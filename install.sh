#!/usr/bin/env bash

{ # this ensures that the entire script is downloaded #

#
# set bash flags
# -e : exit immediately if any command exits with a non-zero status
# -u : Treat unset variables and parameters as an error when performing parameters expansion
# -o pipefail - returns a non-zero exit code if any command in the pipeline fails, not just the last one
#
set -euo pipefail

#=============================================================================#
# Utility Functions
#=============================================================================#

#
# report an error and exit
#
# @param string $1 - The error message to display. Defaults to "An unknown error occurred."
# @param integer $2 - The exit code to set. Defaults to 1
#
function err() {
  print_as "error" "${1:-An unknown error occurred.}"
  exit ${2:-1}
}

#
# ensures that script itself is *not* run using the sudo command but that there *is* a sudo session that can be used when needed
#
# @globals - reads SUDO_USER
#
function resolve_sudo() {
  local os="$(uname -o 2> /dev/null || true)"
  if [[ ! -x "/usr/bin/sudo" ]]
  then
    err "This script requires \"sudo\" to be installed."
  fi
  if [[ -n "${SUDO_USER-}" ]]
  then
    # user run script using sudo, we dont support that.
    err "This script must be run **without** using \"sudo\". You will be prompted if needed."
  fi
  if [[ "$os" != "Darwin" ]] # sudo is not needed on MacOS
  then
    # validate sudo session (prompting for password if necessary)
    local sudo_session_ok=0
    sudo -n true 2> /dev/null || sudo_session_ok=$?
    if [[ "$sudo_session_ok" -ne 0 ]]
    then
      sudo -v
      if [[ $? -ne 0 ]]
      then
        err "Something went wrong when using \"sudo\" to elevate the current script."
      fi
    fi
  fi
}

#
# prints a message to the console. Each type is display using a custom glyph and/or color
# single quoted substrings are highlighted in blue when detected
#
# @param string $1 - the message type, one of "success", "skipped", "failed", "error", "important", "prompt", "info"
# @param string $2 - the message to print
#
function print_as() {
  local red='\033[0;31m'
  local green='\033[0;32m'
  local yellow='\033[0;33m'
  local blue='\033[0;34m'
  local cyan='\033[0;36m'
  local default='\033[0;39m'
  local reset='\033[0m'
  local success_glyph="${green}✓${reset} "
  local success_color="$default"
  local skipped_glyph="${blue}✗${reset} "
  local skipped_color="$default"
  local failed_glyph="${red}✗${reset} "
  local failed_color="$default"
  local error_glyph="${red}✗${reset} "
  local error_color="$red"
  local important_glyph=""
  local important_color="$yellow"
  local prompt_glyph=""
  local prompt_color="$cyan"
  local info_glyph=""
  local info_color="$cyan"
  local nl="\n"

  # store $1 as the msgtype
  local msgtype=$1
  local glyph
  local color

  # use eval to assign reference vars
  eval "glyph=\${${msgtype}_glyph}"
  eval "color=\${${msgtype}_color}"

  # use sed to highlight quoted substrings in $2 and store as msg
  local msg=$(echo -n -e "$(echo -e -n "$2" | sed -e "s/'\([^'\\\"]*\)'/\\${blue}\1\\${reset}\\${color}/g")")

  # for prompts dont emit a linebreak
  if [[ "$msgtype" = "prompt" ]]
  then
    nl=""
  fi

  printf "${glyph}${color}${msg}${reset}${nl}"
}

#
# log to the log file
#
# @param string(s) $@ - the message(s) to log (expands to all arguments)
#
function log() {
  printf "$@\n" >> "$GHQS_DIR/install.log" 2>&1
}

#
# return its arguments as a single string with leading and trailing space trimmed
#
# @param string(s) $*- The string(s) to trim. Arguments are merged into a single string
#
function trim() {
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

#
# Run the installer command passed as 1st argument and shows the spinner until this is done
#
# @param string $1 - the installer command to run
# @param string $2 - the title to show next the spinner
# @globals - reads GHQS_DIR, writes GHQS_ENV_UPDATED, GHQS_ADDITIONAL_CONFIG_NEEDED, GHQS_INSTALLER_FAILED
#
function install() {
  command="$1"
  shift
  install_$command $@ >> "$GHQS_DIR/install.log" 2>&1 &
  local pid=$!
  log "===================================\n$command: pid $pid\n===================================\n"
  local delay=0.05

  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

  # Hide the cursor, it looks ugly :D
  tput civis
  local index=0
  local framesCount=${#frames[@]}

  while [[ "$(ps a | awk '{print $1}' | grep $pid)" ]]
  do
    printf "\033[0;34m${frames[$index]}\033[0m Installing $command"

    let index=index+1
    if [[ $index -ge $framesCount ]]
    then
      index=0
    fi

    printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
    sleep $delay
  done

  #
  # Wait the command to be finished, this is needed to capture its exit status
  #
  local exit_code=0
  wait $pid || exit_code=$?

  log "\nInstall function completed with exit code: $exit_code\n"

  if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 90 ]] || [[ $exit_code -eq 91 ]]
  then
    print_as "success" "Installing $command"
    if [[ $exit_code -eq 90 ]]
    then
      # 90 means environment will need to be reloaded, so this still successful run. Just set flag to output correct message later
      GHQS_ENV_UPDATED="true"
    elif [[ $exit_code -eq 91 ]]
    then
      # 91 means further configuration is needed, so this still successful run. Just set flag to output correct message later
      GHQS_ADDITIONAL_CONFIG_NEEDED="true"
    fi
  else
    GHQS_INSTALLER_FAILED="true"
    print_as "failed" "Installing $command"
  fi

  # Restore the cursor
  tput cnorm
}

#
# Validates that all commands used by functions in this script are available
#
function validate_commands() {
  local rc=0
  local commands="printf sed uname ps awk grep sleep tput cut mkdir which"
  for command in $commands; do
    rc=0
    command -v "$command" >/dev/null || rc=$?
    if [[ $rc -ne 0 ]]
    then
      err "Required command \"$command\" was not found."
    fi
  done
}

#
# ensure we are executing on a supported operating system
# Currently supported: Ubuntu 22.x or higher and MacOS 14.x or higher
#
# @globals - writes GHQS_OS_NAME, GHQS_OS_VERSION, GHQS_OS_MAJOR_VERSION, GHQS_OS_ARCH, GHQS_OS_KERNEL, GHQS_OS_MACHINE
#
function validate_os() {
  GHQS_OS_NAME="$(lsb_release -si 2> /dev/null || sw_vers -productName || echo "Unknown")"
  GHQS_OS_VERSION="$(lsb_release -sr 2> /dev/null || sw_vers -productVersion || echo "0.0.0")"
  GHQS_OS_MAJOR_VERSION="$(cut -d '.' -f 1 <<< "$GHQS_OS_VERSION")"
  GHQS_OS_ARCH="$(uname -m)"
  if [[ "$GHQS_OS_NAME" == "macOS" ]] || [[ "$GHQS_OS_NAME" == "macOS Server" ]] || [[ "$GHQS_OS_NAME" == "Mac OS X" ]]
  then
    # normalize to just MacOS for consistency
    GHQS_OS_NAME="MacOS"
  fi
  if [[ "$GHQS_OS_ARCH" == "arm64" ]]
  then
    # some systems report arm64 instead of aarch64. Normalize to aarch64
    GHQS_OS_ARCH="aarch64"
  fi
  if [[ -d "/run/WSL" ]]
  then
    GHQS_OS_VM=true
    GHQS_OS_MACHINE="$GHQS_OS_ARCH/WSL2"
  elif [[ -d "/opt/orbstack-guest" ]]
  then
    GHQS_OS_VM=true
    GHQS_OS_MACHINE="$GHQS_OS_ARCH/OrbStack"
  else
    GHQS_OS_VM=false
    GHQS_OS_MACHINE="$GHQS_OS_ARCH"
  fi
  if [[ "$GHQS_OS_NAME" == "Ubuntu" ]] && [[ $GHQS_OS_MAJOR_VERSION -ge 22 ]]
  then
    GHQS_OS_KERNEL="Linux"
  elif [[ "$GHQS_OS_NAME" == "MacOS" ]] && [[ $GHQS_OS_MAJOR_VERSION -ge 14 ]]
  then
    GHQS_OS_KERNEL="Darwin"
  else
    err "\"$GHQS_OS_NAME $GHQS_OS_VERSION ($GHQS_OS_MACHINE)\" is not a supported operating system."
  fi
}

#
# validate shell is supported and the users profile is already configured
#
# @globals - reads SHELL, HOME, writes GHQS_PROFILE_FILE
#
function validate_shell() {
  # validate the users shell is either bash or zsh and that they already have a valid profile
  if [[ "${SHELL#*bash}" != "$SHELL" ]]
  then
    if [[ -f "$HOME/.bashrc" ]]
    then
      GHQS_PROFILE_FILE="$HOME/.bashrc"
    elif [[ -f "$HOME/.bash_profile" ]]
    then
      GHQS_PROFILE_FILE="$HOME/.bash_profile"
    else
      err "Can not find a valid bash profile. Ensure either ~/.bashrc or ~/.bash_profile already exist"
    fi
  elif [[ "${SHELL#*zsh}" != "$SHELL" ]]
  then
    if [[ -f "$HOME/.zshrc" ]]
    then
      GHQS_PROFILE_FILE="$HOME/.zshrc"
    elif [[ -f "$HOME/.zprofile" ]]
    then
      GHQS_PROFILE_FILE="$HOME/.zprofile"
    else
      err "Can not find a valid zsh profile. Ensure either ~/.zshrc or ~/.zprofile already exist"
    fi
  else
    err "The current shell \"$SHELL\" is not supported."
  fi
}

#
# prepare the log file. We want a new log file for each run
#
# @globals - reads GHQS_DIR, writes GHQS_LOGFILE
#
function prepare_log() {
  # delete log if it exists.
  if [[ -f "$GHQS_DIR/install.log" ]]
  then
    rm -f "$GHQS_DIR/install.log"
  fi

  # create log file and make current user owner if sudo was used
  touch "$GHQS_DIR/install.log"
}

#
# Collects configuration options from the user
#
# @globals - reads GHQS_PROFILE_FILE, writes GHQS_GIT_USER_NAME, GHQS__GIT_USER_EMAIL
#
function configure() {
  local name
  local email
  local token
  local profile="$GHQS_PROFILE_FILE"

  print_as "info" "Responses will be used to configure git and git-credential-manager."
  printf "\n"
  
  print_as "prompt" "Full name: "
  read name
  GHQS_GIT_USER_NAME=$(trim $name)

  print_as "prompt" "Email address: "
  read email
  GHQS_GIT_USER_EMAIL=$(trim $email)

  if [[ -n "${GIT_HUB_PKG_TOKEN:-}" ]]
  then
    log "Environment variable GIT_HUB_PKG_TOKEN is already set. Skipping token configuration"
    printf "\n"
  else
    print_as "prompt" "GitHub token: "
    read token
    printf "\n"

    log "Profile is \"$profile\"."
    if cat "$profile" | grep -q "export GIT_HUB_PKG_TOKEN="; then
      log "Profile is already set to export github PAT. Confirming value is correct."
      if cat "$profile" | grep -q "export GIT_HUB_PKG_TOKEN=$token"; then
        log "Profile is already set to export github PAT with correct value. Skipping."
      else
        log "Profile is set to export github PAT with stale value. Updating."
        sed -i.bak "s/^export GIT_HUB_PKG_TOKEN=.*$/export GIT_HUB_PKG_TOKEN=$token/" -- $profile
      fi
    else
      log "Adding export of github PAT to profile."
      {
        echo ''
        echo '# github token for private registries'
        echo 'export GIT_HUB_PKG_TOKEN="'$token'"'
      } | tee -a "$profile"

      # set flag so that completion report informs user that environment needs reload
      GHQS_ENV_UPDATED="true"
    fi
  fi
}

#
# Runs all required validations before executing installation scripts
#
function init() {
  GHQS_DIR=$(mktemp -d 2> /dev/null || mktemp -d -t 'github-quickstart')
  validate_commands
  validate_shell
  validate_os
  prepare_log
  configure
}

#
# Cleanup variables and environment
# Note: there is no safe way to get the list of functions defined in a particular bash script, so we have to list them manually
#
function cleanup() {
  local utils="err resolve_suo print_as log trim install validate_commands validate_os validate_shell prepare_log configure init cleanup completion_report setup"
  local installers="install_git install_git-config"
  unset "${!GHQS_@}" # unset all variables starting with GHQS_
  unset -f $utils $installers # unset all functions defined in this script
}

#
# Print messages upon completion
#
# @globals - reads GHQS_DIR, GHQS_INSTALLER_FAILED, GHQS_ENV_UPDATED, GHQS_ADDITIONAL_CONFIG_NEEDED
#
function completion_report() {
  if [[ "${GHQS_INSTALLER_FAILED:-false}" == "true" ]]
  then
    print_as "failed" "Done!"
    printf "\n"
    print_as "important" "An error occured. Review \"$GHQS_DIR/install.log\" for more information."
  fi
  print_as "success" "Done!"
  printf "\n"
  print_as "info" "🚀 You should now be able to use git and git-credential-manager to clone a private repository."
  printf "\n"
  if [[ "${GHQS_ADDITIONAL_CONFIG_NEEDED:-false}" == "true" ]]
  then
    print_as "important" "Additional configuration needed. Run \"git-credential-manager configure\"."
  fi
  if [[ "${GHQS_ENV_UPDATED:-false}" == "true" ]]
  then
    print_as "important" "Environment was updated. Reload your current shell before proceeding."
  fi
}

#=============================================================================#
# Installers
#=============================================================================#

#
# Installs the latest version of git and git-credential-manager available at time 
# of install, or updates current version if needed.
#
function install_git() {
  local gcm_bin="$(which git-credential-manager 2> /dev/null || true)"
  if [[ "$GHQS_OS_NAME" == "Ubuntu" ]]
  then
    # update and upgrade, then install packages, then cleanup
    log "Updating and upgrading system packages and installing git"
    sudo apt-get -y update
    sudo apt-get -y upgrade
    sudo apt-get -y install git
    sudo apt-get -y clean
    # if we are on WSL2 or OrbStack, or if the binary is already available, skip installing git-credential-manager
    if [[ -d "/run/WSL" ]] || [[ -d "/opt/orbstack-guest" ]] || [[ -n "${gcm_bin:-}" ]]
    then
      log "Detected that Ubuntu is running in a VM. Skipping git-credential-manager installation."
    else
      log "Bare metal installation of Ubuntu detected. Downloading and installing git-credential-manager using dpkg"
      tmpdir=$(mktemp -d 2> /dev/null || mktemp -d -t 'github-quickstart-gcm')
      log "Using temp directory '$tmpdir'"
      pushd $tmpdir > /dev/null
      curl -L https://github.com/git-ecosystem/git-credential-manager/releases/download/v2.6.0/gcm-linux_amd64.2.6.0.deb -o gcm-linux_amd64.2.6.0.deb
      sudo dpkg -i gcm-linux_amd64.2.5.0.deb
      popd > /dev/null
      rm -rf $tmpdir
      return 91 # 91 is the code to indicate that further configuration is needed
    fi
  elif [[ "$GHQS_OS_NAME" == "MacOS" ]]
  then
    # Use homebrew to install os packages
    local brew_bin="$(which brew 2> /dev/null || true)"
    if [[ -n "${brew_bin:-}" ]]
    then
      log "Updating and upgrading brew packages"
      brew update
      brew doctor
    else
      log "Installing homebrew"
      tmpdir=$(mktemp -d 2> /dev/null || mktemp -d -t 'github-quickstart-homebrew')
      log "Using temp directory '$tmpdir'"
      pushd $tmpdir > /dev/null
      curl -L https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o install.sh
      ./install.sh
      popd > /dev/null
      rm -rf $tmpdir
    fi
    # now use homebrew to install git and git-credential-manager
    brew install git
    brew install --cask git-credential-manager
  else
    err "Unknown operating system \"$os\"."
  fi
}

#
# Configure existing git install
#
# @globals - reads GHQS_GIT_USER_NAME and GHQS_GIT_USER_EMAIL
#
function install_git-config() {
  local gcm_bin="$(which git-credential-manager 2> /dev/null || true)"
  local gcm_wsl2_bin="/mnt/c/Program\ Files/git/mingw64/bin/git-credential-manager.exe"
  local i

  # if we did not find the GCM executable we might be on WSL2
  if [[ -z "${gcm_bin:-}" ]] && [[ -d "/run/WSL" ]] && [[ -f "${gcm_wsl2_bin//[\\]/}" ]] # remove backslashes from variable value
  then
    # we are in a wsl2 vm on windows and the gcm binary is available in its default location
    gcm_bin=$gcm_wsl2_bin
    log "\"git-credential-manager\" was not found but WSL2 detected, setting \"credential.helper\" to \"$gcm_wsl2_bin\"."
  fi

  # if it is still undefined log it and return error code
  if [[ -z "${gcm_bin:-}" ]]
  then
    log "testing \"${gcm_bin:-}\""
    log "\"git-credential-manager\" was expected to be installed but was not found. Cannot continue."
    return 1
  fi

  declare -a keys=( user.name user.email credential.helper )
  declare -a values=( "${GHQS_GIT_USER_NAME:-}" "${GHQS_GIT_USER_EMAIL:-}" "$gcm_bin" )

  # populate current with the current values read from git config
  for (( i=0; i<${#keys[@]}; i++ ))
  do
    if [[ "$(git config --global "${keys[$i]}" || true)" != "${values[$i]}" ]]
    then
      git config --global --replace-all "${keys[$i]}" "${values[$i]}"
      log "git config setting '${keys[$i]}' was updated to '${values[$i]}'."
    else
      log "git config setting '${keys[$i]}' is already set to '${values[$i]}', skipping."
    fi
  done
}

#=============================================================================#
# Main Setup
#=============================================================================#

#
# Execute a series of installer functions sequentially and report results
#
function setup() {
  local completion_report_output

  # call init
  init

  # run all the installers one at a time
  install 'git'
  install 'git-config'

  # capture output of completion report and perform cleanup
  completion_report_output="$(completion_report && cleanup)"

  printf "$completion_report_output\n"
}

# only run when called directly and not sourced from another script (works in bash and zsh)
if [[ "${0}" == "bash" ]] || [[ "${BASH_SOURCE[0]}" == "${0}" ]] || echo "${ZSH_EVAL_CONTEXT+}" | grep -q "file"
then
  resolve_sudo
  setup
fi

} # this ensures that the entire script is downloaded #
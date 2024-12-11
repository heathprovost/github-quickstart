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
# Generic Utility Functions (only generic dependencies/globals)
#=============================================================================#

#
# generate global variables to use for generating ansi colors
#
function generate_ansi_colors {
  ansi_black="$(printf "\033[%sm" "30")"
  ansi_red="$(printf "\033[%sm" "31")"
  ansi_green="$(printf "\033[%sm" "32")"
  ansi_yellow="$(printf "\033[%sm" "33")"
  ansi_blue="$(printf "\033[%sm" "34")"
  ansi_magenta="$(printf "\033[%sm" "35")"
  ansi_cyan="$(printf "\033[%sm" "36")"
  ansi_white="$(printf "\033[%sm" "37")"
  ansi_reset="$(printf "\033[%sm" "39")"
}

#
# logs to the log file specified by the environment variable GHQS_LOG, otherwise logs to stdout
#
# @param string(s) $@ - the message(s) to log (expands to all arguments)
#
function log() {
  if [[ -n "${GHQS_LOG:-}" ]]
  then
    echo -e "$@" >> "$GHQS_LOG" 2>&1
  else
    echo -e "$@"
  fi
}

#
# returns the architecture of the current system, normalizing the output to correct for common aliases
#
function get_arch() {
  local arch="$(uname -m)"
  if [[ "$arch" == "amd64" ]]
  then
    arch="x86_64"
  fi
  if [[ "$arch" == "arm64" ]]
  then
    arch="aarch64"
  fi
  echo "$arch"
}

#
# returns the name of the kernel for the current system
#
function get_kernel() {
  local kernel="$(uname -s)"
  echo "$kernel"
}

#
# returns the name of the current operating system
#
function get_os() {
  local os="$(lsb_release -si 2> /dev/null || sw_vers -productName || echo -n "Unknown")"
  if [[ "$os" == "macOS" ]] || [[ "$os" == "macOS Server" ]] || [[ "$os" == "Mac OS X" ]]
  then
    os="MacOS"
  fi
  echo "$os"
}

#
# returns the major version number of the current operating system (e.g. 10.15.7 -> 10)
#
function get_os_version() {
  local version_string="$(get_os_version_string)"
  local version="$(cut -d '.' -f 1 <<< "$version_string")"
  echo "$version"
}

#
# returns the full version number of the current operating system (e.g. 10.15.7)
#
function get_os_version_string() {
  lsb_release -sr 2> /dev/null || sw_vers -productVersion || echo "0.0.0"
}

#
# returns the path to the current user's profile based on their SHELL, or an empty string. Supports bash and zsh only.
#
# @globals - reads SHELL, HOME
#
function get_profile_path() {
  if [[ $SHELL == */bash ]]
  then
    if [[ -f "$HOME/.bashrc" ]]
    then
      echo "$HOME/.bashrc"
    elif [[ -f "$HOME/.bash_profile" ]]
    then
      echo "$HOME/.bash_profile"
    fi
  elif [[ $SHELL == */zsh ]]
  then
    if [[ -f "$HOME/.zshrc" ]]
    then
      echo "$HOME/.zshrc"
    elif [[ -f "$HOME/.zprofile" ]]
    then
      echo "$HOME/.zprofile"
    fi
  fi
}

#
# creates a temporary directory in ./tmp/$1 and sets it as the cwd
#
# @param string $1 - the name of the temporary directory to create and cd into
#
function pushd_tmp() {
  local tmpdir="./tmp/$1"
  if [[ -d "$tmpdir" ]]
  then
    log "Removing existing temp directory '$tmpdir'"
    command rm -rf $tmpdir
  fi
  log "Using temp directory '$tmpdir'"
  command mkdir -p "$tmpdir"
  command pushd "$tmpdir" > /dev/null
}

#
# returns to the previous cwd and deletes the temporary directory created by push_tmpdir
#
function popd_tmp() {
  local tmpdir="$(command dirs +0)"
  if ! echo "$tmpdir" | grep -q '/tmp/'
  then
    log "Directory '$tmpdir' on top of stack does not match the expected pattern '*/tmp/*'. Cannot continue."
    exit 1
  fi
  log "Removing temp directory '$tmpdir'"
  command popd > /dev/null
  command rm -rf $tmpdir
}

#=============================================================================#
# Utility Functions (these have dependencies on other functions/globals)
#=============================================================================#

#
# report an error and exit with an error code
#
# @param string $1 - The error message to display. Defaults to "An unknown error occurred."
# @param integer $2 - The exit code to set. Defaults to 1
#
function err() {
  local error_message="${1:-An unknown error occurred.}"
  local exit_code="${2:-1}"

  printf "${ansi_red}${error_message}${ansi_reset}\n"
  exit $exit_code
}

#
# ensures that script itself is *not* run using the sudo command but that there *is* a sudo session that can be used when needed
#
# @globals - reads SUDO_USER
#
function resolve_sudo() {
  local kernel="$(get_kernel)"
  if [[ ! -x "/usr/bin/sudo" ]]
  then
    err "This script requires \"sudo\" to be installed."
  fi
  if [[ -n "${SUDO_USER-}" ]]
  then
    # user run script using sudo, we dont support that.
    err "This script must be run **without** using \"sudo\". You will be prompted if needed."
  else
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
# Run the installer command passed as 1st argument and shows the spinner until this is done
#
# @param string $1 - the installer command to run
# @param string $2 - the title to show next the spinner
# @globals - reads GHQS_LOG, writes GHQS_ENV_UPDATED, GHQS_INSTALLER_FAILED
#
function install() {
  local command="$1"
  shift
  install_$command $@ >> "$GHQS_LOG" 2>&1 &
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

  if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 90 ]]
  then
    printf "${ansi_green}✓${ansi_reset} Installing $command\n"
    if [[ $exit_code -eq 90 ]]
    then
      # 90 means environment will need to be reloaded, so this still successful run. Just set flag to output correct message later
      GHQS_ENV_UPDATED="true"
    fi
  else
    GHQS_INSTALLER_FAILED="true"
    printf "${ansi_red}✗${ansi_reset} Installing $command\n"
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
# ensure we are executing on a supported operating system. Currently Ubuntu 22+ or MacOS 14+
#
function validate_os() {
  local os="$(get_os)"
  local version="$(get_os_version)"
  if [[ "$os" == "Ubuntu" && $version -ge 22 ]] || [[ "$os" == "MacOS" && $version -ge 14 ]]
  then
    log "Operating system is supported: $os $version"
  else
    err "The current os \"$os $version\" is not supported."
  fi
}

#
# validate users default shell is supported. Must be either bash or zsh
#
# @globals - reads SHELL
#
function validate_shell() {
  local kernel="$(get_kernel)"

  if [[ "$kernel" == "Darwin" ]] && [[ $SHELL != */zsh ]]
  then
    err "You must use the default zsh shell. Please run 'chsh -s /bin/zsh' and try again."
  elif [[ $SHELL == */bash ]] || [[ $SHELL == */zsh ]]
  then
    log "Shell is supported: $SHELL"
  else
    err "The current shell \"$SHELL\" is not supported."
  fi
}

#
# prepare the log file. We want a new log file for each run
#
# @globals - reads GHQS_DIR, writes GHQS_LOG
#
function prepare_log() {
  GHQS_DIR="$HOME/.ghqs"
  mkdir -p "$GHQS_DIR"
  GHQS_LOG="$GHQS_DIR/install.log"
  if [[ -f "$GHQS_LOG" ]]
  then
    rm -f "$GHQS_LOG"
  fi
  touch "$GHQS_LOG"
}

#
# Cleanup variables and environment
#
# Note: there is no safe way to get the list of functions defined in a particular bash script, so we have to list them manually
#
function cleanup() {
  # unset all generic utiilty functions defined in this script
  unset -f "generate_ansi_colors log get_arch get_kernel get_os get_os_version get_os_version_string get_profile_path pushd_tmp popd_tmp"
  # unset all other functions
  unset -f "err resolve_sudo install validate_commands validate_os validate_shell prepare_log cleanup init completion_report configure setup"
  # unset installer functions
  unset -f "install_git install_git-config"
  # unset all ansi color variables
  unset "${!ansi_@}"
  # unset all variables starting with GHQS_
  unset "${!GHQS_@}"
}

#
# Runs all required validations before executing installation scripts
#
function init() {
  prepare_log
  validate_commands
  validate_os
  validate_shell
  configure
}

#
# Print messages upon completion
#
# @globals - reads GHQS_INSTALLER_FAILED, GHQS_ENV_UPDATED, GHQS_LOG
#
function completion_report() {
  if [[ "${GHQS_INSTALLER_FAILED:-false}" == "true" ]]
  then
    printf "${ansi_red}✗${ansi_reset} Done!\n\n"
    printf "${ansi_yellow}An error occured. Review \"${ansi_reset}${ansi_blue}$GHQS_LOG${ansi_reset}${ansi_yellow}\" for more information.${ansi_reset}\n"
  else
    printf "${ansi_green}✓${ansi_reset} Done!\n\n"
    if [[ "${GHQS_ENV_UPDATED:-false}" == "true" ]]
    then
      printf "${ansi_yellow}Environment was updated. Close and reopen your terminal before continuing.${ansi_reset}\n"
    fi
  fi
}

#
# Collects configuration options from the user
#
# @globals - reads GIT_HUB_PKG_TOKEN, writes GHQS_GIT_USER_NAME, GHQS_GIT_USER_EMAIL, GHQS_GITHUB_TOKEN
#
function configure() {
  local profile="$(get_profile_path)"
  local git_credentials="$HOME/.git-credentials"
  local name_input
  local name="$(git config --global user.name 2> /dev/null || true)"
  local email_input
  local email="$(git config --global user.email 2> /dev/null || true)"
  local token_input
  local token

  printf "${ansi_cyan}Responses will be used to configure GitHub credentials.${ansi_reset}\n\n"

  if [[ -n "${name:-}" ]]
  then
    printf "${ansi_cyan}Full name [${ansi_reset}${name}${ansi_cyan}]: ${ansi_reset}"
  else
    printf "${ansi_cyan}Full name: ${ansi_reset}"
  fi
  read name_input
  name=${name_input:-$name}
  GHQS_GIT_USER_NAME=$name

  if [[ -n "${email:-}" ]]
  then
    printf "${ansi_cyan}Email address [${ansi_reset}${email}${ansi_cyan}]: ${ansi_reset}"
  else
    printf "${ansi_cyan}Email address: ${ansi_reset}"
  fi
  read email_input
  email=${email_input:-$email}
  GHQS_GIT_USER_EMAIL=$email

  # if token is not already exported but it IS already set in users profile then capture it
  if [[ -z "${token:-}" ]] && cat "$profile" | grep -q "export GIT_HUB_PKG_TOKEN=";
  then
    token="$(cat "$profile" | sed -n "s/^export GIT_HUB_PKG_TOKEN=\(.*\)$/\1/p")"
  fi

  if [[ -n "${GIT_HUB_PKG_TOKEN:-}" ]] && [[ -z "${token:-}" ]]
  then
    # token is already exported, but was not set from the users profile. Do not try and overwrite it, just skip
    log "Environment variable GIT_HUB_PKG_TOKEN is already set. Skipping token configuration"
    GHQS_GITHUB_TOKEN=$GIT_HUB_PKG_TOKEN
    printf "\n"
    return 0
  fi

  if [[ -n "${token:-}" ]]
  then
    printf "${ansi_cyan}GitHub token [${ansi_reset}${token}${ansi_cyan}]: ${ansi_reset}"
  else
    printf "${ansi_cyan}GitHub token: ${ansi_reset}"
  fi
  read token_input
  token=${token_input:-$token}
  GHQS_GITHUB_TOKEN=$token
  printf "\n"
}

#=============================================================================#
# Installers
#=============================================================================#

#
# Installs the latest version of git and git-credential-manager available at time
# of install, or updates current version if needed.
#
function install_git() {
  local os="$(get_os)"
  local profile="$(get_profile_path)"
  local profile_updated

  if [[ "$os" == "Ubuntu" ]]
  then
    # update and upgrade, then install packages, then cleanup
    log "Updating and upgrading system packages and installing git"
    sudo apt-get -y update
    sudo apt-get -y upgrade
    sudo apt-get -y install git
    sudo apt-get -y clean
  elif [[ "$os" == "MacOS" ]]
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
      chmod +x install.sh
      ./install.sh
      popd > /dev/null
      rm -rf $tmpdir

      # add homebrew to users profile if needed and source it
      if [[ -f "$profile" ]]
      then
        if cat "$profile" | grep -q --fixed-strings 'eval "$(/opt/homebrew/bin/brew shellenv)"'; then
          log "Homebrew is already in the users profile. Skipping."
        else
          log "Adding homebrew to the users profile."
          printf '\n# homebrew\neval "$(/opt/homebrew/bin/brew shellenv)"\n' >> "$profile"
          profile_updated="true"
        fi
      fi

      log "making brew command available to current shell session"
      eval "$(/opt/homebrew/bin/brew shellenv)"
      log "confirming homebrew is now available"
      brew_bin="$(which brew 2> /dev/null || true)"
      if [[ -z "${brew_bin:-}" ]]
      then
        err "Homebrew was installed but the brew command could not be successfully added to the current session."
      fi
    fi
    # now use homebrew to install git
    brew install git

    # if profile was updated, set flag so that completion report informs user that environment needs reload
    if [[ -n "${profile_updated:-}" ]]
    then
      return 90
    fi
  else
    err "Unknown operating system \"$os\"."
  fi
}

#
# Configure git install
#
# @globals - reads GIT_HUB_PKG_TOKEN, GHQS_GIT_USER_NAME and GHQS_GIT_USER_EMAIL, GHQS_GITHUB_TOKEN
#
function install_git-config() {
  local i
  local profile="$(get_profile_path)"
  local git_credentials="$HOME/.git-credentials"
  local url="https://oauth2:${GHQS_GITHUB_TOKEN}@github.com"

  declare -a keys=( user.name user.email credential.helper )
  declare -a values=( "${GHQS_GIT_USER_NAME}" "${GHQS_GIT_USER_EMAIL}" "store" )

  # populate .gitconfig with user name and email and set credential helper to store
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

  # update credential store with github token if needed
  if [[ ! -f "$git_credentials" ]]
  then
    log "Creating \"~/.git-credentials\" file."
    touch "$git_credentials"
  fi
  if cat "$git_credentials" | grep -q --fixed-strings --ignore-case "$url"; then
    log "Credentials are already stored. Skipping."
  elif cat "$git_credentials" | grep -q --fixed-strings --ignore-case "^.*@github\.com$"; then
    log "Credentials are already stored for \"@github.com\", but token has changed. Updating."
    sed -i.bak "s|^.*@github\.com$|$url|" $git_credentials
  else
    echo "$url" >> "$git_credentials"
    log "Credentials were stored in \"$git_credentials\"."
  fi

  # update user profile if needed
  log "Profile is \"$profile\"."
  if cat "$profile" | grep -q --fixed-strings --ignore-case "export GIT_HUB_PKG_TOKEN="; then
    log "Profile is already set to export github PAT. Confirming value is correct."
    if cat "$profile" | grep -q --fixed-strings --ignore-case "export GIT_HUB_PKG_TOKEN=$GHQS_GITHUB_TOKEN"; then
      log "Profile is already set to export github PAT with correct value. Skipping."
    else
      log "Profile is set to export github PAT with stale value. Updating."
      sed -i.bak "s/^export GIT_HUB_PKG_TOKEN=.*$/export GIT_HUB_PKG_TOKEN=$GHQS_GITHUB_TOKEN/" $profile
    fi
  elif [[ -n "${GIT_HUB_PKG_TOKEN:-}" ]]
  then
    log "GIT_HUB_PKG_TOKEN is already set from a source other than the users profile. Skipping."
    return 0
  else
    log "Adding export of github PAT to profile."
    printf "\n# github token for private registries\nexport GIT_HUB_PKG_TOKEN=$GHQS_GITHUB_TOKEN\n" >> "$profile"
    # set flag so that completion report informs user that environment needs reload
    return 90
  fi
}

#=============================================================================#
# Main Setup
#=============================================================================#

#
# Execute a series of installer functions sequentially and report results
#
function setup() {
  init

  # run all the installers one at a time
  install 'git'
  install 'git-config'

  printf "$(completion_report && cleanup)\n"
}

generate_ansi_colors
resolve_sudo
setup

} # this ensures that the entire script is downloaded #

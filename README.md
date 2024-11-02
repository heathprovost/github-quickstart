# :rocket: GitHub Quickstart

This script can be used to simplify the process of cloning a private repository for the very first time using 
[git-credential-manager](https://github.com/git-ecosystem/git-credential-manager) and a
[GitHub HTTPS repository url](https://docs.github.com/en/get-started/getting-started-with-git/about-remote-repositories#cloning-with-https-urls).

## Requirements

A computer running one of the following:

- **Windows 11**
- **MacOS 15 (Sequoia)**
- **Ubuntu 22.04 LTS**

Both x86_64 and Arm64 hardware is supported.

*Note: Installing inside of Virtual Machines such as [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) and [OrbStack](https://orbstack.dev/)
is supported, but **only** for Ubuntu.*

## Installation

Setup is performed by simply copying and pasting one of the following commands into your terminal and hitting ENTER.

### Windows PowerShell

```powershell
. { Invoke-WebRequest -useb "https://raw.githubusercontent.com/heathprovost/github-quickstart/main/install.ps1" } | Invoke-Expression; install
```

### MacOS and Ubuntu

```sh
bash <(curl -so- https://raw.githubusercontent.com/heathprovost/github-quickstart/main/install.sh)
```

## Hows it Work

The script will be download and executed in one step. You will be promted to provide your name, email address, and the
[GitHub PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) you will use 
to access private package registries.  

The script will ensure that you have the latest versions of [git](https://git-scm.com/) and [git-credential-manager](https://github.com/git-ecosystem/git-credential-manager)
installed. Once completed you should be able to successfully clone a private and your shell environment will be configured so that your PAT 
is availible by reading the environment variable `GIT_HUB_PKG_TOKEN`.
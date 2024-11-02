# :cyclone: GitHub Quickstart

Simplify the process of cloning a private repository using [git-credential-manager](https://github.com/git-ecosystem/git-credential-manager)
for the very first time.

## :cyclone: Requirements

An x86_64 or Arm64 computer running, at a minimum, one of the following:

- **Windows 10**
- **MacOS 14 (Sonoma)**
- **Ubuntu 22.04 LTS**

*Note: Installing inside of Virtual Machines such as [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) and [OrbStack](https://orbstack.dev/)
is supported if running Ubuntu.*

## :cyclone: Installation

Copy and paste one of the following commands into your terminal and hitting ENTER.

### Windows PowerShell

```powershell
. { Invoke-WebRequest -useb "https://raw.githubusercontent.com/heathprovost/github-quickstart/main/install.ps1" } | Invoke-Expression; install
```

### MacOS and Ubuntu

```sh
bash <(curl -so- https://raw.githubusercontent.com/heathprovost/github-quickstart/main/install.sh)
```

That's it. Once installed you should be able to successfully close a GitHub private repo using an 
[HTTPS url](https://docs.github.com/en/get-started/getting-started-with-git/about-remote-repositories#cloning-with-https-urls).

## :cyclone: How's It Work?

The script will download and execute in one step. You will be promted to provide your name, email address, and the
[GitHub PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) you will use 
to access private package registries if you have not already configured one. This information is used **only** to configure git on your machine.

The script will ensure that you have the latest versions of [git](https://git-scm.com/) and [git-credential-manager](https://github.com/git-ecosystem/git-credential-manager)
installed. Once completed you should be able to successfully clone a private repository and your shell environment will be configured so that your PAT 
is availible in the environment variable `GIT_HUB_PKG_TOKEN`.
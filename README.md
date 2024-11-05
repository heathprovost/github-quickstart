# :cyclone: GitHub Quickstart

Simplify the process of cloning a private [GitHub](https://github.com) repository for the very first time.

## :cyclone: Requirements

An x86_64 or Arm64 computer running, at a minimum, one of the following:

- **Windows 10**
- **MacOS 14 (Sonoma)**
- **Ubuntu 22.04 LTS**

*Note: Installing inside of Virtual Machines such as [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install)
and [OrbStack](https://orbstack.dev/) is supported if running Ubuntu.*

## :cyclone: Installation

Copy and paste one of the following commands into your terminal and hitting ENTER.

### Windows PowerShell

```powershell
. { Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/heathprovost/github-quickstart/main/install.ps1" } | Invoke-Expression
```

### MacOS and Ubuntu

```sh
bash <(curl -so- https://raw.githubusercontent.com/heathprovost/github-quickstart/main/install.sh)
```

That's it. Once installed you should be able to successfully clone a GitHub private repo using an
[HTTPS Url](https://docs.github.com/en/get-started/getting-started-with-git/about-remote-repositories#cloning-with-https-urls).

## :cyclone: How It Works

The script will download and execute in one step. You will be prompted to provide your name, email address and the
[GitHub PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) you will use for authentication if you have not already configured one. This information is used **only** to configure git on your machine.

The script will ensure that you have the latest versions of [git](https://git-scm.com/) installed using the system's default package manager to install or update as needed. Once completed you should be able to successfully clone a private repository and your shell environment will be configured so that your PAT is available in the environment variable `GIT_HUB_PKG_TOKEN`.

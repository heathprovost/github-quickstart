#
# Prompts user for input with provided default value
#
function Read-HostWithDefault {
  param (
    [string] $prompt,
    [string] $defaultValue = $null
  )
  if ($defaultValue -eq $null) {
    Write-Host -ForegroundColor Cyan -NoNewline "${prompt}: "
  } else {
    Write-Host -ForegroundColor Cyan -NoNewline "${prompt}: ["
    Write-Host -NoNewline "$defaultValue"
    Write-Host -ForegroundColor Cyan -NoNewline ']: '
  }
  $input = Read-Host
  if ([string]::IsNullOrEmpty($input)) {
    $input = $defaultValue
  }
  return $input
}

#
# Installs git and git-credential-manager if not installed
#
function Install-Git {
  $git_bin = $null
  $gcm_bin = $null

  $git_bin = (Get-Command -ErrorAction SilentlyContinue -Name 'git').Source

  if ( $git_bin -ne $null -and $git_bin -match '\\cmd\\git\.exe$' ) {
    $expected_gcm_bin = $git_bin -replace "\\cmd\\git\.exe$",'\mingw64\bin\git-credential-manager.exe'
    if (Test-Path -Path $expected_gcm_bin) {
      $gcm_bin = $expected_gcm_bin
    }
  }

  if ($git_bin -eq $null -or $gcm_bin -eq $null) {
    Write-host 'Installing git...'
    Write-host ''
    winget install --exact --silent 'Git.Git' --accept-package-agreements
    Write-host ''
  }
}

#
# Prompt user for information to configure git
# note: git installs with credential.helper set to use gcm by default, so it is not set here
#
function Add-GitConfig {
  $name = (git config --global user.name)
  $email = (git config --global user.email)
  $machine_token=([Environment]::GetEnvironmentVariable("GIT_HUB_PKG_TOKEN", [System.EnvironmentVariableTarget]::Machine))
  $token = ([Environment]::GetEnvironmentVariable("GIT_HUB_PKG_TOKEN", [System.EnvironmentVariableTarget]::User))
  Write-host -ForegroundColor Cyan 'Responses will be used to configure git and git-credential-manager.'
  Write-host ''

  # set a few standard git config values
  git config --global push.default "simple" | out-null
  git config --global core.autocrlf "false" | out-null
  git config --global core.eol "lf" | out-null

  $name_input = Read-HostWithDefault 'Full name' $name
  if ($name_input -ne $null -and $name_input -ne "$name") {
    git config --global user.name "$name_input" | out-null
  }

  $email_input = Read-HostWithDefault 'Email address' $email
  if ($email_input -ne $null -and $email_input -ne "$email") {
    git config --global user.email "$email_input" | out-null
  }

  # if a token is set at the machine level, do not prompt for it
  if ($machine_token -eq $null) {
    $token_input = Read-HostWithDefault 'GitHub token' $token
    if ($token_input -ne $null -and $token_input -ne "$token") {
      [Environment]::SetEnvironmentVariable("GIT_HUB_PKG_TOKEN", "$token_input", [System.EnvironmentVariableTarget]::User)
    }
  }

  Write-host ''
  # dumb workaround for rocket emoji
  $EmojiIcon = [System.Convert]::toInt32("1F680", 16)
  Write-host -NoNewline ([System.Char]::ConvertFromUtf32($EmojiIcon))
  Write-host -ForegroundColor Cyan ' You should now be able to clone a private repository.'
}

Clear-Host
Install-Git
Add-GitConfig

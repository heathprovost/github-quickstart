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
  $token = $null
  Write-host -ForegroundColor Cyan 'Responses will be used to configure git and git-credential-manager.'
  Write-host ''

  $name = $(Write-Host -ForegroundColor Cyan -NoNewline 'Full name: '; Read-Host)
  if ((git config --global user.name) -ne"$name") {
    git config --global user.name "$name"
  }

  $email = $(Write-Host -ForegroundColor Cyan -NoNewline 'Email address: '; Read-Host)
  if ((git config --global user.email) -ne "$email") {
    git config --global user.email "$email"
  }

  # only prompt for token if not already set
  if (-not (Test-Path 'env:GIT_HUB_PKG_TOKEN')) {
    $token = $(Write-Host -ForegroundColor Cyan -NoNewline 'GitHub token: '; Read-Host)
    [Environment]::SetEnvironmentVariable("GIT_HUB_PKG_TOKEN", "$token", [System.EnvironmentVariableTarget]::User)
  }

  Write-host ''

  # dumb workaround for rocket emoji
  $EmojiIcon = [System.Convert]::toInt32("1F680", 16)
  Write-host -NoNewline ([System.Char]::ConvertFromUtf32($EmojiIcon))
  Write-host -ForegroundColor Cyan ' You should now be able to use git and git-credential-manager to clone a private repository.'
}

Install-Git
Add-GitConfig
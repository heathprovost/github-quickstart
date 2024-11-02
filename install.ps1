function Get-Command-Path {
  Param (
    [string]$command
  )
  $orgEap = $ErrorActionPreference
  $ErrorActionPreference = ‘stop’
  try {
    $path = (Get-Command $command).Source
    return $path
  }
  catch {
    return $null
  }
  finally {
    $ErrorActionPreference = $orgEap
  }
}

$git_bin = Get-Command-Path "git"
$gcm_bin = Get-Command-Path "git-credential-manager"

Write-Output "$git_bin"
Write-Output "$gcm_bin"

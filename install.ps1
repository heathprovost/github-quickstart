function Get-Command-Path {
  param ( [string] $command )
  try {
    $path = (Get-Command $command).Source
    return $path
  }
  catch {
    return $null
  }
}

$git_bin = Get-Command-Path "git"
$gcm_bin = Get-Command-Path "git-credential-manager"

Write-Output "$git_bin"
Write-Output "$gcm_bin"

function Get-CommandPath {
  param ( [string] $command )
  try {
    $path = (Get-Command -ErrorAction Stop -Name $command).Source
    return $path
  }
  catch {
    return $null
  }
}

$git_bin = Get-CommandPath "git"
$gcm_bin = Get-CommandPath "git-credential-manager"

Write-Output "$git_bin"
Write-Output "$gcm_bin"

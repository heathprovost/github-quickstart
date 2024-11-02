# you must be an administrator to run this script

function Get-GitCommandPath {
  $result = $null
  try {
    $result = (Get-Command -ErrorAction Stop -Name 'git').Source
  }
  catch {}
  return $result
}

function Get-GcmCommandPath {
  $result = $null
  $git_bin = Get-GitCommandPath
  if ( $git_bin -ne $null -and $git_bin -match '\\cmd\\git\.exe$' ) {
    $gcm_bin = $git_bin -replace "\\cmd\\git\.exe$",'\mingw64\bin\git-credential-manager.exe'
    if ( Test-Path -Path $gcm_bin ) {
      $result = $gcm_bin
    }
  }
  catch {}
  return $result
}

$git_bin = Get-GitCommandPath
$gcm_bin = Get-GcmCommandPath

Write-Output "$git_bin"
Write-Output "$gcm_bin"

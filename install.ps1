$git_bin = (Get-Command git).Source
$gcm_bin = (Get-Command git-credential-manager).Source

Write-Output "$git_bin"
Write-Output "$gcm_bin"

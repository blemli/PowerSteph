. (Join-Path $PSScriptRoot Get-Transcript.ps1)
. (Join-Path $PSScriptRoot .\Get-Week.ps1)

Export-ModuleMember -Function Get-Transcript, Get-Week, Clear-Transcript
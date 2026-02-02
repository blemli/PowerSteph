. (Join-Path $PSScriptRoot Get-Transcript.ps1)
. (Join-Path $PSScriptRoot .\Get-Week.ps1)
. (Join-Path $PSScriptRoot .\Disable-MailspringUpdate.ps1)
. (Join-Path $PSScriptRoot .\Publish-MyModule.ps1)
. (Join-Path $PSScriptRoot .\Get-1PasswordItem.ps1)

Export-ModuleMember -Function Get-Transcript, Get-Week, Step-Week, Clear-Transcript, Disable-MailspringUpdate, Enable-MailspringUpdate, Publish-MyModule, Get-1PasswordItem
Import-Module PowerSteph
Get-1PasswordItem -Name PowerSteph -Field credential -Type "API Credential" | Set-Variable -Name Key
Publish-MyModule -NuGetApiKey $Key -Path ./PowerSteph/

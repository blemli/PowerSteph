Import-Module PowerSteph
Get-1PasswordItem -Name PowerSteph -Field credential -Type "API Credential"
Publish-MyModule -Key $Key

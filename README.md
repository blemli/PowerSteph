# PowerSteph
stop wishing, start scripting!

## Install
```Install-Module -Name PowerSteph```

## Publish

```bash
key=$(op item get --reveal --field credential "Powershell Gallery PowerSteph")
pwsh publish.ps1 -NuGetApiKey $key
```


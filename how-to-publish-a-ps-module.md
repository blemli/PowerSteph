# Share Your PowerShell Module with the World

## 0) Foundation
1. Install an Editor i.e.: `scoop install vscode`
2. `Set-ExecutionPolicy -Scope CurrentUser Bypass`
3. Create a PowerShellGallery Account
4. Install the PowerShellGet Module:
`Install-Module -Name PowerShellGet -Force -SkipPublisherCheck`
5. Trust the PSGallery: `Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted`


On Windows the default powershell is still V5. You might want to use the newest with `scoop install powershell`. 
Also you might want to set your Editor as default Application for .ps1 .psm1 and .psd1 files.



## I) Prepare 
1. Define a Name for Your Module. Make sure it doesn't already exist
You can Check with `Find-Module -Name MyModule`. 
2. Create a Repository with .gitignore file and with the name of the Module.


## II) Create a Module Manifest
1. Navigate to your module directory:
`Set-Location -Path .\MyModule`

2. If you don't already have a module-File create it:
`New-Item -Type File MyModule.psm1`

2. Create a Module Manifest:
`New-ModuleManifest -Path PowerSteph.psd1 -Author "John Miller" -Description "A short and catchy slogan" -RootModule MyModule.psm1` 

3. Open it with your editor and make changes: `code MyModule.psd1`



## III) Publish
1. Publish-Module -Path . -Repository PSGallery -NuGetApiKey 'YourApiKey'
2. Verify: `Install-Module -Name MyModule`


## IV) Update
3. To Install an already installed Module add Force: `Install-Module -Name MyModule -Force`
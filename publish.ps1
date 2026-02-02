param (
    [Parameter(Position = 0)]
    [string]
    $NuGetApiKey
)

# Set English output for CLI tools
$env:DOTNET_CLI_UI_LANGUAGE = "en_US"
$env:NUGET_CLI_LANGUAGE = "en_US"

# Ensure TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ModuleName = "PowerSteph"
$ModulePath = Join-Path $PSScriptRoot $ModuleName
$ManifestPath = Join-Path $ModulePath "$ModuleName.psd1"

# Get current local version
$Manifest = Import-PowerShellDataFile -Path $ManifestPath
$LocalVersion = [version]$Manifest.ModuleVersion

# Check PSGallery for published version
$PublishedModule = Find-Module -Name $ModuleName -Repository PSGallery -ErrorAction SilentlyContinue

if ($PublishedModule) {
    $PublishedVersion = [version]$PublishedModule.Version

    if ($LocalVersion -le $PublishedVersion) {
        # Bump patch version
        $NewVersion = [version]::new($PublishedVersion.Major, $PublishedVersion.Minor, $PublishedVersion.Build + 1)
        Write-Host "Bumping version: $LocalVersion -> $NewVersion (published: $PublishedVersion)" -ForegroundColor Yellow

        # Update manifest
        $Content = Get-Content -Path $ManifestPath -Raw
        $Content = $Content -replace "ModuleVersion = '$LocalVersion'", "ModuleVersion = '$NewVersion'"
        Set-Content -Path $ManifestPath -Value $Content -NoNewline

        $LocalVersion = $NewVersion
    }
}

Write-Host "Publishing $ModuleName v$LocalVersion from: $ModulePath" -ForegroundColor Cyan

# Get API key if not provided
if (-not $NuGetApiKey) {
    $SecureKey = Read-Host -Prompt "Enter PSGallery API Key" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureKey)
    $NuGetApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

# Publish
Publish-Module -Path $ModulePath -NuGetApiKey $NuGetApiKey -Repository PSGallery -Verbose

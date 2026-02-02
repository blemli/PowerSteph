function Publish-MyModule {
    <#
    .SYNOPSIS
        Publishes a PowerShell module to PSGallery with automatic version bumping.

    .DESCRIPTION
        Publishes a module to PSGallery. Automatically bumps the patch version
        if the local version is less than or equal to the published version.
        Sets English locale for CLI tools to ensure consistent output.

    .PARAMETER Path
        Path to the module folder. Defaults to the current directory.

    .PARAMETER NuGetApiKey
        The API key for PSGallery. If not provided, prompts for input.

    .PARAMETER Repository
        The repository to publish to. Defaults to PSGallery.

    .EXAMPLE
        Publish-MyModule -Path .\MyModule

        Publishes MyModule, prompting for the API key.

    .EXAMPLE
        Publish-MyModule -Path .\MyModule -NuGetApiKey "abc123"

        Publishes MyModule using the provided API key.

    .EXAMPLE
        Publish-MyModule

        Publishes the module in the current directory.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0)]
        [string]
        $Path = ".",

        [Parameter(Position = 1)]
        [string]
        $NuGetApiKey,

        [Parameter()]
        [string]
        $Repository = "PSGallery"
    )

    begin {
        # Set English output for CLI tools
        $env:DOTNET_CLI_UI_LANGUAGE = "en_US"
        $env:NUGET_CLI_LANGUAGE = "en_US"

        # Ensure TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    process {
        $ModulePath = Resolve-Path -Path $Path -ErrorAction Stop

        # Find manifest
        $ManifestFile = Get-ChildItem -Path $ModulePath -Filter "*.psd1" | Select-Object -First 1
        if (-not $ManifestFile) {
            throw "No module manifest (.psd1) found in '$ModulePath'."
        }

        $ModuleName = $ManifestFile.BaseName
        $ManifestPath = $ManifestFile.FullName

        # Get current local version
        $Manifest = Import-PowerShellDataFile -Path $ManifestPath
        $LocalVersion = [version]$Manifest.ModuleVersion

        # Check repository for published version
        $PublishedModule = Find-Module -Name $ModuleName -Repository $Repository -ErrorAction SilentlyContinue

        if ($PublishedModule) {
            $PublishedVersion = [version]$PublishedModule.Version

            if ($LocalVersion -le $PublishedVersion) {
                # Bump patch version
                $NewVersion = [version]::new($PublishedVersion.Major, $PublishedVersion.Minor, $PublishedVersion.Build + 1)

                if ($PSCmdlet.ShouldProcess($ManifestPath, "Bump version $LocalVersion -> $NewVersion")) {
                    Write-Host "Bumping version: $LocalVersion -> $NewVersion (published: $PublishedVersion)" -ForegroundColor Yellow

                    $Content = Get-Content -Path $ManifestPath -Raw
                    $Content = $Content -replace "ModuleVersion = '$LocalVersion'", "ModuleVersion = '$NewVersion'"
                    Set-Content -Path $ManifestPath -Value $Content -NoNewline

                    $LocalVersion = $NewVersion
                }
            }
        }

        Write-Host "Publishing $ModuleName v$LocalVersion from: $ModulePath" -ForegroundColor Cyan

        # Get API key if not provided
        if (-not $NuGetApiKey) {
            $SecureKey = Read-Host -Prompt "Enter $Repository API Key" -AsSecureString
            $NuGetApiKey = ConvertFrom-SecureString -SecureString $SecureKey -AsPlainText
        }

        # Publish
        if ($PSCmdlet.ShouldProcess("$ModuleName v$LocalVersion", "Publish to $Repository")) {
            PowerShellGet\Publish-Module -Path $ModulePath -NuGetApiKey $NuGetApiKey -Repository $Repository -Verbose
        }
    }
}

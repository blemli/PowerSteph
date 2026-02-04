function Install-PowerShell7 {
    <#
    .SYNOPSIS
        Installs PowerShell 7 using WinGet.

    .DESCRIPTION
        Uses the Windows Package Manager (winget) to install PowerShell 7.
        Can install either the stable or preview version.

    .PARAMETER Preview
        Install the preview version instead of the stable release.

    .EXAMPLE
        Install-PowerShell7

        Installs the latest stable version of PowerShell 7.

    .EXAMPLE
        Install-PowerShell7 -Preview

        Installs the latest preview version of PowerShell 7.

    .LINK
        https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()]
        [switch]$Preview
    )

    # Check if winget is available
    if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
        throw "WinGet is not installed or not in PATH. WinGet is required for this cmdlet."
    }

    $packageId = if ($Preview) {
        "Microsoft.PowerShell.Preview"
    } else {
        "Microsoft.PowerShell"
    }

    $displayName = if ($Preview) { "PowerShell 7 Preview" } else { "PowerShell 7" }

    if ($PSCmdlet.ShouldProcess($displayName, "Install")) {
        Write-Verbose "Installing $displayName using winget..."
        & winget install --id $packageId --source winget --accept-package-agreements --accept-source-agreements

        if ($LASTEXITCODE -eq 0) {
            Write-Host "$displayName installed successfully." -ForegroundColor Green
        } else {
            Write-Error "Failed to install $displayName. Exit code: $LASTEXITCODE"
        }
    }
}

function Uninstall-PowerShell7 {
    <#
    .SYNOPSIS
        Uninstalls PowerShell 7 using WinGet.

    .DESCRIPTION
        Uses the Windows Package Manager (winget) to uninstall PowerShell 7.
        Can uninstall either the stable or preview version.

    .PARAMETER Preview
        Uninstall the preview version instead of the stable release.

    .EXAMPLE
        Uninstall-PowerShell7

        Uninstalls the stable version of PowerShell 7.

    .EXAMPLE
        Uninstall-PowerShell7 -Preview

        Uninstalls the preview version of PowerShell 7.

    .LINK
        https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()]
        [switch]$Preview
    )

    # Check if winget is available
    if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
        throw "WinGet is not installed or not in PATH. WinGet is required for this cmdlet."
    }

    $packageId = if ($Preview) {
        "Microsoft.PowerShell.Preview"
    } else {
        "Microsoft.PowerShell"
    }

    $displayName = if ($Preview) { "PowerShell 7 Preview" } else { "PowerShell 7" }

    if ($PSCmdlet.ShouldProcess($displayName, "Uninstall")) {
        Write-Verbose "Uninstalling $displayName using winget..."
        & winget uninstall --id $packageId

        if ($LASTEXITCODE -eq 0) {
            Write-Host "$displayName uninstalled successfully." -ForegroundColor Green
        } else {
            Write-Error "Failed to uninstall $displayName. Exit code: $LASTEXITCODE"
        }
    }
}

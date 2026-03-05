function Set-Shortcut {
    <#
    .SYNOPSIS
        Modifies an existing Windows shortcut (.lnk) file.

    .DESCRIPTION
        Updates properties of an existing .lnk shortcut file.
        Can change the target, icon, working directory, or arguments.

    .PARAMETER Path
        The full path to the existing shortcut (.lnk) file to modify.

    .PARAMETER From
        New target path for the shortcut.

    .PARAMETER Icon
        New icon path for the shortcut.

    .PARAMETER WorkingDirectory
        New working directory for the shortcut.

    .PARAMETER Arguments
        New arguments to pass to the target.

    .EXAMPLE
        Set-Shortcut -Path "C:\Users\me\Desktop\App.lnk" -From "C:\NewPath\app.exe"

    .EXAMPLE
        Set-Shortcut -Path "C:\Users\me\Desktop\App.lnk" -Icon "C:\Icons\app.ico"

    .EXAMPLE
        Set-Shortcut -Path "C:\Users\me\Desktop\App.lnk" -Arguments "--verbose"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('\.lnk$')]
        [string]$Path,

        [string]$From,

        [string]$Icon,

        [string]$WorkingDirectory,

        [string]$Arguments
    )

    if ($PSVersionTable.Platform -and $PSVersionTable.Platform -ne 'Win32NT') {
        Write-Error "Set-Shortcut is only supported on Windows."
        return
    }

    if (-not (Test-Path $Path)) {
        Write-Error "Shortcut not found: $Path"
        return
    }

    $wsh = New-Object -ComObject WScript.Shell
    $s = $wsh.CreateShortcut($Path)

    if ($From) {
        if (-not (Test-Path $From)) {
            Write-Warning "Target not found: $From - updating shortcut anyway."
        }
        $s.TargetPath = $From
        $s.WorkingDirectory = Split-Path $From -Parent
    }

    if ($Icon) {
        if (Test-Path $Icon) {
            $s.IconLocation = $Icon
        } else {
            Write-Warning "Icon not found: $Icon - skipping icon update."
        }
    }

    if ($WorkingDirectory) {
        $s.WorkingDirectory = $WorkingDirectory
    }

    if ($PSBoundParameters.ContainsKey('Arguments')) {
        $s.Arguments = $Arguments
    }

    $s.Save()

    Write-Output "Updated: $Path"
}

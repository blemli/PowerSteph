function New-Shortcut {
    <#
    .SYNOPSIS
        Creates a Windows shortcut (.lnk) file.

    .DESCRIPTION
        Creates a new .lnk shortcut file pointing to the specified target.
        Uses the WScript.Shell COM object to create standard Windows shortcuts.
        Warns if the target does not exist but creates the shortcut anyway.

    .PARAMETER From
        The full path to the target file or application the shortcut points to.

    .PARAMETER To
        The full path where the shortcut (.lnk) file should be created.
        Must end in .lnk.

    .PARAMETER Icon
        Optional path to an icon file (.ico, .exe, .dll) for the shortcut.
        If not specified or the file doesn't exist, the target is used as the icon source.

    .EXAMPLE
        New-Shortcut -From "C:\Program Files\App\app.exe" -To "C:\Users\me\Desktop\App.lnk"

    .EXAMPLE
        New-Shortcut -From "C:\Tools\tool.exe" -To "C:\Users\me\Desktop\Tool.lnk" -Icon "C:\Tools\tool.ico"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [ValidatePattern('\.lnk$')]
        [string]$To,

        [string]$Icon
    )

    if ($PSVersionTable.Platform -and $PSVersionTable.Platform -ne 'Win32NT') {
        Write-Error "New-Shortcut is only supported on Windows."
        return
    }

    $folder = Split-Path $To -Parent
    if ($folder -and -not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    if (-not (Test-Path $From)) {
        Write-Warning "Target not found: $From - creating shortcut anyway: $To"
    }

    $wsh = New-Object -ComObject WScript.Shell
    $s = $wsh.CreateShortcut($To)
    $s.TargetPath = $From
    $s.WorkingDirectory = Split-Path $From -Parent
    if ($Icon -and (Test-Path $Icon)) { $s.IconLocation = $Icon } else { $s.IconLocation = $From }
    $s.Save()

    Write-Output "Created: $To"
}

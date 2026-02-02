function Disable-MailspringUpdate {
    <#
    .SYNOPSIS
        Disables Mailspring auto-update by renaming Update.exe.

    .DESCRIPTION
        Renames Update.exe to Update.exe.old in the Mailspring installation directory
        to prevent auto-updates. This is a workaround for database errors that can occur
        after installing certain versions of Mailspring.

        See: https://community.getmailspring.com/t/database-error-and-unable-to-launch-app-after-installing-v1-10-0/4063/31

    .PARAMETER ComputerName
        One or more remote computers to run the command on.
        Uses PowerShell Remoting (WinRM). If not specified, runs locally.

    .PARAMETER Credential
        Credentials for remote computer authentication.
        Use Get-Credential to create a credential object, or pass a username
        to be prompted for the password.

    .PARAMETER MailspringPath
        Path to the Mailspring installation directory.
        Defaults to $env:LOCALAPPDATA\Mailspring on the target computer.

    .EXAMPLE
        Disable-MailspringUpdate

        Disables Mailspring auto-update on the local computer.

    .EXAMPLE
        Disable-MailspringUpdate -ComputerName "PC01", "PC02"

        Disables Mailspring auto-update on multiple remote computers.

    .EXAMPLE
        Disable-MailspringUpdate -ComputerName "PC01" -Credential (Get-Credential)

        Prompts for credentials, then disables auto-update on the remote computer.

    .EXAMPLE
        $cred = Get-Credential "DOMAIN\Admin"
        Disable-MailspringUpdate -ComputerName "PC01", "PC02" -Credential $cred

        Uses stored credentials to disable auto-update on multiple remote computers.

    .EXAMPLE
        Disable-MailspringUpdate -ComputerName "SERVER01" -Credential "Administrator"

        Prompts for password for the specified username.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("CN", "Server")]
        [string[]]
        $ComputerName,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Position = 1)]
        [string]
        $MailspringPath
    )

    begin {
        $ScriptBlock = {
            param($Path, $WhatIf)

            if (-not $Path) {
                $Path = Join-Path $env:LOCALAPPDATA "Mailspring"
            }

            $result = [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                Path         = $Path
                Status       = $null
                Message      = $null
            }

            if (-not (Test-Path -Path $Path -PathType Container)) {
                $result.Status = "Error"
                $result.Message = "MailspringPath '$Path' does not exist."
                return $result
            }

            $UpdateExe = Join-Path $Path "Update.exe"
            $UpdateExeOld = Join-Path $Path "Update.exe.old"

            if (-not (Test-Path -Path $UpdateExe)) {
                if (Test-Path -Path $UpdateExeOld) {
                    $result.Status = "AlreadyDisabled"
                    $result.Message = "Auto-update is already disabled (Update.exe.old exists)."
                    return $result
                }
                $result.Status = "Error"
                $result.Message = "Update.exe not found in '$Path'."
                return $result
            }

            if (Test-Path -Path $UpdateExeOld) {
                $result.Status = "Error"
                $result.Message = "Update.exe.old already exists. Remove it first or use Enable-MailspringUpdate."
                return $result
            }

            if ($WhatIf) {
                $result.Status = "WhatIf"
                $result.Message = "Would rename Update.exe to Update.exe.old."
                return $result
            }

            try {
                Rename-Item -Path $UpdateExe -NewName "Update.exe.old" -ErrorAction Stop
                $result.Status = "Success"
                $result.Message = "Auto-update disabled. Update.exe renamed to Update.exe.old."
            }
            catch {
                $result.Status = "Error"
                $result.Message = "Failed to rename: $_"
            }

            return $result
        }
    }

    process {
        $WhatIfPreference = $WhatIfPreference -or (-not $PSCmdlet.ShouldProcess("Mailspring Update.exe", "Disable auto-update"))

        if (-not $ComputerName) {
            $results = & $ScriptBlock -Path $MailspringPath -WhatIf $WhatIfPreference
        }
        else {
            $invokeParams = @{
                ComputerName = $ComputerName
                ScriptBlock  = $ScriptBlock
                ArgumentList = $MailspringPath, $WhatIfPreference
            }

            if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
                $invokeParams.Credential = $Credential
            }

            $results = Invoke-Command @invokeParams
        }

        foreach ($result in $results) {
            switch ($result.Status) {
                "Success" { Write-Output $result }
                "WhatIf" { Write-Output $result }
                "AlreadyDisabled" { Write-Warning "[$($result.ComputerName)] $($result.Message)"; $result }
                "Error" { Write-Error "[$($result.ComputerName)] $($result.Message)" }
            }
        }
    }
}

function Enable-MailspringUpdate {
    <#
    .SYNOPSIS
        Enables Mailspring auto-update by restoring Update.exe.

    .DESCRIPTION
        Renames Update.exe.old back to Update.exe in the Mailspring installation directory
        to re-enable auto-updates.

    .PARAMETER ComputerName
        One or more remote computers to run the command on.
        Uses PowerShell Remoting (WinRM). If not specified, runs locally.

    .PARAMETER Credential
        Credentials for remote computer authentication.
        Use Get-Credential to create a credential object, or pass a username
        to be prompted for the password.

    .PARAMETER MailspringPath
        Path to the Mailspring installation directory.
        Defaults to $env:LOCALAPPDATA\Mailspring on the target computer.

    .EXAMPLE
        Enable-MailspringUpdate

        Enables Mailspring auto-update on the local computer.

    .EXAMPLE
        Enable-MailspringUpdate -ComputerName "PC01", "PC02"

        Enables Mailspring auto-update on multiple remote computers.

    .EXAMPLE
        Enable-MailspringUpdate -ComputerName "PC01" -Credential (Get-Credential)

        Prompts for credentials, then enables auto-update on the remote computer.

    .EXAMPLE
        $cred = Get-Credential "DOMAIN\Admin"
        Enable-MailspringUpdate -ComputerName "PC01", "PC02" -Credential $cred

        Uses stored credentials to enable auto-update on multiple remote computers.

    .EXAMPLE
        Enable-MailspringUpdate -ComputerName "SERVER01" -Credential "Administrator"

        Prompts for password for the specified username.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("CN", "Server")]
        [string[]]
        $ComputerName,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Position = 1)]
        [string]
        $MailspringPath
    )

    begin {
        $ScriptBlock = {
            param($Path, $WhatIf)

            if (-not $Path) {
                $Path = Join-Path $env:LOCALAPPDATA "Mailspring"
            }

            $result = [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                Path         = $Path
                Status       = $null
                Message      = $null
            }

            if (-not (Test-Path -Path $Path -PathType Container)) {
                $result.Status = "Error"
                $result.Message = "MailspringPath '$Path' does not exist."
                return $result
            }

            $UpdateExe = Join-Path $Path "Update.exe"
            $UpdateExeOld = Join-Path $Path "Update.exe.old"

            if (-not (Test-Path -Path $UpdateExeOld)) {
                if (Test-Path -Path $UpdateExe) {
                    $result.Status = "AlreadyEnabled"
                    $result.Message = "Auto-update is already enabled (Update.exe exists)."
                    return $result
                }
                $result.Status = "Error"
                $result.Message = "Update.exe.old not found in '$Path'. Nothing to restore."
                return $result
            }

            if (Test-Path -Path $UpdateExe) {
                $result.Status = "Error"
                $result.Message = "Update.exe already exists. Remove it first or it will conflict with the restore."
                return $result
            }

            if ($WhatIf) {
                $result.Status = "WhatIf"
                $result.Message = "Would rename Update.exe.old to Update.exe."
                return $result
            }

            try {
                Rename-Item -Path $UpdateExeOld -NewName "Update.exe" -ErrorAction Stop
                $result.Status = "Success"
                $result.Message = "Auto-update enabled. Update.exe.old renamed to Update.exe."
            }
            catch {
                $result.Status = "Error"
                $result.Message = "Failed to rename: $_"
            }

            return $result
        }
    }

    process {
        $WhatIfPreference = $WhatIfPreference -or (-not $PSCmdlet.ShouldProcess("Mailspring Update.exe.old", "Enable auto-update"))

        if (-not $ComputerName) {
            $results = & $ScriptBlock -Path $MailspringPath -WhatIf $WhatIfPreference
        }
        else {
            $invokeParams = @{
                ComputerName = $ComputerName
                ScriptBlock  = $ScriptBlock
                ArgumentList = $MailspringPath, $WhatIfPreference
            }

            if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
                $invokeParams.Credential = $Credential
            }

            $results = Invoke-Command @invokeParams
        }

        foreach ($result in $results) {
            switch ($result.Status) {
                "Success" { Write-Output $result }
                "WhatIf" { Write-Output $result }
                "AlreadyEnabled" { Write-Warning "[$($result.ComputerName)] $($result.Message)"; $result }
                "Error" { Write-Error "[$($result.ComputerName)] $($result.Message)" }
            }
        }
    }
}

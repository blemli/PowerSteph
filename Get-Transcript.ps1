<#
    .SYNOPSIS
        Retrieve PowerShell transcripts
    .DESCRIPTION
        The Get-Transcript function fetches PowerShell transcript files from a given folder,
        which defaults to the Documents folder in the user's profile directory. The transcript files
        adhere to the naming pattern "Powershell_transcript.<ORIGIN>.<UID>.<TIMESTAMP>.txt", where
        <ORIGIN> represents the computer's hostname.

        The function can retrieve all transcripts or only the most recent one, based on the -Last switch.
        It also allows filtering hostname, through the $Origin parameter.

        If the specified directory does not exist, an exception is thrown.
    .PARAMETER Origin
        Specifies the hostname (computer name) for filtering transcript files. Default value is "*", which includes all hostnames.
    .PARAMETER TranscriptPath
        Specifies the directory from which to retrieve transcript files. The default is the user's Documents folder.
    .PARAMETER Last
        When used, the function only returns the most recent transcript file based on last write time.
    .EXAMPLE
        Get-Transcript
        This command will retrieve all PowerShell transcripts from the default directory.
    .EXAMPLE
        Get-Transcript -Origin "MYPC" -TranscriptPath "C:\Users\username\Desktop\TranscriptsFromMyPC"
        This command will retrieve all PowerShell transcripts originated from MYPC from the default directory.
        Notice that you have to gather them from the remotemachine yourself....
    .EXAMPLE
        Get-Transcript -Last
        This command will retrieve the most recent PowerShell transcript from the default directory.
    .EXAMPLE
        Get-Transcript -TranscriptPath "C:\Users\username\Desktop" -Last
        This command will retrieve the most recent PowerShell transcript from the specified directory.

    .EXAMPLE
        Get-Transcript -Last | Get-Content
        This command will retrieve the most recent PowerShell transcript from the default directory and display its contents.

#>function Get-Transcript {
    [CmdletBinding()]
    param (
        # Origin (ComputerName)
        [Parameter(Position = 0)]
        [String]
        $Origin = "*",

        # TranscriptPath
        [Parameter(Position = 1)]
        [string]
        $TranscriptPath = (Join-Path $env:USERPROFILE Documents),

        # Gets the most recent transcript
        [Parameter()]
        [Switch]
        $Last
    )

    begin {
        # Validate the TranscriptPath parameter
        if (-not (Test-Path -Path $TranscriptPath -PathType Container)) {
            throw "The specified TranscriptPath '$TranscriptPath' does not exist."
        }

        # If $Origin is empty, set it to "*"
        if ([string]::IsNullOrEmpty($Origin)) {
            $Origin = "*"
        }
    }

    process {
        # Make Origin (ComputerName) Uppercase
        $Origin = $Origin.ToUpper()

        # Get and sort transcript files
        $TranscriptFiles = Get-ChildItem -Path $TranscriptPath -Filter "Powershell_transcript.$Origin.*.txt" | Sort-Object -Property LastWriteTime -Descending
        # If no transcript files were found, return an error
        if ($TranscriptFiles.Count -eq 0) {
            Write-Error "No transcript files were found for Origin '$Origin'."
            Write-Output $null
        }

        # If $Last is set, return only the most recent transcript
        if ($Last) {
            $TranscriptFiles = $TranscriptFiles[0]
        }

        # Output the result
        Write-Output $TranscriptFiles
    }
}

<#
    .SYNOPSIS
        Clear All Transcripts
    .DESCRIPTION
        The Clear-Transcript function removes all PowerShell transcript files
        located in a specified folder. By default, this folder is the Documents
        folder within the user's profile directory. Transcript files follow the
        naming convention "Powershell_transcript.<ORIGIN>.<UID>.<TIMESTAMP>.txt".
        The Origin is a Hostname.

        To specify a different directory, use the -TranscriptPath parameter.
        Before deleting any files, the function checks to make sure the folder exists.
        If the folder does not exist, an exception is thrown.

        The -WhatIf parameter can be used to preview which files would be deleted
        without actually deleting them.
    .EXAMPLE
        Clear-Transcript
        This command will remove all PowerShell transcripts from the default directory.
    .EXAMPLE
        Clear-Transcript -TranscriptPath "C:\Users\username\Desktop"
        This command will remove all PowerShell transcripts from the specified directory.
    .EXAMPLE
        Clear-Transcript -WhatIf
        This command will list all PowerShell transcripts that would be deleted from
        the default directory, without actually deleting them.
#>
function Clear-Transcript {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([type])]
    param(
        # TranscriptPath
        [Parameter(Position = 1)]
        [string]
        $TranscriptPath = (Join-Path $env:USERPROFILE "Documents")
    )

    # Validate the TranscriptPath parameter
    if (-not (Test-Path -Path $TranscriptPath -PathType Container)) {
        throw "The specified TranscriptPath '$TranscriptPath' does not exist."
    }
        
    $itemsToDelete = Get-ChildItem -Path $TranscriptPath -Filter "Powershell_transcript.*.*.*.txt"
    $TranscriptCount= $itemsToDelete.Count
    if ($PSCmdlet.ShouldProcess("$TranscriptPath", "Remove $TranscriptCount transcript files")) {
        $itemsToDelete | Remove-Item
    }
}


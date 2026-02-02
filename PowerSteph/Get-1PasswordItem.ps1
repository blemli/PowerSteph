function Get-1PasswordItem {
    <#
    .SYNOPSIS
        Retrieves a field value from a 1Password item.

    .DESCRIPTION
        Uses the 1Password CLI (op) to retrieve a specific field from a vault item.
        Requires the 1Password CLI to be installed and authenticated.

    .PARAMETER Name
        The name or ID of the 1Password item.

    .PARAMETER Field
        The field to retrieve (e.g., 'password', 'username', 'otp').

    .PARAMETER Vault
        Optional vault to search in. If not specified, searches all vaults.

    .PARAMETER Category
        Filter by item category (e.g., 'Login', 'API Credential', 'Password', 'Secure Note').

    .EXAMPLE
        Get-1PasswordItem -Name "GitHub" -Field "password"

        Retrieves the password field from the GitHub item.

    .EXAMPLE
        Get-1PasswordItem -Name "AWS" -Field "username"

        Retrieves the username field from the AWS item.

    .EXAMPLE
        Get-1PasswordItem -Name "Google" -Field "otp"

        Retrieves the current OTP code from the Google item.

    .EXAMPLE
        Get-1PasswordItem -Name "Database" -Field "password" -Vault "Work"

        Retrieves the password from a specific vault.

    .EXAMPLE
        Get-1PasswordItem -Name "AWS" -Field "credential" -Category "API Credential"

        Retrieves the credential from an API Credential item, useful when multiple items share the same name.

    .LINK
        https://developer.1password.com/docs/cli/
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("Item", "Title")]
        [string]
        $Name,

        [Parameter(Mandatory, Position = 1)]
        [Alias("Property")]
        [string]
        $Field,

        [Parameter()]
        [string]
        $Vault,

        [Parameter()]
        [Alias("Type")]
        [ValidateSet("Login", "Password", "API Credential", "Credit Card", "Identity", "Secure Note", "Document", "SSH Key", "Database", "Server")]
        [string]
        $Category
    )

    begin {
        # Check if op CLI is available
        if (-not (Get-Command "op" -ErrorAction SilentlyContinue)) {
            throw "1Password CLI (op) is not installed or not in PATH. Install from https://1password.com/downloads/command-line/"
        }
    }

    process {
        $itemIdentifier = $Name

        # If Category is specified, find the item ID first
        if ($Category) {
            $listArgs = @("item", "list", "--categories", $Category, "--format", "json")

            if ($Vault) {
                $listArgs += "--vault"
                $listArgs += $Vault
            }

            $items = & op @listArgs 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to list items: $items"
                return
            }

            $matchedItem = $items | Where-Object { $_.title -eq $Name } | Select-Object -First 1

            if (-not $matchedItem) {
                Write-Error "No '$Category' item found with name '$Name'."
                return
            }

            $itemIdentifier = $matchedItem.id
        }

        $opArgs = @("item", "get", $itemIdentifier, "--fields", $Field, "--reveal")

        if ($Vault -and -not $Category) {
            $opArgs += "--vault"
            $opArgs += $Vault
        }

        $result = & op @opArgs 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to retrieve '$Field' from '$Name': $result"
            return
        }

        $result
    }
}

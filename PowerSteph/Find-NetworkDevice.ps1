function Find-NetworkDevice {
    <#
    .SYNOPSIS
        Discovers network devices using ARP, resolving hostnames and MAC vendors.

    .DESCRIPTION
        Scans the local network to find devices by querying the ARP cache.
        Can optionally ping-sweep a subnet to populate the cache first.
        Resolves hostnames via DNS and looks up MAC vendor information.
        Works on both macOS and Windows.

    .PARAMETER Subnet
        CIDR notation subnet to scan (e.g., "192.168.1.0/24").
        Defaults to the current network's subnet.

    .PARAMETER IPv6
        Include IPv6 addresses in the results.

    .PARAMETER Force
        Ping-sweep the subnet first to populate the ARP cache.
        Without this, only devices already in the cache are shown.

    .EXAMPLE
        Find-NetworkDevice

        Lists devices currently in the ARP cache on the local subnet.

    .EXAMPLE
        Find-NetworkDevice -Force

        Ping-sweeps the local subnet first, then lists all responding devices.

    .EXAMPLE
        Find-NetworkDevice -Subnet "192.168.1.0/24" -Force

        Scans a specific subnet.

    .EXAMPLE
        Find-NetworkDevice -IPv6

        Includes IPv6 addresses in the output.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [ValidatePattern('^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$')]
        [string]$Subnet,

        [Parameter()]
        [switch]$IPv6,

        [Parameter()]
        [switch]$Force
    )

    $IsMacOS = $PSVersionTable.OS -match 'Darwin' -or $IsMacOS
    $IsWindows = $PSVersionTable.OS -match 'Windows' -or (-not $IsMacOS -and -not $IsLinux)

    # Helper: Get current subnet in CIDR notation
    function Get-CurrentSubnet {
        if ($IsMacOS) {
            # Get default route interface
            $routeInfo = & route -n get default 2>&1
            $interface = ($routeInfo | Select-String 'interface:\s*(\S+)').Matches.Groups[1].Value

            if (-not $interface) {
                $interface = 'en0'
            }

            # Get IP and netmask from ifconfig
            $ifconfig = & ifconfig $interface 2>&1
            $inetLine = $ifconfig | Select-String 'inet\s+(\d+\.\d+\.\d+\.\d+)\s+netmask\s+(0x[0-9a-f]+)'

            if (-not $inetLine) {
                throw "Could not determine IP address for interface $interface"
            }

            $ip = $inetLine.Matches.Groups[1].Value
            $netmaskHex = $inetLine.Matches.Groups[2].Value

            # Convert hex netmask to prefix length
            $netmaskInt = [Convert]::ToUInt32($netmaskHex, 16)
            $prefix = 0
            while ($netmaskInt -ne 0) {
                $prefix += $netmaskInt -band 1
                $netmaskInt = $netmaskInt -shr 1
            }
        }
        else {
            # Windows: use Get-NetIPAddress, prefer connected physical adapters
            $adapters = Get-NetIPAddress -AddressFamily IPv4 |
                Where-Object {
                    $_.IPAddress -notlike '127.*' -and
                    $_.IPAddress -notlike '169.254.*' -and
                    $_.PrefixOrigin -ne 'WellKnown'
                }

            # Try to find the best adapter (prefer ones with default gateway)
            $bestAdapter = $null
            foreach ($adp in $adapters) {
                $ifIndex = $adp.InterfaceIndex
                $route = Get-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue
                if ($route) {
                    $bestAdapter = $adp
                    break
                }
            }

            # Fallback to first non-loopback adapter
            if (-not $bestAdapter) {
                $bestAdapter = $adapters | Select-Object -First 1
            }

            if (-not $bestAdapter) {
                throw "Could not determine local network adapter"
            }

            $ip = $bestAdapter.IPAddress
            $prefix = $bestAdapter.PrefixLength
            Write-Verbose "Using adapter with IP: $ip/$prefix"
        }

        $ipBytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
        $maskBytes = [byte[]]::new(4)

        for ($i = 0; $i -lt 4; $i++) {
            $bits = [Math]::Min(8, [Math]::Max(0, $prefix - ($i * 8)))
            $maskBytes[$i] = [byte](256 - [Math]::Pow(2, 8 - $bits))
        }

        $networkBytes = for ($i = 0; $i -lt 4; $i++) { $ipBytes[$i] -band $maskBytes[$i] }
        $network = ($networkBytes -join '.')

        return "$network/$prefix"
    }

    # Helper: Get IP range from CIDR
    function Get-IPRange {
        param ([string]$CIDR)

        $parts = $CIDR -split '/'
        $baseIP = [System.Net.IPAddress]::Parse($parts[0])
        $prefix = [int]$parts[1]

        $ipBytes = $baseIP.GetAddressBytes()
        [Array]::Reverse($ipBytes)
        $ipInt = [BitConverter]::ToUInt32($ipBytes, 0)

        $hostBits = 32 - $prefix
        $numHosts = [Math]::Pow(2, $hostBits) - 2
        $networkInt = $ipInt -band ([UInt32]::MaxValue -shl $hostBits)

        $ips = @()
        for ($i = 1; $i -le $numHosts -and $i -le 254; $i++) {
            $currentInt = $networkInt + $i
            $bytes = [BitConverter]::GetBytes([UInt32]$currentInt)
            [Array]::Reverse($bytes)
            $ips += ([System.Net.IPAddress]::new($bytes)).ToString()
        }
        return $ips
    }

    # Helper: Lookup MAC vendor from OUI file
    function Get-MacVendor {
        param ([string]$MAC)

        if (-not $script:OUITable) {
            $ouiPath = Join-Path $PSScriptRoot 'oui.txt'
            if (Test-Path $ouiPath) {
                $script:OUITable = @{}
                Get-Content $ouiPath | ForEach-Object {
                    if ($_ -match '^([0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2})\t(.+)$') {
                        $script:OUITable[$matches[1].ToUpper()] = $matches[2]
                    }
                }
            } else {
                $script:OUITable = @{}
            }
        }

        # Normalize MAC and get prefix
        $normalizedMac = ($MAC -replace '-', ':').ToUpper()
        if ($normalizedMac.Length -ge 8) {
            $prefix = $normalizedMac.Substring(0, 8)
            return $script:OUITable[$prefix]
        }
        return $null
    }

    # Helper: Resolve hostname
    function Resolve-DeviceHostname {
        param ([string]$IP)

        try {
            $dns = [System.Net.Dns]::GetHostEntry($IP)
            if ($dns.HostName -and $dns.HostName -ne $IP) {
                return $dns.HostName
            }
        } catch { }

        return $null
    }

    # Main logic
    if (-not $Subnet) {
        $Subnet = Get-CurrentSubnet
        Write-Verbose "Detected subnet: $Subnet"
    }

    # Parse subnet for filtering
    $subnetParts = $Subnet -split '/'
    $subnetBase = $subnetParts[0]
    $subnetPrefix = [int]$subnetParts[1]

    # Calculate network address for filtering
    $baseBytes = [System.Net.IPAddress]::Parse($subnetBase).GetAddressBytes()
    $maskBytes = [byte[]]::new(4)
    for ($i = 0; $i -lt 4; $i++) {
        $bits = [Math]::Min(8, [Math]::Max(0, $subnetPrefix - ($i * 8)))
        $maskBytes[$i] = [byte](256 - [Math]::Pow(2, 8 - $bits))
    }

    if ($Force) {
        Write-Verbose "Ping-sweeping subnet $Subnet..."
        $ips = Get-IPRange -CIDR $Subnet
        $isMac = $IsMacOS

        # Use parallel ping for speed
        try {
            $ips | ForEach-Object -ThrottleLimit 50 -Parallel {
                if ($using:isMac) {
                    ping -c 1 -W 1 $_ 2>&1 | Out-Null
                }
                else {
                    ping -n 1 -w 500 $_ 2>&1 | Out-Null
                }
            }
        } catch {
            # Ignore ping errors
        }

        Start-Sleep -Milliseconds 500
    }

    # Get ARP table
    Write-Verbose "Reading ARP cache..."
    $arpOutput = & arp -a 2>&1

    $devices = @{}

    foreach ($line in $arpOutput) {
        $ip = $null
        $mac = $null

        if ($IsMacOS) {
            # macOS format: ? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
            # or: hostname (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
            if ($line -match '\((\d+\.\d+\.\d+\.\d+)\)\s+at\s+([0-9a-f:]{17})') {
                $ip = $matches[1]
                $mac = $matches[2].ToUpper()
            }
        }
        else {
            # Windows format: 192.168.1.1     aa-bb-cc-dd-ee-ff     dynamic
            if ($line -match '^\s*(\d+\.\d+\.\d+\.\d+)\s+([0-9a-f-]{17})\s+(\w+)') {
                $ip = $matches[1]
                $mac = $matches[2].ToUpper() -replace '-', ':'
                $type = $matches[3]

                if ($type -ne 'dynamic' -and $type -ne 'static') {
                    continue
                }
            }
        }

        if ($ip -and $mac -and $mac -ne 'FF:FF:FF:FF:FF:FF' -and $mac -notmatch '^\(incomplete\)') {
            # Check if IP is in our subnet
            $ipBytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
            $inSubnet = $true
            for ($i = 0; $i -lt 4; $i++) {
                if (($ipBytes[$i] -band $maskBytes[$i]) -ne ($baseBytes[$i] -band $maskBytes[$i])) {
                    $inSubnet = $false
                    break
                }
            }

            if ($inSubnet) {
                $devices[$mac] = @{
                    IPAddress = $ip
                    MACAddress = $mac
                }
            }
        }
    }

    # Get IPv6 neighbors if requested
    $ipv6Map = @{}
    if ($IPv6) {
        Write-Verbose "Reading IPv6 neighbor cache..."

        if ($IsMacOS) {
            # macOS: use ndp -an
            $ipv6Output = & ndp -an 2>&1

            foreach ($line in $ipv6Output) {
                # Format: fe80::1%en0  aa:bb:cc:dd:ee:ff  en0  ...
                if ($line -match '^(fe80[^\s%]+)%?\S*\s+([0-9a-f:]{17})') {
                    $ip6 = $matches[1]
                    $mac6 = $matches[2].ToUpper()
                    if (-not $ipv6Map.ContainsKey($mac6)) {
                        $ipv6Map[$mac6] = $ip6
                    }
                }
            }
        }
        else {
            # Windows: use netsh
            $ipv6Output = & netsh interface ipv6 show neighbors 2>&1

            foreach ($line in $ipv6Output) {
                if ($line -match '^\s*(fe80[^\s]+)\s+([0-9a-f-]{17})') {
                    $ip6 = $matches[1]
                    $mac6 = $matches[2].ToUpper() -replace '-', ':'
                    if (-not $ipv6Map.ContainsKey($mac6)) {
                        $ipv6Map[$mac6] = $ip6
                    }
                }
            }
        }
    }

    # Build output objects
    Write-Verbose "Resolving hostnames and vendors..."
    foreach ($mac in $devices.Keys) {
        $device = $devices[$mac]

        [PSCustomObject]@{
            Hostname    = Resolve-DeviceHostname -IP $device.IPAddress
            IPAddress   = $device.IPAddress
            IPv6Address = if ($IPv6) { $ipv6Map[$mac] } else { $null }
            MACAddress  = $device.MACAddress
            Vendor      = Get-MacVendor -MAC $device.MACAddress
        }
    }
}

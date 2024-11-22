# Paths
$rootPath = $PSScriptRoot | Split-Path
$configPath = (Join-Path $rootPath 'config.json')
$regBkPath = Join-Path $rootPath "reg"

# reg paths
$msRegPath = "HKLM:\SOFTWARE\Microsoft\GamingServices"
$pkgRegPath = Join-Path $msRegPath "PackageRepository"
$baseConfigPath = Join-Path $msRegPath "GameConfig"

# Log
$dateNow = $((Get-Date).ToString('yyyy.MM.dd_hh.mm.ss'))
$logfileName = "logfile_$dateNow.log"
$logFolderPath = Join-Path $rootPath 'logs'
$LogPath = Join-Path $logFolderPath $logfileName

function testPath() {
    param (
        [Parameter(Mandatory)]
        [string]$path
    )

    return Test-Path -LiteralPath $path
}

function getRootPath() {
    return $rootPath
}

function getLogPath() {
    return $LogPath
}

function getConfigPath() {
    return $configPath
}

function fileExists() {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Path', Position = 0)]
        [Parameter(Mandatory, ParameterSetName = 'PathAll', Position = 0)]
        [string]$Path,

        [Parameter(ParameterSetName = 'PathAll', Position = 1)]
        [string]$FileName
    )

    if ($FileName.Length -gt 0) {
        $path = Join-Path $path $fileName
    }


    return testPath $Path
}

function getFullPath() {
    param (
        [Parameter(Mandatory)] [String] $file
    )
    return (Join-Path $rootPath $file)
}

function logToFile() {
    [CmdletBinding(DefaultParameterSetName = 'log')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'log', Position = 0)]
        [String] $content
    )

    "$((Get-Date).ToString()) $content" | Out-File $LogPath -Append -Encoding UTF8
}

function writeToConsole() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'Color options')
    ]
    [CmdletBinding(DefaultParameterSetName = 'Message-Host')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Message-Host', Position = 0)]
        [Parameter(Mandatory, ParameterSetName = 'Message-Host-Color', Position = 0)]
        [Parameter(Mandatory, ParameterSetName = 'Message-Log', Position = 0)]
        [String] $msg,

        [Parameter(Mandatory, ParameterSetName = 'Message-Host-Color')]
        [switch] $type,

        [Parameter(Mandatory, ParameterSetName = 'Message-Host-Color')]
        [String] $color,

        [Parameter(ParameterSetName = 'Message-Host-Color')]
        [String] $bgcolor,

        [Parameter(Mandatory, ParameterSetName = 'Message-Log')]
        [switch] $log
    )

    if ($type) {
        if (!$color) {
            $color = "White"
        }

        if (!$bgcolor) {
            $bgcolor = "Black"
        }

        Write-Host $msg -ForegroundColor $color -BackgroundColor $bgcolor
    }
    elseif ($log) {
        Write-Information -MessageData $msg -InformationAction Continue
        logToFile $msg
    }
    else {
        Write-Information -MessageData $msg -InformationAction Continue
    }
}

function getLatestFileName() {
    try {
        $files = Get-ChildItem -Path (getFullPath 'hex_tables') -Filter *.json | ForEach-Object { $_.Name }

        $versionUnsorted = $files | ForEach-Object { $_.toString().Split("_")[2] }
        $versionSorted = $versionUnsorted | Sort-Object { [version]$_ } -Descending
        $latestVersionidx = [array]::IndexOf($versionUnsorted, $versionSorted[0])

        return $files[$latestVersionidx]
    }
    catch {
        logToFile $_.Exception
    }
}

function getLatestCommitId() {
    $fileName = getLatestFileName
    $fileNameParts = $fileName.toString().Split('_')[3]
    $commitId = $fileNameParts.substring(0, $fileNameParts.length - 0 - 5)
    return $commitId
}

function getGameVersion() {
    $fileName = getLatestFileName
    $version = $fileName.toString().Split('_')[2].Split('.') -join '_'
    return $version
}

function getConfigProperty() {
    param (
        [string]$property
    )

    if (fileExists $configPath) {
        $config = Get-Content -Raw $configPath | ConvertFrom-Json

        if ($config.$property) {
            return $config.$property.toString()
        }
        else {
            return $false
        }
    }
    else {
        logToFile "config not found - Path: $configPath"
    }
}

function setConfigProperty() {
    param (
        [string]$property,
        [string]$value
    )
    try {
        if (!(fileExists $configPath)) {
            $config = @{$property = $value }
        }
        else {
            $config = Get-Content -Raw $configPath | ConvertFrom-Json

            if (!$config.$property) {
                $config | Add-Member @{$property = $value } -Force
            }
            else {
                $config.$property = $value
            }
        }

        ConvertTo-Json $config -Depth 1 | Out-File $configPath -Force
    }
    catch {
        logToFile $_.Exception
    }
}

function runProcessAndLog() {
    param (
        [string]$command,
        [string]$workingDir,
        [string]$argsToPass,
        [int]$timeout
    )

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $command
    $pinfo.WorkingDirectory = $workingDir
    $pinfo.Arguments = $argsToPass
    $pinfo.Verb = "runAs"

    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $false

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null

    if ($timeout) {
        $Seconds = $timeout
        $EndTime = [datetime]::UtcNow.AddSeconds($Seconds)
        $TimeRemaining = ($EndTime - [datetime]::UtcNow)

        while ($TimeRemaining -gt 0) {
            Write-Progress -Activity 'Building SFSE...' -Status Building -SecondsRemaining $TimeRemaining.TotalSeconds
            Start-Sleep 1
            if ($p.ExitCode -eq 0) {
                break
            }
        }

        # Clear progress bar
        Write-Progress -Activity 'Building SFSE...' -Completed
    }

    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    logToFile -Content "stdout: $stdout"
    logToFile -Content "stderr: $stderr"
    logToFile -Content ("exit code: " + $p.ExitCode)
}

function hasPermissions() {
    param (
        [Parameter(Mandatory = $true)] [String] $path,
        [Parameter(Mandatory = $false)] [switch] $checkVersionInfo
    )

    if (!$path) {
        return $false
    }

    # We can check the exe details to determine if we have full access, as it's hidden by default
    if (!$checkVersionInfo) {
        # Allows the user to bypass the folder permissions check, not recommended.
        getConfigProperty "bypassFolderPermissionCheck" $bypassPerms

        if ($bypassPerms) {
            return $true
        }

        # Get current user
        $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

        # Quick and dirty check to see if user has FullControl file system rights, returns null if not.
        $permissions = (Get-Acl -LiteralPath $path).Access | Where-Object { $_.IdentityReference -eq $user -and $_.FileSystemRights -eq "FullControl" }
    }
    else {
        $permissions = (Get-Item -LiteralPath $path).VersionInfo | Select-Object -ExpandProperty FileDescription
    }

    if ($permissions) {
        return $true
    }

    return $false
}

function refresh() {
    # Check if choco is installed, if so use it's command otherwise fallback to manual refresh
    try {
        # Import choco for refreshenv command
        $env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."
        Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

        refreshenv
    }
    catch {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
}

function isSamePath() {
    param (
        [Parameter(Mandatory)]
        [string]$path
    )

    $gamePath = (getConfigProperty "gamePath")

    if (!($gamePath)) {
        $gamePath = getStarfieldPath
        $gamePathSymLink = getStarfieldPath -symlink
    }

    if ($gamePath.Contains($path) -or ($gamePathSymLink -and $gamePathSymLink.Contains($path))) {
        return $true
    }

    return $false
}

function findRegistryKeys() {
    param (
        [Parameter(Mandatory)]
        [string]$path
    )

    if (!(Test-Path -Path $path)) {
        logToFile -Content "$path not found"
        return $false
    }

    $results = @(Get-ChildItem -Path $path -Name)

    if (!$results) {
        return $false
    }
    else {
        return $results
    }
}

function findRegistryValues() {
    param (
        [Parameter(Mandatory)]
        [String] $path,
        [String] $value
    )

    if (!(Test-Path -Path $path)) {
        logToFile -Content "$path not found"
        return $false
    }

    $result = $false

    if ($value) {
        $result = Get-ItemProperty -Path $path | Select-Object "$value*"
    }
    else {
        $result = Get-ItemProperty -Path $path
    }

    if (!$result) {
        return $false
    }
    else {
        $hashtable = @{}
        $result.psobject.properties | ForEach-Object { $hashtable[$_.Name] = $_.Value }
        return $hashtable
    }
}

function getStarfieldPackage() {
    param (
        [Switch] $key
    )

    if (!(Test-Path -Path $pkgRegPath)) {
        logToFile -Content "Microsoft Package registry not found"
        return $false
    }
    else {
        $installedPkgsPath = Join-Path $pkgRegPath "Package"
        $packageKeyValues = findRegistryValues -path $installedPkgsPath -value "BethesdaSoftworks.ProjectGold"

        if ($packageKeyValues) {
            if ($key) {
                return $packageKeyValues.keys[0]
            }
            else {
                return $packageKeyValues.Values[0]
            }
        }
        else {
            logToFile -Content "Cannot retrieve path, starfield package not found in registry"
            return $false
        }
    }
}

function getStarfieldPath() {
    param (
        [Switch] $symlink
    )

    $starfieldUniqueKey = getStarfieldPackage
    if ($starfieldUniqueKey) {
        $rootPath = Join-Path $pkgRegPath "Root"
        $uniqueKeyPath = Join-Path $rootPath $starfieldUniqueKey
        $gameRootKey = findRegistryKeys -path $uniqueKeyPath

        if ($gameRootKey) {
            $gameRootPath = Join-Path $uniqueKeyPath $gameRootKey
            $gameRoot = findRegistryValues -path $gameRootPath -value "Root"

            if ($gameRoot) {
                $trimmedPath = $gameRoot.Values[0].replace("\\?\", "")

                if ($symlink) {
                    return (Get-Item $trimmedPath).Target
                }
                else {
                    return  $trimmedPath
                }
            }
            else {
                return $false
            }
        }
    }
}

function getRegConfigPath() {
    $starfieldPackageKey = getStarfieldPackage -key
    if ($starfieldPackageKey) {
        $starfieldConfigPath = Join-Path $baseConfigPath $starfieldPackageKey
        if (!(Test-Path -Path $starfieldConfigPath)) {
            logToFile -Content "Starfield config reg key not found!"
            return $false
        }
        else {
            return $starfieldConfigPath
        }
    }
}

function sfseRegistryExists() {
    $starfieldConfigPath = getRegConfigPath
    if ($starfieldConfigPath) {
        $sfseExePath = Join-Path (Join-Path $starfieldConfigPath "Executable") '00000001'
        if (!(Test-Path -Path $sfseExePath)) {
            logToFile -Content "SFSE registry entry does not exist!"
            return $false
        }
        else {
            return $true
        }
    }
}

function backupGameReg() {
    if (!(fileExists $regBkPath)) {
        New-Item -Path $rootPath -Name "reg" -ItemType "directory"
    }

    $starfieldConfigPath = getRegConfigPath
    if ($starfieldConfigPath) {
        $gameVersionVal = findRegistryValues -path $starfieldConfigPath -value "Version"
        if ($gameVersionVal) {
            $version = $gameVersionVal.Values[0]
            $regFileName = "$version.reg"

            if (!(Test-Path -Path (Join-Path $regBkPath $regFileName))) {
                $regExpFriendlyPath = $starfieldConfigPath -replace ':', ''
                reg export $regExpFriendlyPath (Join-Path $regBkPath $regFileName)
            }
            else {
                logToFile -Content "Reg file backup exists, skipping."
            }
        }
        else {
            logToFile -Content "Cannot retrieve game version from registry"
        }
    }
}

function setSFSERegistry() {
    $starfieldConfigPath = getRegConfigPath
    if (!(sfseRegistryExists) -and $starfieldConfigPath) {
        $gameExePath = Join-Path (Join-Path $starfieldConfigPath "Executable") '00000000'
        $sfseExePath = Join-Path (Join-Path $starfieldConfigPath "Executable") '00000001'

        # Backup reg if not already
        backupGameReg

        if ((Test-Path -Path $gameExePath)) {
            Copy-Item $gameExePath $sfseExePath

            if (Test-Path -Path $sfseExePath) {
                Set-ItemProperty -Path $sfseExePath -Name "Name" -Value "sfse_loader.exe"
                logToFile -Content "SFSE registry added successfully!"
            }
        }
    }
    else {
        logToFile -Content "SFSE registry already exists, skipping!"
    }
}

function removeSFSERegistry() {
    $starfieldConfigPath = getRegConfigPath
    if ($starfieldConfigPath) {
        $sfseExePath = Join-Path (Join-Path $starfieldConfigPath "Executable") '00000001'
        if (!(Test-Path -Path $sfseExePath)) {
            logToFile -Content "SFSE registry entry does not exist!"
        }
        else {
            Remove-Item $sfseExePath
        }
    }
}

function setSFSEPath() {
    $gamePathReg = getStarfieldPath -symlink
    setConfigProperty "gamePath" $gamePathReg
}

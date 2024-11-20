# Paths
$rootPath = $PSScriptRoot | Split-Path
$configPath = (Join-Path $rootPath 'config.json')

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
                $config | Add-Member @{$property = $value }
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
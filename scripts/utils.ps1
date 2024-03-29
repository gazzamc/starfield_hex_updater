function testPath() {
    param (
        [string]$path
    )

    if (!$path) {
        return $false
    }

    if (Test-Path -Path $path) {
        return $true
    }
    else {
        return $false
    }
}

function fileExists() {
    param (
        [Parameter(Mandatory = $true)] [String] $path,
        [Parameter(Mandatory = $false)] [String] $fileName
    )

    $exists = $false

    if (testPath (Join-Path $path $fileName)) {
        $exists = $true
    }

    return $exists
}

function getFullPath() {
    param (
        [Parameter(Mandatory = $true)] [String] $file
    )
    return (Join-Path $rootPath $file)
}

function logToFile() {
    param (
        [Parameter(Mandatory = $true)] [String] $content,
        [Parameter(Mandatory = $true)] [String] $filePath
    )
    
    "$((Get-Date).ToString()) $content" | Out-File $filePath -Append -Encoding UTF8
}

function writeToConsole() {
    param (
        [Parameter(Mandatory = $true)] [String] $msg,
        [Parameter(Mandatory = $false)] [switch] $type,
        [Parameter(Mandatory = $false)] [String] $color,
        [Parameter(Mandatory = $false)] [String] $bgcolor,
        [Parameter(Mandatory = $false)] [String] $logPath
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
    elseif ($logPath) {
        Write-Information s -MessageData $msg -InformationAction Continue -InformationVariable 'InfoMsg'
        logToFile $InfoMsg $logPath
    }
    else {
        Write-Information s -MessageData $msg -InformationAction Continue
    }
}

function getLatestFileName() {
    try {
        $files = Get-ChildItem -Path (getFullPath 'hex_tables') -filter *.json | ForEach-Object { $_.Name }

        $versionUnsorted = $files | ForEach-Object { $_.toString().Split("_")[2] }
        $versionSorted = $versionUnsorted | Sort-Object { [version]$_ } -Descending
        $latestVersionidx = [array]::IndexOf($versionUnsorted, $versionSorted[0])
    
        return $files[$latestVersionidx]
    }
    catch {
        logToFile $_.Exception $LogPath
        pause
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

    if (fileExists $rootPath "config.json") {
        $config = Get-Content -Raw (Join-Path $rootPath "config.json") | ConvertFrom-Json

        if ($config.$property) {
            return $config.$property.toString()
        }
    }
    else {
        return
    } 
}

function setConfigProperty() {
    param (
        [string]$property,
        [string]$value
    )


    if (!(fileExists $rootPath "config.json")) { 
        $config = @{$property = $value }
    }
    else {
        $config = Get-Content -Raw (Join-Path $rootPath "config.json") | ConvertFrom-Json
    
        if (!$config.$property) {
            $config | Add-Member @{$property = $value }
        }
        else {
            $config.$property = $value
        }
    }

    ConvertTo-Json $config -Depth 1 | Out-File "$rootPath\config.json" -Force
}
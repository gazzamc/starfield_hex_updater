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


function writeToConsole() {
    param (
        [Parameter(Mandatory = $true)] [String] $msg,
        [Parameter(Mandatory = $false)] [switch] $type,
        [Parameter(Mandatory = $false)] [String] $color,
        [Parameter(Mandatory = $false)] [String] $bgcolor
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
    else {
        Write-Information s -MessageData $msg -InformationAction Continue
    }
}

function getLatestCommitId() {
    $files = Get-ChildItem -Path (getFullPath 'hex_tables') -filter *.json -file | Sort-Object -Property Name -Descending
    $highestVersion = $files[0].toString().Split('_')[3]
    return $highestVersion.substring(0, $highestVersion.length - 0 - 5)
}

function getGameVersion() {
    $files = Get-ChildItem -Path (getFullPath 'hex_tables') -filter *.json -file | Sort-Object -Property Name -Descending
    $highestVersion = $files[0].toString().Split('_')[2].Split('.') -join '_'
    return $highestVersion
}

function getLatestDictFileName() {
    $files = Get-ChildItem -Path (getFullPath 'hex_tables') -filter *.json -file | Sort-Object -Property Name -Descending
    return $files[0]
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
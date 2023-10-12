# A PS script to patch/install Gamepass SFSE in one click

$ErrorActionPreference = "Stop"
$vsWhereURL = "https://github.com/microsoft/vswhere/releases/download/3.1.7/vswhere.exe"
$currentPath = Get-Location
$progsToInstall = New-Object System.Collections.Generic.List[System.Object]
$allDepsInstalled = $false;

function installProg() {
    param (
        [Parameter(Mandatory = $true)] [String] $name
    )
 
    Switch ($name) {
        "git" {
            writeToConsole "Installing Git..."
            choco install git
            Break
        }
        "cmake" {
            writeToConsole "Installing CMake..."
            choco install cmake
            Break
        }
        "python" {
            writeToConsole "Installing Python 3..."
            choco install python311
            Break
        }
        "vs" {
            writeToConsole "Installing Visual Studio 2022 and Build Tools..."
            choco install visualstudio2022community --package-parameters "--add Microsoft.VisualStudio.Product.BuildTools --includeRecommended --passive"
            Break
        }
        "notepadplusplus" {
            writeToConsole "Installing notepadplusplus..."
            choco install notepadplusplus.install
            Break
        }
        "chocolatey" {
            writeToConsole "Installing chocolatey..."

            Set-ExecutionPolicy Bypass -Scope Process -Force; 
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; 
            Invoke-Expression (
                (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

            Break
        }
    }
}

function checkCommand() {
    param (
        [Parameter(Mandatory = $true )] [String] $command
    )
    # Used for quickly determining if software is installed
    $isCommand = $false

    try {
        $command | Out-Null
        $isCommand = $true
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        # Catch exception to prevent script failure
    }

    return $isCommand
}

function isInstalled() {
    param (
        [Parameter(Mandatory = $true)] [String] $softwareName
    )
    Switch ($softwareName) {
        "git" {
            return checkCommand git 
        }
        "cmake" {
            return checkCommand cmake 
        }
        "python" {
            return checkCommand (python -VV)
        }
        "vs" {
            return checkCommand ((./tools/vswhere.exe -products Microsoft.VisualStudio.Product.Community -format json | 
                    ConvertFrom-Json).productId -eq "Microsoft.VisualStudio.Product.Community")
        }
        "chocolatey" {
            return checkCommand choco
        }
    }
}

function fileExists() {
    param (
        [Parameter(Mandatory = $true)] [String] $fileName
    )

    $exists = $false

    if (Test-Path -Path (getFullPath $fileName )) {
        $exists = $true
    }

    return $exists
}

function writeToConsole() {
    param (
        [Parameter(Mandatory = $true)] [String] $msg
    )
    Write-Information -MessageData ("`n`t" + $msg) -InformationAction Continue
}

function getFullPath() {
    param (
        [Parameter(Mandatory = $true)] [String] $file
    )
    return (Join-Path $currentPath $file)
}

function askAndDownload() {
    param (
        [Parameter(Mandatory = $true)] [String] $question, 
        [Parameter(Mandatory = $true)] [String] $downloadURL, 
        [Parameter(Mandatory = $true)] [String] $fileName, 
        [Parameter(Mandatory = $true)] [String] $bypass
    )

    if (!$bypassChecks) {
        # Ask user for permission to download
        $confirmation = Read-Host $question
        while ($confirmation -ne "y") {
            if ($confirmation -eq 'n') { exit }
            $confirmation = Read-Host $question
        }
    }
    # Check if folder exists, create if not
    if (!(fileExists "tools" )) {
        mkdir (getFullPath "tools" )
    }

    # Proceed with download
    $filePath = getFullPath("tools/" + $fileName)
    Invoke-WebRequest -Uri $downloadURL -OutFile $filePath
}

function checkVsCodeInstalled() {
    #Check if we already downloaded it
    if (!(fileExists "tools/vswhere.exe")) {
        askAndDownload "Do you want to download the tool to check if vs studio is installed? [y/n]" $vsWhereURL "vswhere.exe" $bypassChecks
    }

    #Check if already installed
    if (isInstalled "vs") {
        writeToConsole "> Visual studio was found, but this check doesn't look for C++ build tools, please ensure it's installed"
        return $true
    }
}

function preFlightCheck() {
    "`nChecking to ensure all prerequisites are met..."
    "Click the links for more info on each software"

    writeToConsole ("Chocolatey [https://chocolatey.org/] ...." + (& { if (isInstalled "chocolatey") { "Installed" } else { "Not Found"; $progsToInstall.Add("chocolatey") } }))

    writeToConsole ("Python [https://www.python.org/] ...." + (& { if (isInstalled "python") { "Installed" } else { "Not Found"; $progsToInstall.Add("python") } }))

    writeToConsole ("CMake [https://cmake.org/] ...." + (& { if (isInstalled "cmake") { "Installed" } else { "Not Found"; $progsToInstall.Add("CMake") } }))

    writeToConsole ("Git [https://git-scm.com/] ...." + (& { if (isInstalled "git") { "Installed" } else { "Not Found"; $progsToInstall.Add("Git") } }))

    writeToConsole ("Visual Studio 2022 [https://visualstudio.microsoft.com/vs/] ...." + (& { if (checkVsCodeInstalled) { "Installed" } else { "Not Found"; $progsToInstall.Add("VS2022") } }))
}

function installMissing() {
    if ($progsToInstall.ToArray().Count -eq 0) {
        writeToConsole "Nothing to install, continuing..."
    }
    else {
        # Install chocolatey as it's a dependency for the rest
        if ($progsToInstall.contains("chocolatey")) {
            $progsToInstall.Remove("chocolatey")
            installProg "chocolatey"
        }

        foreach ($prog in $progsToInstall) {
            installProg $prog
        }

        writeToConsole "Re-checking dependencies"
        preFlightCheck

        if ($progsToInstall.ToArray().Count -eq 0) {
            $allDepsInstalled = $true;
        }
    }
}


function getLatestCommitId() {
    $files = Get-ChildItem -Path (getFullPath 'hex_tables') -filter *.json -file | Sort-Object -Property Name -Descending
    $highestVersion = $files[0].toString().Split('_')[3]
    return $commit = $highestVersion.substring(0, $highestVersion.length - 0 - 5)
}

function getGameVersion() {
    $files = Get-ChildItem -Path (getFullPath 'hex_tables') -filter *.json -file | Sort-Object -Property Name -Descending
    $highestVersion = $files[0].toString().Split('_')[2].Split('.') -join '_'
    return $commit = $highestVersion
}

function getLatestDictFileName() {
    $files = Get-ChildItem -Path (getFullPath 'hex_tables') -filter *.json -file | Sort-Object -Property Name -Descending
    return $files[0]
}




function cloneRepo() {
    # Reset path
    cd $PSScriptRoot

    $commit = getLatestCommitId
    try {
        git clone https://github.com/gazzamc/sfse.git
        cd (getFullPath 'sfse')
        git checkout $commit
    }
    catch {
        # Catch exception to prevent script failure
        writeToConsole('Error')
    }
}

function buildRepo() {
    # Reset path
    cd $PSScriptRoot

    writeToConsole('Building SFSE')

    try {
        # Lets be sure were in the root of the script
        if (!(fileExists "AutoInstall.ps1")) {
            cd ..
        }

        cmake -B sfse/build -S sfse
        cmake --build sfse/build --config Release

        if (fileExists "sfse\build") {
            writeToConsole('Successfully built')
        }
    }
    catch {
        # Catch exception to prevent script failure
        writeToConsole('Error')
    }
}

function moveFiles() {
    # Reset path
    cd $PSScriptRoot

    writeToConsole('Moving Files..')

    $gamePath = Read-Host "Enter full path to Starfield game files eg. C:/path/to/Starfield/content"

    while ($gamePath -ne "") {
        if (!(fileExists $gamePath)) {
            writeToConsole("$gamePath does not exist!")
            exit 
        }
        else {
            break
        }
        writeToConsole($gamePath)
    }

    $gameVersion = getGameVersion
    $filesToCopy = "sfse_loader.exe", "sfse_$gameVersion.dll"

    try {
        # Find files in build folder and copy to user provided path
        foreach ($file in $filesToCopy) {
            Get-ChildItem -Path (getFullPath "sfse/build/") -Filter $file -Recurse | Copy-Item -Destination $gamePath
        }

        # Check files exist
        foreach ($file in $filesToCopy) {
            if (Test-Path -Path $gamePath -Filter $file) {
                writeToConsole("$file moved")
            }
        }
    }
    catch {
        writeToConsole("An Error occured during the copying of files")
    }
}

function patchFiles() {
    # Reset path
    cd $PSScriptRoot
    writeToConsole('Patching SFSE')

    # Get latest dictFile
    $dictFile = getFullPath ('/hex_tables/' + (getLatestDictFileName))

    # Update hex values
    python hex_updater.py -m update -p (getFullPath 'sfse/sfse') -d "$dictFile"

    # Patch loader
    python hex_updater.py -m patch -p (getFullPath 'sfse')

    # Check if bak files were created
    $backFiles = Get-ChildItem -Path (getFullPath "sfse/") -Filter *.bak -Recurse -File -Name

    if ($backFiles.length -eq 25) {
        writeToConsole('Successfully Patched SFSE')
    }
    else {
        writeToConsole('Unsuccessfully Patched SFSE')
    }
}


function autoInstall() {
    #  If starting script via right-click, as about prompts
    if (!$bypassChecks) {
        $question = "Would you like to bypass all confirmation prompts? [y/n]"
        $confirmation = Read-Host $question
        Do {
            if ($confirmation -eq 'y') {
                $bypassChecks = $true
                break
            }

            if ($confirmation -eq 'n') { 
                exit 
            }

            $confirmation = Read-Host $question
        }
        while ($Confirmation -ne "y")
    }

    # Check for all dependencies
    preFlightCheck

    # If any dependencies are missing try to install them
    if ($progsToInstall.length) {
        installMissing
    }
    else {
        $allDepsInstalled = $true;
    }

    if ($allDepsInstalled) {
        cloneRepo
        patchFiles
        buildRepo
        moveFiles
    }
    else {
        Clear-Host
        writeToConsole "Failed to install all dependencies, exiting!"
        exit
    }
}

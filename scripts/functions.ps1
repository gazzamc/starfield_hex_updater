. .\utils.ps1

# A PS script to patch/install Gamepass SFSE in one click

#URLs for tools needed
$vsWhereURL = "https://github.com/microsoft/vswhere/releases/download/3.1.7/vswhere.exe"
$pstools = "https://download.sysinternals.com/files/PSTools.zip"

$ErrorActionPreference = "Stop"
$rootPath = $PSScriptRoot | Split-Path # Root
$progsToInstall = New-Object System.Collections.Generic.List[System.Object]
$dateNow = $((Get-Date).ToString('yyyy.MM.dd_hh.mm.ss'))
$logfileName = "logfile_$dateNow.log"
$powershellVersion = $host.Version.Major
$version = "1.3.3"

$LogPath = Join-Path (Join-Path $rootPath 'logs') $logfileName

# Change powershell executable depending on version
if ($powershellVersion -eq 5) {
    $poweshellExe = "powershell"
}
else {
    $poweshellExe = "pwsh"
}

# Check if log folder exist
if (!(testPath (Join-Path $rootPath 'logs'))) {
    mkdir (Join-Path $rootPath "logs" )
}

function installProg() {
    param (
        [Parameter(Mandatory = $true)] [String] $name
    )
 
    Switch ($name) {
        "git" {
            writeToConsole "`n`t`tInstalling Git..." -logPath $LogPath
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command choco install git -y | Out-File $LogPath -Append -Encoding UTF8"
            Break
        }
        "cmake" {
            writeToConsole "`n`t`tInstalling CMake..." -logPath $LogPath
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command choco install cmake --installargs 'ADD_CMAKE_TO_PATH=System' -y | Out-File $LogPath -Append -Encoding UTF8"
            Break
        }
        "python" {
            writeToConsole "`n`t`tInstalling Python 3..." -logPath $LogPath
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command choco install python311 -y | Out-File $LogPath -Append -Encoding UTF8"
            Break
        }
        "vs" {
            writeToConsole "`n`t`tInstalling C++ Build Tools, This might take a while.." -logPath $LogPath
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command choco install visualstudio2019-workload-vctools --passive -y | Out-File $LogPath -Append -Encoding UTF8"
            Break
        }
        "chocolatey" {
            writeToConsole "`n`t`tInstalling chocolatey..." -logPath $LogPath

            # Choco requires admin rights to install properly
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command 

            Set-ExecutionPolicy Bypass -Scope Process -Force; 
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; 
            Invoke-Expression (
                (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) | Out-File $LogPath -Append -Encoding UTF8;"

            Break
        }
    }
}

function checkCommand() {
    param (
        [Parameter(Mandatory = $true )] [String] $command
    )
    # Used for quickly determining if software is installed
    $isCommand = $true

    try {
        # Catch vs command check first to prevent error
        # should set command variable true if present
        if ($command -eq 'True') {
            return $true
        }
        elseif ($command -eq 'False') {
            return $false
        }

        $result = [string](Get-Command $command | Select-Object).version

        if ($command -eq "python" -and $result -eq "0.0.0.0") {
            $isCommand = $false
        }

    }
    catch [System.Management.Automation.CommandNotFoundException] {
        # If we're here command not found, so software probably not installed
        logToFile $_.Exception $LogPath

        $isCommand = $false
    }

    return $isCommand
}

function checkForCompiler() {
    # Check if we have a c++ compiler installed/configured
    # Requires CMake
    
    try {
        $output = (cmake --system-information 2>$null | Where-Object { $_ -match "CMAKE_CXX_COMPILER ==" }).Split('==').Trim()

        if ($output[2] -ne "") {
            return $True
        }
    }
    catch {
        # Clean-up left over files from check if failed
        if (fileExists $PSScriptRoot '__cmake_systeminformation') {
            Remove-Item '__cmake_systeminformation' -Recurse
        }

        if ($output) {
            logToFile $output $LogPath
        }

        logToFile $_.Exception $LogPath

        return $False
    }
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
            return checkCommand python
        }
        "vs" {
            return checkCommand (Invoke-Expression "($(Join-Path (Join-Path $rootPath 'tools') vswhere.exe) -products Microsoft.VisualStudio.Product.Community -format json | 
            ConvertFrom-Json).productId -eq `"Microsoft.VisualStudio.Product.Community`"")
        }
        "chocolatey" {
            return checkCommand choco
        }
    }
}

function askAndDownload() {
    param (
        [Parameter(Mandatory = $true)] [String] $question, 
        [Parameter(Mandatory = $true)] [String] $downloadURL, 
        [Parameter(Mandatory = $true)] [String] $fileName, 
        [Parameter(Mandatory = $false)] [String] $bypass = $true
    )

    if (!$bypass) {
        # Ask user for permission to download
        $confirmation = Read-Host $question
        while ($confirmation -ne "y") {
            if ($confirmation -eq 'n') { exit }
            $confirmation = Read-Host $question
        }
    }
    # Check if folder exists, create if not
    if (!(fileExists $rootPath "tools" )) {
        mkdir (getFullPath "tools" )
    }

    # Proceed with download
    $filePath = getFullPath("tools/" + $fileName)
    Invoke-WebRequest -Uri $downloadURL -OutFile $filePath
}

function checkVsCodeInstalled() {
    #Check if we already downloaded it
    if (!(fileExists $rootPath "tools/vswhere.exe")) {
        try {
            askAndDownload "`n`t`tDo you want to download the tool to check if vs studio is installed? [y/n]" $vsWhereURL "vswhere.exe" ([System.Convert]::ToBoolean((getConfigProperty "bypassPrompts")))
        }
        catch {
            writeToConsole "`n`t`t`t> Failed to download vswhere.exe!" -logPath $LogPath
            logToFile $_.Exception $LogPath
            pause
            exit
        }
    }

    writeToConsole "`n`t`t`t> Checking for Compiler and/or VS2022, this might take a sec..." -logPath $LogPath

    #Check if already installed
    if ((isInstalled "vs") -and !(checkForCompiler)) {
        writeToConsole "`n`t`t`t> Visual studio was found, but check for compiler was not successful" -logPath $LogPath
        return $true
    }
    elseif (isInstalled "vs") {
        writeToConsole "`n`t`t`t> Visual studio and C++ compiler found" -logPath $LogPath
        return $true
    }
    elseif (checkForCompiler) {
        writeToConsole "`n`t`t`t> C++ compiler found" -logPath $LogPath
        return $true
    }
}

function checkDependencies() {
    Clear-Host
    # Reset progsToInstall before checking again
    $progsToInstall.Clear()

    "`n`tChecking to ensure all prerequisites are met..."
    "`n`tVisit the links for more info on each software"

    writeToConsole ("`n`t`tChocolatey [https://chocolatey.org/] ...." + (& { if (isInstalled "chocolatey") { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("chocolatey") } })) -logPath $LogPath

    writeToConsole ("`n`t`tPython [https://www.python.org/] ...." + (& { if (isInstalled "python") { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("python") } })) -logPath $LogPath

    writeToConsole ("`n`t`tCMake [https://cmake.org/] ...." + (& { if (isInstalled "cmake") { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("CMake") } })) -logPath $LogPath

    writeToConsole ("`n`t`tGit [https://git-scm.com/] ...." + (& { if (isInstalled "git") { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("Git") } })) -logPath $LogPath

    writeToConsole ("`n`t`tVisual Studio 2022 [https://visualstudio.microsoft.com/vs/] / C++ Build Tools ...." + (& { if (checkVsCodeInstalled) { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("vs") } })) -logPath $LogPath

    if (![System.Convert]::ToBoolean((getConfigProperty "bypassPrompts"))) {
        pause
    }
}

function installMissing() {
    Clear-Host

    if ($progsToInstall.ToArray().Count -eq 0) {
        writeToConsole "`n`t`tNothing to install, returning to menu..." -logPath $LogPath
        Start-Sleep 5
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

        writeToConsole "`n`t`tRefreshing Environment" -logPath $LogPath
        Start-Sleep 2

        # We need to refresh the env to detect new installs
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        writeToConsole "`n`t`tRe-checking dependencies" -logPath $LogPath
        checkDependencies
    }
}

function cloneRepo() {
    Clear-Host

    # Reset path
    Set-Location $rootPath

    $commit = getLatestCommitId
    try {
        writeToConsole "`n`t`tCloning SFSE and Checking out CommitID!" -logPath $LogPath

        git clone https://github.com/gazzamc/sfse.git
        Set-Location "sfse"
        git checkout $commit

        # Verify sfse exist before continuing
        if (!(fileExists $rootPath "sfse")) {
            throw "There was a problem cloning sfse repo"
        }
    }
    catch {
        # Catch exception to prevent script failure
        writeToConsole "`n`t`tFailed trying to checkout SFSE" -logPath $LogPath
        logToFile $_.Exception $LogPath
        pause
    }
}

function buildRepo() {
    Clear-Host
    writeToConsole "`n`t`tBuilding SFSE" -logPath $LogPath

    try {
        # Split build commands to reduce hanging
        Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -PassThru -WorkingDirectory $rootPath -ArgumentList "-command 
        cmake -B sfse/build -S sfse | Out-File $LogPath -Append -Encoding UTF8"


        Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -PassThru -WorkingDirectory $rootPath -ArgumentList "-command 
        cmake --build sfse/build --config Release | Out-File $LogPath -Append -Encoding UTF8"

        writeToConsole "`n`t`tBuild finished, verifying!" -logPath $LogPath

        if (fileExists $rootPath "sfse\build") {
            writeToConsole "`n`t`tSuccessfully built" -logPath $LogPath
            if (![System.Convert]::ToBoolean((getConfigProperty "bypassPrompts"))) {
                pause
            }
        }
        else {
            writeToConsole "`n`t`tCould not verify build, check manually!" -logPath $LogPath
            pause
        }
    }
    catch {
        # Catch exception to prevent script failure
        writeToConsole "`n`t`tError Building SFSE, check that you have C++ dev tools installed!" -logPath $LogPath
        logToFile $_.Exception $LogPath
        pause
    }
}

function moveSFSEFiles() {
    # Reset path
    Clear-Host
    Set-Location $rootPath

    $gamePath = getConfigProperty "newGamePath"
    writeToConsole "`n`t`tCopying SFSE Files to $gamePath..." -logPath $LogPath

    $gameVersion = getGameVersion
    $filesToCopy = "sfse_loader.exe", "sfse_$gameVersion.dll"



    try {
        # Find files in build folder and copy to user provided path
        foreach ($file in $filesToCopy) {
            Get-ChildItem -Path (getFullPath "sfse/build/") -Filter $file -Recurse | Copy-Item -Destination $gamePath  -Verbose *>&1 | Out-File -FilePath $LogPath -Append -Encoding UTF8
        }

        # Check files exist
        foreach ($file in $filesToCopy) {
            if (Test-Path -Path $gamePath -Filter $file) {
                writeToConsole "`n`t`t$file Successfully Copied!" -logPath $LogPath
            }
            else {
                writeToConsole "`n`t`tThere was an issue copying $file!" -logPath $LogPath
            }
        }

        Start-Sleep 5
    }
    catch {
        writeToConsole "`n`t`tAn Error occured during the copying of files" -logPath $LogPath
        logToFile $_.Exception $LogPath
        pause
    }
}

function patchFiles() {
    Clear-Host

    # Reset path
    Set-Location $rootPath
    writeToConsole "`n`tPatching SFSE" -logPath $LogPath

    # Get latest dictFile
    $dictFile = getFullPath ('/hex_tables/' + (getLatestDictFileName))

    # Update hex values
    python hex_updater.py -m update -p (getFullPath 'sfse/sfse') -d "$dictFile" | Out-File $LogPath -Append -Encoding UTF8

    # Patch loader
    python hex_updater.py -m patch -p (getFullPath 'sfse') | Out-File $LogPath -Append -Encoding UTF8

    # Check if bak files were created
    $backFiles = Get-ChildItem -Path (getFullPath "sfse/") -Filter *.bak -Recurse -File -Name

    if ($backFiles.length -eq 33) {
        writeToConsole "`n`t`tSuccessfully Patched SFSE" -logPath $LogPath
        if (![System.Convert]::ToBoolean((getConfigProperty "bypassPrompts"))) {
            pause
        }
    }
    else {
        writeToConsole "`n`t`tUnsuccessfully Patched SFSE, backup files found ($($backFiles.length)/33) " -logPath $LogPath
        pause
    }
}

function checkSpaceReq() {
    param (
        [string]$gamePath,
        [string]$newPath
    )

    $driveLetter = (Get-Item $newPath).PSDrive.Name + ":"
    $drives = Get-CimInstance -ClassName Win32_LogicalDisk | Select-Object -Property DeviceID, FreeSpace
    
    if ($drives.DeviceID -contains $driveLetter) {
        # Get free space of drive
        $idx = $drives.DeviceID.IndexOf($driveLetter)
        $space = ($drives[$idx].FreeSpace)

        # Get current size of game folder
        $folderSize = (Get-ChildItem -Path $gamePath -Recurse | Measure-Object -Property Length -Sum).sum

        if ($folderSize -gt $space) {
            writeToConsole "
            Not enough space on drive to copy the game: 

                Space Required: $([Math]::Round($folderSize / 1Gb, 2)) Gb
                Free Disk Space ($driveLetter): $([Math]::Round($space / 1Gb, 2)) Gb
            " -logPath $LogPath
            pause
        }
    }
    
}

function checkForPStools() {
    if (!(fileExists $rootPath "tools/PSTools/PsExec.exe")) {
        try {
            $question = "`n`tIn order to move the secured game exe we need to use PSTools, download? [y/n]"
            askAndDownload $question $pstools "pstools.zip" ([System.Convert]::ToBoolean((getConfigProperty "bypassPrompts")))
    
            if (fileExists $rootPath "tools/PSTools.zip") {
                #Extract to folder
                Expand-Archive -LiteralPath (getFullPath 'tools/PSTools.zip') -DestinationPath (getFullPath 'tools/PSTools')
    
                #Clean up zip
                Remove-Item (getFullPath 'tools/PSTools.zip')
            }
    
        }
        catch {
            writeToConsole "`n`tFailed to download PSTools, exiting!" -logPath $LogPath
            logToFile $_.Exception $LogPath
            pause
            exit 
        }
    }
}

function moveGameEXE() {
    $gamePath = getConfigProperty "gamePath"
    $newGamePath = getConfigProperty "newGamePath"

    checkForPStools

    try {
        # We can't copy directly from game folder so we need to move and copy back
        if (fileExists $gamePath 'Starfield.exe') {
            writeToConsole "`n`tCopying Starfield.exe to new game folder!" -logPath $LogPath
         
            # Calling powershell 7 from within psexec.exe does not seem to work, leaving it as powershell for now
            # as it's built-in to windows it should not cause issues as it's being called with system permissions anyway
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $rootPath/tools/PSTools/psexec.exe "-s -i -nobanner -accepteula powershell 
            Move-Item (Join-Path $gamePath 'Starfield.exe') -Destination (Join-Path $newGamePath 'Starfield.exe') -Verbose -Force *>&1 | 
            Out-File -FilePath $LogPath -Append -Encoding UTF8"
            Start-Sleep -Seconds 5
        }
        else {
            throw [System.IO.FileNotFoundException] "Starfield.exe cannot be found in game path $gamePath"
        }

        if (fileExists $newGamePath 'Starfield.exe') {
            Copy-Item (Join-Path $newGamePath 'Starfield.exe') -Destination (Join-Path $gamePath 'Starfield.exe')
            writeToConsole "`n`tStarfield.exe Copied back successfully!" -logPath $LogPath
            Start-Sleep -Seconds 5
        }
        else {
            throw [System.IO.FileNotFoundException] "Starfield.exe was not copied correctly as it cannot be found in $newGamePath"
        }
    }
    catch {
        if ($_.Exception.GetType().Name -eq "InvalidOperationException") {
            writeToConsole "`n`tCannot find PsExec.exe, please check that PSTools has been downloaded to the tools folder." -logPath $LogPath
        }
        elseif ($_.Exception.GetType().Name -eq "FileNotFoundException") {
            writeToConsole "`n`tStarfield.exe cannot be found in the folder specified, check log for more information!" -logPath $LogPath
        }
        else {
            writeToConsole "`n`tFailed to copy Starfield.exe for unknown reason, try manually copying the exe. (CTRL + X | CTRL + V)" -logPath $LogPath
        }

        logToFile $_.Exception $LogPath
        logToFile $_.Exception.GetType().Name $LogPath
        pause
    }
}

function moveGameFiles() {
    Clear-Host
    writeToConsole "`n`tMove/Hardlink Game Files.." -logPath $LogPath

    $type = Read-Host -Prompt "
    1. Copy Files 
    2. Hardlink Files (Does not work across drives)
    q. Return

    Choose the type of operation"

    # Return to menu
    if ($type -eq 'q') {
        return
    }

    if ($type -eq "" -or ($type -gt 2 -or $type -lt 1)) {
        writeToConsole "`n`tInvalid Option, exiting!"
        exit 
    }

    
    # Get path of game install and new location for files
    $gamePath = getConfigProperty "gamePath"
    $newGamePath = getConfigProperty "newGamePath"

    if ($type -eq 1) {
        # Check that we have enough space if copying
        checkSpaceReq $gamePath $newGamePath
        writeToConsole "`n`tCopying files to new location!" -logPath $LogPath

        # Copy over files
        ROBOCOPY $gamePath $newGamePath /E /XF (Join-Path $gamePath "Starfield.exe") | Out-File $LogPath -Append -Encoding UTF8
    }
    elseif ($type -eq 2) {
        writeToConsole "`n`tHardlinking files to new location!" -logPath $LogPath
        Get-ChildItem -Path $gamePath | ForEach-Object { 
            if ($_.PSIsContainer) {
                New-Item -ItemType Junction -Path "$($newGamePath)\$($_.Name)" -Value $_.FullName | Out-File $LogPath -Append -Encoding UTF8
            }
            else { 
                if ($_.Name -ne "Starfield.exe") {
                    New-Item -ItemType HardLink -Path "$($newGamePath)\$($_.Name)" -Value $_.FullName | Out-File $LogPath -Append -Encoding UTF8
                }
            }
        }
    }

    moveGameEXE
}

function autoInstall() {
    # Check for all dependencies
    checkDependencies

    # If any dependencies are missing try to install them
    if ($progsToInstall.ToArray().Count -gt 0) {
        installMissing
    }

    # Check condition again in case missing deps were installed in last step
    if ($progsToInstall.ToArray().Count -eq 0) {
        cloneRepo   
        patchFiles
        buildRepo
        moveGameFiles
        moveSFSEFiles

        Clear-Host
        writeToConsole "`n`tYou're ready to start using SFSE mods!"
        writeToConsole "`n`t`tCheck out the list of compatible mods here: 
        `n`t`thttps://github.com/gazzamc/starfield_hex_updater/blob/main/docs/compatibility"
        pause
    }
    else {
        writeToConsole "`n`tFailed to install dependencies: [$progsToInstall], exiting!" -logPath $LogPath
        exit
    }
}
function setGamePaths() {
    Clear-Host
    $paths = "`n`tGamePath", "`n`tNewGamePath"
    $noPathMsg = "`n`tPath inputted does not exist, please check that it exists! [q to exit]"

    foreach ($pathName in $paths) {
        $continue = $true;
        $inputtedPath = Read-Host $pathName
        while ($continue) {
            if (!(fileExists $inputtedPath)) {
                if ($inputtedPath -eq 'q') { exit }

                writeToConsole $noPathMsg
            }
            else {
                if ($pathName -eq $paths[0]) {
                    # Add a check for the content folder, add it if not present
                    $splitPath = $inputtedPath.split('\')

                    if ($splitPath[$splitPath.Length - 1].ToLower() -ne "content") {
                        $inputtedPath = Join-Path $inputtedPath "Content"
                    }

                    setConfigProperty "gamePath" $inputtedPath
                }
                else {
                    setConfigProperty "newGamePath" $inputtedPath
                }

                break
            }

            $inputtedPath = Read-Host $pathName
        }
    }
}

function setBypassChoice() {
    Clear-Host
    $question = "Would you like to bypass all future prompts? [y/n]"
    $confirmation = Read-Host $question
    while ($confirmation -ne "y" -and $confirmation -ne "n") {  
        $confirmation = Read-Host $question
    }

    if ($confirmation -eq 'y') {
        setConfigProperty "bypassPrompts" $true
    }
    elseif ($confirmation -eq 'n') {
        setConfigProperty "bypassPrompts" $false
    }
}

function welcomeScreen() {
    Clear-Host
    $title = (Get-Content -Raw "header.txt").Replace('x.x.x', $version).Replace('[at]', '@')
    
    writeToConsole $title
    writeToConsole "`n`tIn order to make the auto-install process as smooth as possible we'll set the path now, `n`tThis can be changed from the options menu." -type -color yellow -bgcolor black
    writeToConsole "`n`tOnce the path is set, you won't see this screen again on start-up." -type -color yellow -bgcolor black

    writeToConsole "`n`n`tGamePath: 
    `n`tThe original location installed by xbox app eg. C:\XboxGames\Starfield,
    `n`tIf you have not set the install folder in 'Options > Install Options' within the Xbox app, `n`tplease do so now and restart the script." 

    writeToConsole "`n`n`tNewGamePath: 
    `n`tThe new path that we will copy/hardlink the game files to in order to use SFSE,
    `n`tThis can be anywhere you choose but Hardlinking cannot be done across drives.

    `tOptions:
    `n`t`t Hardlinking: `n`n`t`t`tSaves space but will be modified when game updates (or deleted)
    `n`t`t Copying: `n`n`t`t`tRequires more space but will avoid issues after game updates, 
                    `n`t`t`thas continued to work after updates so far.`n" 

    pause
    setGamePaths
    setBypassChoice
}


# Show warning about spaced Path
if($rootPath.Contains(" ")){
    writeToConsole "
    It looks like you're running the script from a path that contains spaces: 
    `n`t'$rootPath'`n
    I would recommend moving and running the script from a location without spaces as they are known the cause issues. 
    I'm currently looking into this issue and hope to find a solution soon."

    pause
}

# Display start message/ set paths if config exist
if (!(fileExists $rootPath "config.json") -or 
    (!(testPath (getConfigProperty "gamePath")) -and 
    !(testPath (getConfigProperty "newGamePath")))) {
    welcomeScreen
}
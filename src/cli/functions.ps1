Import-Module (Join-Path $PSScriptRoot utils.psm1)

# A PS script to patch/install Gamepass SFSE in one click

#URLs for tools needed
$pstools = "https://download.sysinternals.com/files/PSTools.zip"
$python = "https://www.python.org/ftp/python/3.11.8/python-3.11.8-embed-amd64.zip"

$progsToInstall = New-Object System.Collections.Generic.List[System.Object]
$powershellVersion = $host.Version.Major
$version = "1.6.0"

# Paths
$rootPath = getRootPath
$logFolderPath = getLogPath | Split-Path
$LogPath = getLogPath
$sfsePath = Join-Path $rootPath 'sfse'
$sfseBuildPath = (Join-Path $sfsePath 'build')
$toolsPath = (Join-Path $rootPath 'tools')
$pythonPath = (Join-Path $toolsPath 'python')
$pythonZipPath = (Join-Path $toolsPath 'python.zip')
$psToolsPath = Join-Path $toolsPath 'pstools'
$psToolsZipPath = Join-Path $toolsPath 'pstools.zip'
$psExecPath = (Join-Path $psToolsPath 'psexec.exe')
$patcherFolderPath = (Join-Path $rootPath 'patcher')
$patcherPath = (Join-Path $patcherFolderPath 'patcher.py')


# Change powershell executable depending on version
if ($powershellVersion -eq 5) {
    $poweshellExe = "powershell"
}
else {
    $poweshellExe = "pwsh"
}

# Check if log folder exist
if (!(testPath $logFolderPath)) {
    mkdir $logFolderPath
}

function installProg() {
    param (
        [Parameter(Mandatory = $true)] [String] $name
    )

    Switch ($name) {
        "git" {
            writeToConsole "`n`t`tInstalling Git..." -log
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command choco install git -y --force | Out-File $LogPath -Append -Encoding UTF8"
            Break
        }
        "cmake" {
            writeToConsole "`n`t`tInstalling CMake..." -log
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command choco install cmake --installargs 'ADD_CMAKE_TO_PATH=System' -y --force | Out-File $LogPath -Append -Encoding UTF8"
            Break
        }
        "python" {
            writeToConsole "`n`t`tInstalling Python 3..." -log
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command choco install python311 -y  --force | Out-File $LogPath -Append -Encoding UTF8"
            Break
        }
        "compiler" {
            writeToConsole "`n`t`tInstalling C++ Build Tools, This might take a while.." -log
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command choco install visualstudio2019buildtools visualstudio2019-workload-vctools --passive -y --force | Out-File $LogPath -Append -Encoding UTF8"
            Break
        }
        "chocolatey" {
            writeToConsole "`n`t`tInstalling chocolatey..." -log

            # Choco requires admin rights to install properly
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command

            Set-ExecutionPolicy Bypass -Scope Process -Force;
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
            Invoke-Expression (
                (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) | Out-File $LogPath -Append -Encoding UTF8;"

            Break
        }
        "uninstall" {
            writeToConsole "`n`t`tUninstalling choco packages..." -log

            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command
            choco uninstall git git.install cmake cmake.install python311 visualstudio2019buildtools visualstudio2019-workload-vctools --confirm | Out-File $LogPath -Append -Encoding UTF8"
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
        logToFile $_.Exception

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
        if (fileExists -Path $PSScriptRoot -FileName '__cmake_systeminformation') {
            Remove-Item '__cmake_systeminformation' -Recurse
        }

        if ($output) {
            logToFile $output
        }

        logToFile $_.Exception

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
        "compiler" {
            return checkForBuildTools
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
    if (!(fileExists $toolsPath )) {
        mkdir $toolsPath
    }

    # Proceed with download
    $filePath = Join-Path $toolsPath $fileName
    Invoke-WebRequest -Uri $downloadURL -OutFile $filePath
}

function checkForBuildTools() {
    #Check if we already downloaded it
    if ($progsToInstall.contains("cmake")) {
        writeToConsole "`n`t`t`t> Cmake not installed, cannot check for compiler..." -log
        return $false
    }

    writeToConsole "`n`t`t`t> Checking for Compiler, this might take a sec..." -log
    if (checkForCompiler) {
        writeToConsole "`n`t`t`t> C++ compiler found" -log
        return $true
    }
}

function checkDependencies() {
    Clear-Host
    # Reset progsToInstall before checking again
    $progsToInstall.Clear()

    "`n`tChecking to ensure all prerequisites are met..."
    "`n`tVisit the links for more info on each software"

    writeToConsole ("`n`t`tChocolatey [https://chocolatey.org/] ...." + (& { if (isInstalled "chocolatey") { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("chocolatey") } })) -log

    if (![System.Convert]::ToBoolean((getConfigProperty "standalonePython"))) {
        writeToConsole ("`n`t`tPython [https://www.python.org/] ...." + (& { if (isInstalled "python") { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("python") } })) -log
    }
    else {
        installStandalonePython
        writeToConsole ("`n`t`tPython [https://www.python.org/] .... Installed [Using Standalone]") -log
    }

    writeToConsole ("`n`t`tCMake [https://cmake.org/] ...." + (& { if (isInstalled "cmake") { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("CMake") } })) -log

    writeToConsole ("`n`t`tGit [https://git-scm.com/] ...." + (& { if (isInstalled "git") { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("Git") } })) -log

    writeToConsole ("`n`t`tC++ Build Tools ...." + (& { if (checkForBuildTools) { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("compiler") } })) -log

    if (![System.Convert]::ToBoolean((getConfigProperty "bypassPrompts"))) {
        Pause
    }
}

function installStandalonePython() {
    if (!(fileExists -Path $pythonPath -FileName "python.exe")) {
        try {
            $question = "`n`tPython has not been detected on your system, do you want to download a standalone version? [y/n]"
            askAndDownload -question $question -downloadURL $python -fileName "python.zip" -bypass ([System.Convert]::ToBoolean((getConfigProperty "bypassPrompts")))

            if (fileExists $pythonZipPath) {
                #Extract to folder
                Expand-Archive -LiteralPath $pythonZipPath -DestinationPath $pythonPath

                #Clean up zip
                Remove-Item $pythonZipPath
            }

        }
        catch {
            writeToConsole "`n`tFailed to download Python, exiting!" -log
            logToFile $_.Exception
            Pause
            exit
        }
    }
}

function installMissing() {
    Clear-Host

    $chocoOnlyDep = $progsToInstall.contains("chocolatey") -and $progsToInstall.ToArray().Count -eq 1

    if ($progsToInstall.ToArray().Count -eq 0 -or $chocoOnlyDep) {
        writeToConsole "`n`t`tNothing to install, returning to menu..." -log
        Start-Sleep 5
    }
    else {
        # Install chocolatey as it's a dependency for the rest
        # Unless it's the only dependency not installed (others installed externally)
        if ($progsToInstall.contains("chocolatey") -and !$chocoOnlyDep) {
            $progsToInstall.Remove("chocolatey")
            installProg "chocolatey"
        }

        foreach ($prog in $progsToInstall) {
            installProg $prog
        }

        writeToConsole "`n`t`tRefreshing Environment" -log
        Start-Sleep 2

        # We need to refresh the env to detect new installs
        refresh

        writeToConsole "`n`t`tRe-checking dependencies" -log
        checkDependencies
    }
}

function cloneRepo() {
    Clear-Host

    # Reset path
    Set-Location $rootPath

    $commit = getLatestCommitId
    try {
        # Delete SFSE if already preset
        if (fileExists $sfsePath) {
            writeToConsole "`n`t`tSFSE already exists, removing first" -log
            Remove-Item -Force -Recurse $sfsePath
        }

        writeToConsole "`n`t`tCloning SFSE and Checking out CommitID: '$commit'" -log

        git clone https://github.com/gazzamc/sfse.git
        Set-Location "sfse"
        git checkout $commit

        # Verify sfse exist before continuing
        if (!(fileExists $sfsePath)) {
            throw "There was a problem cloning sfse repo"
        }
    }
    catch {
        # Catch exception to prevent script failure
        writeToConsole "`n`t`tFailed trying to checkout SFSE" -log
        logToFile $_.Exception
    }
}

function buildRepo() {
    Clear-Host

    try {
        # Clean build files before running, if exists
        if (fileExists $sfseBuildPath) {
            Remove-Item -Force -Recurse $sfseBuildPath
        }

        # Split build commands to reduce hanging
        runProcessAndLog $poweshellExe $rootPath "-command cmake -B '$sfseBuildPath' -S sfse"
        runProcessAndLog $poweshellExe $rootPath "-command cmake --build '$sfseBuildPath' --config Release" 60
        Clear-Host

        writeToConsole "`n`t`tBuild finished, verifying!" -log

        if (fileExists $sfseBuildPath) {
            writeToConsole "`n`t`tSuccessfully built" -log
            if (![System.Convert]::ToBoolean((getConfigProperty "bypassPrompts"))) {
                Pause
            }
        }
        else {
            writeToConsole "`n`t`tCould not verify build, check manually!" -log
            Pause
        }
    }
    catch {
        # Catch exception to prevent script failure
        writeToConsole "`n`t`tError Building SFSE, check that you have C++ dev tools installed!" -log
        logToFile -Content $_.Exception
        Pause
    }
}
function moveSFSEFiles() {
    # Reset path
    Clear-Host
    Set-Location $rootPath

    if (sfseRegistryExists) {
        $gamePath = getConfigProperty "gamePath"
    }
    else {
        $gamePath = getConfigProperty "newGamePath"
    }

    # Remove any existing sfse files before copying
    $sfseItems = Get-ChildItem -Path $gamePath | Where-Object { $_.extension -in @(".dll", ".exe") -and ( $_.Name -match 'sfse') }

    if ($sfseItems) {
        logToFile -Content "Removing Existing SFSE files before copying."
        $sfseItems | Remove-Item
    }

    writeToConsole "`n`t`tCopying SFSE Files to $gamePath..." -log

    $gameVersion = getGameVersion
    $filesToCopy = "sfse_loader.exe", "sfse_$gameVersion.dll"

    try {
        # Find files in build folder and copy to user provided path
        if (fileExists $sfseBuildPath) {
            foreach ($file in $filesToCopy) {
                Get-ChildItem -Path $sfseBuildPath -Filter $file -Recurse | Copy-Item -Destination $gamePath -Verbose *>&1 | Out-File -FilePath $LogPath -Append -Encoding UTF8
            }

            # Check files exist
            foreach ($file in $filesToCopy) {
                if (Test-Path -Path $gamePath -Filter $file) {
                    writeToConsole "`n`t`t$file Successfully Copied!" -log
                }
                else {
                    writeToConsole "`n`t`tThere was an issue copying $file!" -log
                }
            }

            Start-Sleep 5
        }
        else {
            throw
        }
    }
    catch {
        if ($_.Exception.GetType().Name -eq "RuntimeException") {
            writeToConsole "`n`t`tFiles not found, please run build before trying to copy" -log
        }
        else {
            writeToConsole "`n`t`tAn Error occured during the copying of files, check log for more details" -log
        }

        logToFile $_.Exception
        Pause
    }
}

function patchFiles() {
    Clear-Host

    # Reset path
    Set-Location $rootPath

    try {
        $fileName = getLatestFileName
        $dictFile = (Join-Path $rootPath (Join-Path 'hex_tables' $fileName))
        $pythonExe = 'python'
        $updateArgs = $patcherPath, '-m', 'update', '-p', (Join-Path $SFSEPath 'sfse'), '-d', "$dictFile"
        $patchArgs = $patcherPath, '-m', 'patch', '-p', $SFSEPath
        $verifyArgs = $patcherPath, '-m', 'md5', '-p', $SFSEPath, '--verify'

        if (([System.Convert]::ToBoolean((getConfigProperty "standalonePython")))) {
            installStandalonePython
            $pythonExe = Join-Path $pythonPath 'python.exe'
        }

        writeToConsole "`n`tPatching SFSE" -log

        # Update hex values
        & $pythonExe $updateArgs | Out-File $LogPath -Append -Encoding UTF8

        # Patch loader
        & $pythonExe $patchArgs | Out-File $LogPath -Append -Encoding UTF8

        # Verify files were patched
        $verifyPatch = & $pythonExe $verifyArgs

        # Log md5 comparison
        $verifyPatch | Out-File $LogPath -Append -Encoding UTF8

        if ($verifyPatch[-2].SubString(6, 18) -eq "All files matched!") {
            writeToConsole "`n`t`tSuccessfully Patched SFSE" -log
            if (![System.Convert]::ToBoolean((getConfigProperty "bypassPrompts"))) {
                Pause
            }
        }
        else {
            writeToConsole "`n`t`tUnsuccessfully Patched SFSE, check log to see which files failed md5 comparison" -log
            Pause
        }
    }
    catch {
        logToFile $_.Exception
    }
}

function checkSpaceReq() {
    param (
        [string]$gamePath,
        [string]$newPath
    )

    $hasSpace = $true

    $driveLetter = (Get-Item $newPath).PSDrive.Name + ":"
    $drives = Get-CimInstance -ClassName Win32_LogicalDisk | Select-Object -Property DeviceID, FreeSpace

    if ($drives.DeviceID -contains $driveLetter) {
        # Get free space of drive
        $idx = $drives.DeviceID.IndexOf($driveLetter)
        $space = ($drives[$idx].FreeSpace)

        # Get current size of game folder
        $folderSize = (Get-ChildItem -Path $gamePath -Recurse | Measure-Object -Property Length -Sum).sum

        if ($folderSize -gt $space) {
            $hasSpace = $false

            writeToConsole "
            Not enough space on drive to copy the game:

                Space Required: $([Math]::Round($folderSize / 1Gb, 2)) Gb
                Free Disk Space ($driveLetter): $([Math]::Round($space / 1Gb, 2)) Gb
            " -log
            Pause
        }
    }
    return $hasSpace
}

function checkForPStools() {
    if (!(fileExists $psExecPath)) {
        try {
            $question = "`n`tIn order to move the secured game exe we need to use PSTools, download? [y/n]"
            askAndDownload -question $question -downloadURL $pstools -fileName "pstools.zip" -bypass ([System.Convert]::ToBoolean((getConfigProperty "bypassPrompts")))

            if (fileExists $psToolsZipPath) {
                #Extract to folder
                Expand-Archive -LiteralPath $psToolsZipPath -DestinationPath $psToolsPath

                #Clean up zip
                Remove-Item $psToolsZipPath
            }

        }
        catch {
            writeToConsole "`n`tFailed to download PSTools, exiting!" -log
            logToFile $_.Exception
            Pause
            exit
        }
    }
}

function moveGameEXE() {
    $gamePath = getConfigProperty "gamePath"
    $newGamePath = getConfigProperty "newGamePath"

    # Check for permissions before copying exe
    if (!(hasPermissions $newGamePath)) {
        writeToConsole "
        `n`tStarfield.exe cannot be copied as you do not have the necessary permissions within the folder" -type -color red
        writeToConsole "`n`t$newGamePath" -type -color yellow
        writeToConsole "`n`tPlease copy the game files to a new location where you have FullControl of permissions." -type -color red
        Pause
        exit
    }

    checkForPStools

    try {
        if (fileExists -Path $newGamePath -FileName 'Starfield.exe') {
            throw [System.Exception] "`n`tStarfield.exe was not copied as it already exists in $newGamePath!";
        }

        # We can't copy directly from game folder so we need to move and copy back
        if (fileExists -Path $gamePath -FileName 'Starfield.exe') {
            writeToConsole "`n`tCopying Starfield.exe to new game folder!" -log

            # Calling powershell 7 from within psexec.exe does not seem to work, leaving it as powershell for now
            # as it's built-in to windows it should not cause issues as it's being called with system permissions anyway
            Start-Process -Wait -Verb RunAs $psExecPath "-s -i -nobanner -accepteula powershell 
            Move-Item (Join-Path '$gamePath' 'Starfield.exe') -Destination (Join-Path '$newGamePath' 'Starfield.exe')"
            Start-Sleep -Seconds 5

            # Check that permissions we're stripped from exe
            if (hasPermissions (Join-Path $newGamePath 'Starfield.exe') -checkVersionInfo) {
                writeToConsole "`n`tStarfield.exe moved successfully!" -log
            }
            else {
                throw [System.IO.Exception] "Starfield.exe permissions we're not removed, please try again or check docs for manual process"
            }
        }
        else {
            throw [System.IO.FileNotFoundException] "Starfield.exe cannot be found in game path $gamePath"
        }

        if (fileExists -Path $newGamePath -FileName 'Starfield.exe') {
            Start-Process -Wait -Verb RunAs $psExecPath "-s -i -nobanner -accepteula powershell 
            Copy-Item (Join-Path '$newGamePath' 'Starfield.exe') -Destination (Join-Path '$gamePath' 'Starfield.exe')"
            Start-Sleep -Seconds 5

            # check exe was copied back to starfield install folder
            if (fileExists -Path $gamePath -FileName 'Starfield.exe') {
                writeToConsole "`n`tCopy of Starfield.exe created in original folder!" -log
            }

            Start-Sleep -Seconds 5
        }
        else {
            throw [System.IO.FileNotFoundException] "Starfield.exe cannot be copied back to game folder as it cannot be found in $newGamePath"
        }
    }
    catch {
        if ($_.Exception.GetType().Name -eq "InvalidOperationException") {
            writeToConsole "`n`tCannot find PsExec.exe, please check that PSTools has been downloaded to the tools folder." -log
        }
        elseif ($_.Exception.GetType().Name -eq "FileNotFoundException") {
            writeToConsole "`n`tStarfield.exe cannot be found in the folder specified, check log for more information!" -log
        }
        else {
            writeToConsole "`n`tFailed to copy Starfield.exe correctly, check log for more information!" -log
            $msg = $_.Exception
            writeToConsole "`n`t > $msg"
        }

        logToFile $_.Exception.Message
        Pause
        Clear-Host
    }
}

function moveGameFiles() {
    Clear-Host
    writeToConsole "`n`tMove/Hardlink Game Files.." -log

    $choice = getConfigProperty "hardlinkOrCopy"

    if ($choice) {
        $type = $choice
    }


    # Get path of game install and new location for files
    $gamePath = getConfigProperty "gamePath"
    $newGamePath = getConfigProperty "newGamePath"

    if ($type -eq 1) {
        # Check that we have enough space if copying
        $suffSpace = checkSpaceReq $gamePath $newGamePath

        if (!$suffSpace) {
            return
        }

        writeToConsole "`n`tCopying files to new location!" -log

        # Copy over files
        ROBOCOPY $gamePath $newGamePath /E /XF (Join-Path $gamePath "Starfield.exe") /MIR /NDL /NJH /NJS |
        ForEach-Object {
            $data = $_.Split([char]9); if ("$($data[4])" -ne "") { $file = "$($data[4])" };

            if ($data[0] -eq '' -and ($file -ne '' -or $null)) {
                #  Log files to be copied
                Out-File $LogPath -InputObject "Copying File: $file" -Append -Encoding UTF8
            }

            Write-Progress "Percentage $($data[0])" -Activity "Robocopy" -CurrentOperation "$($file)" -ErrorAction SilentlyContinue;
        }

        # Clear progress bar when completed
        Write-Progress -Activity "Robocopy" -Completed

    }
    elseif ($type -eq 2) {
        writeToConsole "`n`tHardlinking files to new location!" -log

        try {
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
        catch {
            logToFile $_.Exception
        }
    }
}

function autoInstall() {
    # Check for all dependencies
    checkDependencies

    $chocoOnlyDep = $progsToInstall.contains("chocolatey") -and $progsToInstall.ToArray().Count -eq 1

    # Check if dependencies are installed otherwise redirect user back to main menu
    if ($progsToInstall.ToArray().Count -gt 0 -and !$chocoOnlyDep) {
        Clear-Host
        writeToConsole "`n`tMissing dependencies, install all dependencies before proceeding: [$progsToInstall]" -log
        Pause
        return
    }

    cloneRepo
    patchFiles
    buildRepo
    setSFSERegistry
    moveSFSEFiles

    Clear-Host
    writeToConsole "`n`tYou're ready to start using SFSE mods!"
    writeToConsole "`n`t`tCheck out the list of compatible mods here: 
    `n`t`thttps://github.com/gazzamc/starfield_hex_updater/blob/main/docs/compatibility"
    Pause
}
function setGamePath() {
    Clear-Host
    $noPathMsg = "`n`tPath inputted does not exist, please check that it exists! [q to exit]"
    $noPermissionMsg = "`n`tYou do not have the correct permissions for the path inputted, please use another! [q to exit]"
    $samePathMsg = "`n`tThe Gamepath and NewGamePath cannot be the same! [q to exit]"

    $continue = $true;
    $inputMsg = "`n`tNewGamePath"

    # Get initial input
    $inputtedPath = Read-Host $inputMsg;
    $inputtedPathTrimmed = $inputtedPath.trim()

    while ($continue) {
        if (!$inputtedPathTrimmed -or !(fileExists $inputtedPathTrimmed)) {
            if ($inputtedPathTrimmed -eq 'q') { exit }
            writeToConsole $noPathMsg
        }
        elseif ((isSamePath $inputtedPathTrimmed)) {
            if ($inputtedPathTrimmed -eq 'q') { exit }
            writeToConsole $samePathMsg
        }
        # check if user has full control permissions in newgamepath
        elseif (!(hasPermissions $inputtedPathTrimmed)) {
            if ($inputtedPathTrimmed -eq 'q') { exit }
            writeToConsole $noPermissionMsg
        }
        else {
            setConfigProperty "newGamePath" $inputtedPathTrimmed
            break
        }

        # Get new inputs after message
        $inputtedPath = Read-Host $inputMsg
        $inputtedPathTrimmed = $inputtedPath.trim()
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

function setPythonChoice() {
    Clear-Host
    writeToConsole "`n`tRecommended if having issues detecting local install" -type -color yellow -bgcolor black
    writeToConsole "`n`tPython will be installed to the tools folder" -type -color yellow -bgcolor black

    $question = "
        Would you like to use a standalone python install? [y/n]"
    $confirmation = Read-Host $question
    while ($confirmation -ne "y" -and $confirmation -ne "n") {
        $confirmation = Read-Host $question
    }

    if ($confirmation -eq 'y') {
        setConfigProperty "standalonePython" $true
    }
    elseif ($confirmation -eq 'n') {
        setConfigProperty "standalonePython" $false
    }
}

function setFilesChoice() {
    Clear-Host
    $question = "(2) Hardlink (same drive as original) or (1) Copy Game files? [1/2]"
    $confirmation = Read-Host $question
    while ($confirmation -ne "1" -and $confirmation -ne "2") {
        $confirmation = Read-Host $question
    }

    if ($confirmation -eq '1') {
        setConfigProperty "hardlinkOrCopy" 1
    }
    elseif ($confirmation -eq '2') {
        setConfigProperty "hardlinkOrCopy" 2
    }
}

function welcomeScreen() {
    Clear-Host
    $title = (Get-Content -Raw "header.txt").Replace('x.x.x', $version).Replace('[at]', '@')

    writeToConsole $title
    writeToConsole "`n`tIn order to make the auto-install process as smooth as possible we'll set some options now, `n`tthis can be changed from the options menu." -type -color yellow -bgcolor black
    writeToConsole "`n`tOnce these are set, you won't see this screen again on start-up." -type -color yellow -bgcolor black

    writeToConsole "`n`tCopying the game files, executable to bypass permissions is no longer required to launch SFSE as of v1.6.0," -type -color yellow -bgcolor black
    writeToConsole "`tAs is setting the game install path manually, this will be automatically set for you." -type -color yellow -bgcolor black

    writeToConsole "`n`tSFSE will be enabled by default when using the 'auto' option," -type -color yellow -bgcolor black
    writeToConsole "`tthis will allow you to launch SFSE via the winstore shortcut directly." -type -color yellow -bgcolor black

    writeToConsole "`n`tYou can enable/disable this option via the options menu, when you want to play vanilla." -type -color green -bgcolor black
    writeToConsole "`n"

    Pause
    setPythonChoice
    setBypassChoice
}


#  Prevent errors from being suppressed
if (![System.Convert]::ToBoolean((getConfigProperty "debug"))) {
    $ErrorActionPreference = "Stop"
}

# Display start message/ set path if missing/invalid
$pathsExistAndValid = $True

if (!(testPath (getConfigPath))) {
    $pathsExistAndValid = $False
}
else {
    $gamePathConfig = getConfigProperty "gamePath"
    $gamePathReg = getStarfieldPath

    if ($gamePathReg -ne $gamePathConfig) {
        setSFSEPath
    }
}

if (!$pathsExistAndValid) {
    welcomeScreen
    setSFSEPath
}
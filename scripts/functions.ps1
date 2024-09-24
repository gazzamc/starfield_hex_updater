. .\utils.ps1

# A PS script to patch/install Gamepass SFSE in one click

#URLs for tools needed
$pstools = "https://download.sysinternals.com/files/PSTools.zip"
$python = "https://www.python.org/ftp/python/3.11.8/python-3.11.8-embed-amd64.zip"

$progsToInstall = New-Object System.Collections.Generic.List[System.Object]
$dateNow = $((Get-Date).ToString('yyyy.MM.dd_hh.mm.ss'))
$logfileName = "logfile_$dateNow.log"
$powershellVersion = $host.Version.Major
$version = "1.5.19"

# Paths
$logFolderPath = Join-Path $rootPath 'logs'
$LogPath = Join-Path $logFolderPath $logfileName
$sfsePath = Join-Path $rootPath 'sfse'
$sfseBuildPath = (Join-Path $sfsePath 'build')
$toolsPath = (Join-Path $rootPath 'tools')
$pythonPath = (Join-Path $toolsPath 'python')
$pythonZipPath = (Join-Path $toolsPath 'python.zip')
$psToolsPath = Join-Path $toolsPath 'pstools'
$psToolsZipPath = Join-Path $toolsPath 'pstools.zip'
$psExecPath = (Join-Path $psToolsPath 'psexec.exe')


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
            writeToConsole "`n`t`tInstalling Git..." -logPath $LogPath
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command choco install git -y --force | Out-File $LogPath -Append -Encoding UTF8"
            Break
        }
        "cmake" {
            writeToConsole "`n`t`tInstalling CMake..." -logPath $LogPath
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command choco install cmake --installargs 'ADD_CMAKE_TO_PATH=System' -y --force | Out-File $LogPath -Append -Encoding UTF8"
            Break
        }
        "python" {
            writeToConsole "`n`t`tInstalling Python 3..." -logPath $LogPath
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command choco install python311 -y  --force | Out-File $LogPath -Append -Encoding UTF8"
            Break
        }
        "compiler" {
            writeToConsole "`n`t`tInstalling C++ Build Tools, This might take a while.." -logPath $LogPath
            Start-Process -Wait -WindowStyle Hidden -Verb RunAs $poweshellExe -ArgumentList "-command choco install visualstudio2019buildtools visualstudio2019-workload-vctools --passive -y --force | Out-File $LogPath -Append -Encoding UTF8"
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
        "uninstall" {
            writeToConsole "`n`t`tUninstalling choco packages..." -logPath $LogPath

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
        writeToConsole "`n`t`t`t> Cmake not installed, cannot check for compiler..." -logPath $LogPath
        return $false
    }

    writeToConsole "`n`t`t`t> Checking for Compiler, this might take a sec..." -logPath $LogPath
    if (checkForCompiler) {
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

    if (![System.Convert]::ToBoolean((getConfigProperty "standalonePython"))) {
        writeToConsole ("`n`t`tPython [https://www.python.org/] ...." + (& { if (isInstalled "python") { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("python") } })) -logPath $LogPath
    }
    else {
        installStandalonePython
        writeToConsole ("`n`t`tPython [https://www.python.org/] .... Installed [Using Standalone]") -logPath $LogPath
    }

    writeToConsole ("`n`t`tCMake [https://cmake.org/] ...." + (& { if (isInstalled "cmake") { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("CMake") } })) -logPath $LogPath

    writeToConsole ("`n`t`tGit [https://git-scm.com/] ...." + (& { if (isInstalled "git") { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("Git") } })) -logPath $LogPath

    writeToConsole ("`n`t`tC++ Build Tools ...." + (& { if (checkForBuildTools) { "`tInstalled" } else { "`tNot Found"; $progsToInstall.Add("compiler") } })) -logPath $LogPath

    if (![System.Convert]::ToBoolean((getConfigProperty "bypassPrompts"))) {
        Pause
    }
}

function installStandalonePython() {
    if (!(fileExists (Join-Path $pythonPath "python.exe"))) {
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
            writeToConsole "`n`tFailed to download Python, exiting!" -logPath $LogPath
            logToFile $_.Exception $LogPath
            Pause
            exit
        }
    }
}

function installMissing() {
    Clear-Host

    $chocoOnlyDep = $progsToInstall.contains("chocolatey") -and $progsToInstall.ToArray().Count -eq 1

    if ($progsToInstall.ToArray().Count -eq 0 -or $chocoOnlyDep) {
        writeToConsole "`n`t`tNothing to install, returning to menu..." -logPath $LogPath
        Start-Sleep 5
    }
    else {
        # Install chocolatey as it's a dependency for the rest
        # Unless it's the only dependency not installed (others installed externally)
        if ($progsToInstall.contains("chocolatey") -and !$chocoOnlyDep) {
            $progsToInstall.Remove("chocolatey")
            installProg "chocolatey"

            # Import choco for refreshenv command
            $env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."
            Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
        }

        foreach ($prog in $progsToInstall) {
            installProg $prog
        }

        writeToConsole "`n`t`tRefreshing Environment" -logPath $LogPath
        Start-Sleep 2

        # We need to refresh the env to detect new installs
        refreshenv

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
        # Delete SFSE if already preset
        if (fileExists $sfsePath) {
            writeToConsole "`n`t`tSFSE already exists, removing first" -logPath $LogPath
            Remove-Item -Force -Recurse $sfsePath
        }

        writeToConsole "`n`t`tCloning SFSE and Checking out CommitID!" -logPath $LogPath

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
        writeToConsole "`n`t`tFailed trying to checkout SFSE" -logPath $LogPath
        logToFile $_.Exception $LogPath
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

        writeToConsole "`n`t`tBuild finished, verifying!" -logPath $LogPath

        if (fileExists $sfseBuildPath) {
            writeToConsole "`n`t`tSuccessfully built" -logPath $LogPath
            if (![System.Convert]::ToBoolean((getConfigProperty "bypassPrompts"))) {
                Pause
            }
        }
        else {
            writeToConsole "`n`t`tCould not verify build, check manually!" -logPath $LogPath
            Pause
        }
    }
    catch {
        # Catch exception to prevent script failure
        writeToConsole "`n`t`tError Building SFSE, check that you have C++ dev tools installed!" -logPath $LogPath
        logToFile $_.Exception $LogPath
        Pause
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
        if (fileExists $sfseBuildPath) {
            foreach ($file in $filesToCopy) {
                Get-ChildItem -Path $sfseBuildPath -Filter $file -Recurse | Copy-Item -Destination $gamePath -Verbose *>&1 | Out-File -FilePath $LogPath -Append -Encoding UTF8
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
        else {
            throw
        }
    }
    catch {
        if ($_.Exception.GetType().Name -eq "RuntimeException") {
            writeToConsole "`n`t`tFiles not found, please run build before trying to copy" -logPath $LogPath
        }
        else {
            writeToConsole "`n`t`tAn Error occured during the copying of files, check log for more details" -logPath $LogPath
        }

        logToFile $_.Exception $LogPath
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
        $updateArgs = 'hex_updater.py', '-m', 'update', '-p', (Join-Path $SFSEPath 'sfse'), '-d', "$dictFile"
        $patchArgs = 'hex_updater.py', '-m', 'patch', '-p', $SFSEPath
        $verifyArgs = 'hex_updater.py', '-m', 'md5', '-p', $SFSEPath, '--verify'

        if (([System.Convert]::ToBoolean((getConfigProperty "standalonePython")))) {
            installStandalonePython
            $pythonExe = Join-Path $pythonPath 'python.exe'
        }

        writeToConsole "`n`tPatching SFSE" -logPath $LogPath

        # Update hex values
        & $pythonExe $updateArgs | Out-File $LogPath -Append -Encoding UTF8

        # Patch loader
        & $pythonExe $patchArgs | Out-File $LogPath -Append -Encoding UTF8

        # Verify files were patched
        $verifyPatch = & $pythonExe $verifyArgs

        # Log md5 comparison
        $verifyPatch | Out-File $LogPath -Append -Encoding UTF8

        if ($verifyPatch[-2].SubString(6, 18) -eq "All files matched!") {
            writeToConsole "`n`t`tSuccessfully Patched SFSE" -logPath $LogPath
            if (![System.Convert]::ToBoolean((getConfigProperty "bypassPrompts"))) {
                Pause
            }
        }
        else {
            writeToConsole "`n`t`tUnsuccessfully Patched SFSE, check log to see which files failed md5 comparison" -logPath $LogPath
            Pause
        }
    }
    catch {
        logToFile $_.Exception $LogPath
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
            " -logPath $LogPath
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
            writeToConsole "`n`tFailed to download PSTools, exiting!" -logPath $LogPath
            logToFile $_.Exception $LogPath
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
        if (fileExists $newGamePath 'Starfield.exe') {
            throw [System.Exception] "`n`tStarfield.exe was not copied as it already exists in $newGamePath!";
        }

        # We can't copy directly from game folder so we need to move and copy back
        if (fileExists $gamePath 'Starfield.exe') {
            writeToConsole "`n`tCopying Starfield.exe to new game folder!" -logPath $LogPath

            # Calling powershell 7 from within psexec.exe does not seem to work, leaving it as powershell for now
            # as it's built-in to windows it should not cause issues as it's being called with system permissions anyway
            Start-Process -Wait -Verb RunAs $psExecPath "-s -i -nobanner -accepteula powershell 
            Move-Item (Join-Path '$gamePath' 'Starfield.exe') -Destination (Join-Path '$newGamePath' 'Starfield.exe')"
            Start-Sleep -Seconds 5

            # Check that permissions we're stripped from exe
            if (hasPermissions (Join-Path $newGamePath 'Starfield.exe') -checkVersionInfo) {
                writeToConsole "`n`tStarfield.exe moved successfully!" -logPath $LogPath
            }
            else {
                throw [System.IO.Exception] "Starfield.exe permissions we're not removed, please try again or check docs for manual process"
            }
        }
        else {
            throw [System.IO.FileNotFoundException] "Starfield.exe cannot be found in game path $gamePath"
        }

        if (fileExists $newGamePath 'Starfield.exe') {
            Start-Process -Wait -Verb RunAs $psExecPath "-s -i -nobanner -accepteula powershell 
            Copy-Item (Join-Path '$newGamePath' 'Starfield.exe') -Destination (Join-Path '$gamePath' 'Starfield.exe')"
            Start-Sleep -Seconds 5
            
            # check exe was copied back to starfield install folder
            if (fileExists $gamePath 'Starfield.exe') {
                writeToConsole "`n`tCopy of Starfield.exe created in original folder!" -logPath $LogPath
            }

            Start-Sleep -Seconds 5
        }
        else {
            throw [System.IO.FileNotFoundException] "Starfield.exe cannot be copied back to game folder as it cannot be found in $newGamePath"
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
            writeToConsole "`n`tFailed to copy Starfield.exe correctly, check log for more information!" -logPath $LogPath
            $msg = $_.Exception
            writeToConsole "`n`t > $msg"
        }

        logToFile $_.Exception.Message $LogPath
        Pause
        Clear-Host
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



    Clear-Host

    # Get path of game install and new location for files
    $gamePath = getConfigProperty "gamePath"
    $newGamePath = getConfigProperty "newGamePath"

    if ($type -eq 1) {
        # Check that we have enough space if copying
        $suffSpace = checkSpaceReq $gamePath $newGamePath

        if (!$suffSpace) {
            return
        }

        writeToConsole "`n`tCopying files to new location!" -logPath $LogPath

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
        writeToConsole "`n`tHardlinking files to new location!" -logPath $LogPath

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
            logToFile $_.Exception $LogPath
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
        writeToConsole "`n`tMissing dependencies, install all dependencies before proceeding: [$progsToInstall]" -logPath $LogPath
        Pause
        return
    }

    cloneRepo
    patchFiles
    buildRepo
    moveGameFiles
    moveSFSEFiles
    moveGameEXE

    Clear-Host
    writeToConsole "`n`tYou're ready to start using SFSE mods!"
    writeToConsole "`n`t`tCheck out the list of compatible mods here: 
    `n`t`thttps://github.com/gazzamc/starfield_hex_updater/blob/main/docs/compatibility"
    Pause
}
function setGamePaths() {
    Clear-Host
    $pathNames = "`n`tGamePath", "`n`tNewGamePath"
    $noPathMsg = "`n`tPath inputted does not exist, please check that it exists! [q to exit]"
    $noPermissionMsg = "`n`tYou do not have the correct permissions for the path inputted, please use another! [q to exit]"
    $samePathMsg = "`n`tThe Gamepath and NewGamePath cannot be the same! [q to exit]"

    function isSamePath() {
        param (
            [string]$path
        )

        $gamePath = (getConfigProperty "gamePath")

        if ($path -eq $gamePath) {
            return $true
        }

        if ((Join-Path $path "Content") -eq $gamePath) {
            return $true
        }

        return $false
    }

    foreach ($pathName in $pathNames) {
        $continue = $true;

        # Get initial input
        $inputtedPath = Read-Host $pathName;
        $inputtedPathTrimmed = $inputtedPath.trim()

        while ($continue) {
            if (!$inputtedPathTrimmed -or !(fileExists $inputtedPathTrimmed)) {
                if ($inputtedPathTrimmed -eq 'q') { exit }
                writeToConsole $noPathMsg
            }
            elseif ($pathName -eq $pathNames[1] -and (isSamePath $inputtedPathTrimmed)) {
                if ($inputtedPathTrimmed -eq 'q') { exit }
                writeToConsole $samePathMsg
            }
            # check if user has full control permissions in newgamepath
            elseif ($pathName -eq $pathNames[1] -and !(hasPermissions $inputtedPathTrimmed)) {
                if ($inputtedPathTrimmed -eq 'q') { exit }
                writeToConsole $noPermissionMsg
            }
            else {
                if ($pathName -eq $pathNames[0]) {
                    # Add a check for the content folder, add it if not present
                    $splitPath = $inputtedPathTrimmed.split('\')

                    if ($splitPath[$splitPath.Length - 1].ToLower() -ne "content") {
                        $inputtedPath = Join-Path $inputtedPathTrimmed "Content"
                    }

                    setConfigProperty "gamePath" $inputtedPath
                }
                else {
                    setConfigProperty "newGamePath" $inputtedPathTrimmed
                }

                break
            }

            # Get new inputs after message
            $inputtedPath = Read-Host $pathName
            $inputtedPathTrimmed = $inputtedPath.trim()
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

    Pause
    setGamePaths
    setPythonChoice
    setBypassChoice
}


#  Prevent errors from being suppressed
if (![System.Convert]::ToBoolean((getConfigProperty "debug"))) {
    $ErrorActionPreference = "Stop"
}

# Display start message/ set paths if missing
if (!(testPath (getConfigProperty "gamePath")) -and !(testPath (getConfigProperty "newGamePath"))) { 
    welcomeScreen
}
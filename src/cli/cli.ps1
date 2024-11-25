Import-Module (Join-Path $PSScriptRoot functions.ps1)

$sfseEnabledMsg = "
`n`tDisable 'SFSE Enabled' option (7) in the options menu to manually move files, 
`n`tby default SFSE files will be moved to original game install folder 
`n`tand will be enabled when starting via xbox app or shortcut."

function promptUserPathNotExist() {
    if (!(sfseRegistryExists)) {
        $newGamePath = getConfigProperty "newGamePath"
        if (!($newGamePath)) {
            setGamePath
        }
    }
}

Do {
    switch ($mainMenuOption) {
        1 {
            Clear-Host
            autoInstall
            break
        }
        2 {
            Clear-Host
            checkDependencies
            break
        }
        3 {
            checkDependencies
            Clear-Host
            installMissing
            break
        }
        4 {
            Clear-Host
            Do {
                switch ($repoMenuOption) {
                    1 {
                        Clear-Host
                        cloneRepo
                        break
                    }
                    2 {
                        Clear-Host
                        patchFiles
                        break
                    }
                    3 {
                        Clear-Host
                        buildRepo
                        break
                    }
                    4 {
                        Clear-Host
                        promptUserPathNotExist
                        moveSFSEFiles
                        break
                    }
                    Default {
                    }
                }

                Clear-Host
                Write-Host
                "
                    1. Clone Repo
                    2. Patch Files
                    3. Build
                    4. Move files to game folder
                    q. Return
                "
                $repoMenuOption = Read-Host "Choose an option"
            }
            while ($repoMenuOption -ne "q")
            break
        }
        5 {
            Clear-Host

            if (sfseRegistryExists) {
                writeToConsole $sfseEnabledMsg -type -color yellow
                Pause
                break
            }

            Write-Host
            "
            `n`t`tCopy Files - Additional space required.
            `n`t`tHardlink - Saves space, but can only be used on same drive as the game install.
            "

            Do {
                switch ($moveGameFilesOption) {
                    1 {
                        Clear-Host
                        $choice = getConfigProperty "hardlinkOrCopy"

                        if (!$choice) {
                            setFilesChoice
                        }

                        promptUserPathNotExist
                        moveGameFiles
                        break
                    }
                    2 {
                        Clear-Host
                        promptUserPathNotExist
                        moveGameEXE
                        break
                    }
                    Default {
                    }
                }

                Clear-Host
                Write-Host
                "
                    1. Copy/Hardlink Game Files
                    2. Copy Game EXE Only
                    q. Return
                "
                $moveGameFilesOption = Read-Host "Choose an option"
            }
            while ($moveGameFilesOption -ne "q")
            break
        }
        6 {
            Do {
                switch ($setConfigOption) {
                    1 {
                        Clear-Host
                        setGamePath
                        break
                    }
                    2 {
                        Clear-Host
                        setBypassChoice
                        break
                    }
                    3 {
                        Clear-Host
                        setPythonChoice
                        break
                    }
                    4 {
                        Clear-Host
                        setFilesChoice
                        break
                    }
                    5 {
                        Clear-Host
                        installProg "Uninstall"
                        break
                    }
                    6 {
                        Clear-Host
                        refresh
                        break
                    }
                    7 {
                        Clear-Host
                        if (sfseRegistryExists) {
                            removeSFSERegistry
                        }
                        else {
                            setSFSERegistry
                        }
                        break
                    }
                    Default {
                    }
                }

                # Display current config set
                Clear-Host
                Write-Host "`n`t Config"
                Write-Host "`t---------"
                Write-Host "`tSFSE Enabled: $(sfseRegistryExists)"
                Write-Host "`t"
                Write-Host "`tGame Path: $(getConfigProperty "gamePath")"
                Write-Host "`t"
                Write-Host "`tCopied/Hardlinked Path: $(getConfigProperty "newGamePath" )"
                Write-Host "`t"
                Write-Host "`t[Copy = 1, Hardlink = 2] : $(getConfigProperty "hardlinkOrCopy" )"
                Write-Host "`t"
                Write-Host "`tBypass Prompts: $(getConfigProperty "bypassPrompts" )"
                Write-Host "`t"
                Write-Host "`tStandalone Python: $(getConfigProperty "standalonePython" )"
                Write-Host "`t"

                Write-Host
                "
                    1. Set Paths
                    2. Set Bypass Choice
                    3. Set Python Choice
                    4. Set Game Transfer Choice
                    
                    5. Uninstall Dependencies (Choco Packages only)
                    6. Refresh Environment (If Choco Packages are not detected)
                    
                    7. $(if (-Not (sfseRegistryExists)) {"Enable SFSE"} else {"Disable SFSE"})
                    q. Return
                "
                $setConfigOption = Read-Host "Choose an option"
            }
            while ($setConfigOption -ne "q")
            break
        }
        Default {
        }
    }


    Clear-Host
    Write-Host
    "
        1. Auto
        2. Check Installed Dependencies
        3. Install Dependencies
        4. SFSE
        5. Copy/Hardlink Game Files
        6. Options
        q. Quit
    "

    $mainMenuOption = Read-Host "Choose an option"
}
while ($mainMenuOption -ne "q")
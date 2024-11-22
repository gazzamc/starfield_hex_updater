Import-Module (Join-Path $PSScriptRoot functions.ps1)

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
            Write-Host
            "
            Due to security permissions SFSE cannot be injected into the Starfield.exe
            from within it's original installation folder, to bypass this issue
            we need to link/copy the game files to a place that gives the user full control.

            `n`t`tCopy Files - Additional space required, but will not break when the game updates (Time limited).
            `n`t`tHardlink - Saves space, but certain files will be modified when the game updates.
            "

            Do {
                switch ($moveGameFilesOption) {
                    1 {
                        Clear-Host

                        $choice = getConfigProperty "hardlinkOrCopy"
                        $newGamePath = getConfigProperty "newGamePath"

                        if (!$choice -and !$newGamePath) {
                            setFilesChoice
                            setGamePath
                        }
                        elseif (!$choice) {
                            setFilesChoice
                        }
                        elseif (!$newGamePath) {
                            setGamePath
                        }

                        moveGameFiles
                        break
                    }
                    2 {
                        Clear-Host
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
                Write-Host "`tRegistry Bypass: $(sfseRegistryExists)"
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
                    7. $(if (-Not (sfseRegistryExists)) {"Add Registry Bypass"} else {"Remove Registry Bypass"})
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
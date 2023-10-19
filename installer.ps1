. .\functions.ps1

Do{
    switch ($mainOption) {
        1 { 
            Clear-Host
            autoInstall
            break
        }
        2 { 
            Clear-Host
            preFlightCheck
            break
        }
        3 { 
            preFlightCheck
            Clear-Host
            installMissing
            break
        }
        4 { 
            Clear-Host
            Do{
                switch ($subOption) {
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
            
                Write-Host 
                
                "
                    1. Clone Repo
                    2. Patch Files
                    3. Build
                    4. Move files to game folder
                    q. Return
                "
            
                $subOption = Read-Host "Choose an option"
            }
            while ($subOption -ne "q")
            break
        }
        5 { 
            Clear-Host
            Write-Host 
                
            "
                Due to security permissions SFSE cannot be injected into the Starfield.exe from within it's original installation folder, 
                to bypass this issue we need to link/copy the game files to a place that gives the user full control.

                Copy Files - Additional space required, but will not break when the game updates.
                Hardlink - Saves space, but certain files will be modified when the game updates.
            "

            moveGameFiles
            break
        }
        6 { 
            Clear-Host
            Do{
                switch ($subOption2) {
                    1 { 
                        Clear-Host
                        Get-ExecutionPolicy
                        break
                    }
                    2 { 
                        Clear-Host
                        Set-ExecutionPolicy Unrestricted
                        break
                    }
                    3 { 
                        Clear-Host
                        Set-ExecutionPolicy Restricted
                        break
                    }
                    Default {
                    }
                }
            
                Write-Host 
                
                "
                    If you're having difficulties running the script,
                    You can set the execution policy below.

                    1. Check Execution Policy
                    2. Set Execution Policy to Unrestricted
                    3. Set Execution Policy to Restricted
                    q. Return
                "
            
                $subOption2 = Read-Host "Choose an option"
            }
            while ($subOption2 -ne "q")
            break
        }
        Default {
        }
    }

    Clear-Host
    Write-Host 
    
    "
        1. Auto Install
        2. Check Installed Dependencies
        3. Install Dependencies
        4. SFSE
        5. Copy/Hardlink Game Folder
        6. Options
        q. Quit
    "

    $mainOption = Read-Host "Choose an option"
}
while ($mainOption -ne "q")
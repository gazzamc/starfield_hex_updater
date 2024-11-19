Describe "Utils" {
    BeforeAll {
        $modulePath = (Join-Path $PSScriptRoot utils.psm1)
        Import-Module -Name $modulePath
    }

    Describe "testPath" {

            BeforeAll {
                $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
                
                Mock -ModuleName utils Join-Path { return '/fake/' }
                Mock -ModuleName utils Test-Path { return $true }
            }        

            It "should have a testPath function" {
                $moduleFunctions | Should -Contain 'testPath'
            }

            Context "parameters" {
                It "should have a parameter named path" {
                    Get-Command testPath | Should -HaveParameter path -Type String
                    Get-Command testPath | Should -HaveParameter path -Mandatory:$false
                }
            }

            Context "functionality" {
                It "should call Test-Path" {
                    testPath 'path/fake' |

                    Should -Be $true
                    Should -Invoke Test-Path -ModuleName utils -Times 1
                }
            }
        }



        Describe "fileExists" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys

            Mock -ModuleName utils Join-Path { return '/fake/' }
            Mock -ModuleName utils Test-Path { return $true }
        }

        It "should have a fileExists function" {
            $moduleFunctions | Should -Contain 'fileExists'
        }

        Context "parameters" {
            It "should have a mandatory parameter named path" {
                Get-Command fileExists | Should -HaveParameter path -Type String
                Get-Command fileExists | Should -HaveParameter path -Mandatory:$true
            }
            It "should have an optional parameter named fileName" {
                Get-Command fileExists | Should -HaveParameter fileName -Type String
                Get-Command fileExists | Should -HaveParameter fileName -Mandatory:$false
            }
        }

        Context "functionality" {
            It "should call Test-Path" {
                fileExists -Path 'path/fake' |

                Should -Be $true
                Should -Invoke Test-Path -ModuleName utils -Times 1
            }

            It "should call Join-Path if fileName provided" {
                fileExists -Path 'path/fake' -FileName 'test'
                Should -Invoke Join-Path -ModuleName utils -Times 1
            }
        }
    }

    Describe "writeToConsole" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
            Mock -ModuleName utils logToFile -MockWith {}
            Mock -ModuleName utils Write-Information {}
            Mock -ModuleName utils Write-Host {}
        }

        It "should have a writeToConsole function" {
            $moduleFunctions | Should -Contain 'writeToConsole'
        }

        Context "parameters" {
            It "should have an optional parameter named msg" {
                Get-Command writeToConsole | Should -HaveParameter msg -Type String
                Get-Command writeToConsole | Should -HaveParameter msg -Mandatory:$true
            }
            It "should have an optional parameter named type" {
                Get-Command writeToConsole | Should -HaveParameter type -Type switch
                Get-Command writeToConsole | Should -HaveParameter type -Mandatory:$false
            }

            It "should have an optional parameter named color" {
                Get-Command writeToConsole | Should -HaveParameter color -Type String
                Get-Command writeToConsole | Should -HaveParameter color -Mandatory:$false
            }

            It "should have an optional parameter named bgcolor" {
                Get-Command writeToConsole | Should -HaveParameter bgcolor -Type String
                Get-Command writeToConsole | Should -HaveParameter bgcolor -Mandatory:$false
            }
            It "should have an optional parameter named log" {
                Get-Command writeToConsole | Should -HaveParameter log -Type switch
                Get-Command writeToConsole | Should -HaveParameter log -Mandatory:$false
            }
        }

        Context "functionality" {
            It "should call Write-Information when passing only msg" {
                writeToConsole -msg "test"
                Should -Invoke Write-Information -ModuleName utils -Times 1
            }

            It "should call Write-Information & logToFile when passing msg and log param" {
                #Add global variable for logpath
                $global:LogPath = '/path/'

                writeToConsole -msg "test" -log
                Should -Invoke Write-Information -ModuleName utils -Times 1
                Should -Invoke logToFile -ModuleName utils -Times 1

                # Remove global variable
                Remove-Variable -Name LogPath -Scope Global
            }
        }
    }

    Describe "getLatestFileName" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys

            $unsortedArrayOfHexTables =
            'hex_table_1.7.29_d4e7645.json',
            'hex_table_1.12.30_dd60417.json',
            'hex_table_1.9.51_4cde620.json',
            'hex_table_1.13.61_2f1f1ce.json'

            Mock -ModuleName utils -CommandName 'Get-ChildItem' -MockWith {
                return $unsortedArrayOfHexTables | ForEach-Object { @{ Name = $_ } }
            }

            Mock -ModuleName utils -CommandName 'getFullPath' -MockWith {}
        }

        It "should have a getLatestFileName function" {
            $moduleFunctions | Should -Contain 'getLatestFileName'
        }

        Context "functionality" {
            It "should return the latest file name" {
                getLatestFileName |

                Should -eq 'hex_table_1.13.61_2f1f1ce.json'
                Should -Invoke Get-ChildItem -ModuleName utils -Times 1
            }
        }
    }

    Describe "getLatestCommitId" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
            Mock -ModuleName utils -CommandName 'getLatestFileName' -MockWith { return 'hex_table_1.13.61_2f1f1ce.json' }
        }

        It "should have a getLatestCommitId function" {
            $moduleFunctions | Should -Contain 'getLatestCommitId'
        }

        Context "functionality" {
            It "should return the latest commit id" {
                getLatestCommitId |

                Should -eq '2f1f1ce'
                Should -Invoke getLatestFileName -ModuleName utils -Times 1
            }
        }
    }

    Describe "getGameVersion" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
            Mock -ModuleName utils -CommandName 'getLatestFileName' -MockWith { return 'hex_table_1.13.61_2f1f1ce.json' }
        }

        It "should have a getGameVersion function" {
            $moduleFunctions | Should -Contain 'getGameVersion'
        }

        Context "functionality" {
            It "should return the latest game version and replace the delimiter" {
                getGameVersion |

                Should -eq '1_13_61'
                Should -Invoke getLatestFileName -ModuleName utils -Times 1
            }
        }
    }

    Describe "getConfigProperty" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
            $configJson = '{ "gamePath":  "C:\\XboxGames\\Starfield\\Content" }'

            Mock -ModuleName utils -CommandName 'Get-Content' -MockWith { return $configJson }
            Mock -ModuleName utils Out-File {}
        }

        It "should have a getConfigProperty function" {
            $moduleFunctions | Should -Contain 'getConfigProperty'
        }

        Context "functionality" {
            It "should return the property value if present in the config file" {
                getConfigProperty "gamePath" |

                Should -eq "C:\XboxGames\Starfield\Content"
                Should -Invoke Get-Content -ModuleName utils -Times 1
            }

        It "should return $false if the property does not exist" {
            getConfigProperty "debug" |

            Should -BeFalse
            Should -Invoke Get-Content -ModuleName utils -Times 1
        }

            It "should write to log if the config file does not exist" {
                #Add global variable for logpath
                $global:LogPath = '/path/'

                Mock -ModuleName utils -CommandName 'fileExists' -MockWith { return $False }
                Mock -ModuleName utils -CommandName 'logToFile'

                getConfigProperty "gamePath" |

                Should -BeNullOrEmpty
                Should -Invoke Get-Content -ModuleName utils -Times 0
                Should -Invoke fileExists -ModuleName utils -Times 1
                Should -Invoke logToFile -ModuleName utils -Times 1

                # Remove global variable
                Remove-Variable -Name LogPath -Scope Global
            }
        }
    }


    Describe "setConfigProperty" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
            $configJson = '{ "gamePath":  "C:\\XboxGames\\Starfield\\Content" }'

            Mock -ModuleName utils -CommandName 'Get-Content' -MockWith { return $configJson }
            Mock -ModuleName utils -CommandName 'ConvertFrom-Json' -MockWith { return @{ "gamePath" = "C:\\XboxGames\\Starfield\\Content" } }
            Mock -ModuleName utils -CommandName 'ConvertTo-Json' -MockWith { return $configJson }
            Mock -ModuleName utils -CommandName 'Add-Member'

            Mock -ModuleName utils Out-File {}
        }

        It "should have a setConfigProperty function" {
            $moduleFunctions | Should -Contain 'setConfigProperty'
        }

        Context "functionality" {
            It "should create a new config file, if it doesn't already exist and store the given prop/val" {
                Mock -ModuleName utils -CommandName 'fileExists' -MockWith { return $False }

                setConfigProperty "key" "val" |

                Should -Invoke Get-Content -ModuleName utils -Times 0
                Should -Invoke ConvertTo-Json -ModuleName utils -Times 1
                Should -Invoke Out-File -ModuleName utils -Times 1
            }

            It "should extend the config file if it exists and key/val does not" {
                Mock -ModuleName utils -CommandName 'fileExists' -MockWith { return $True }

                setConfigProperty "key" "val" |

                Should -Invoke Get-Content -ModuleName utils -Times 1
                Should -Invoke ConvertTo-Json -ModuleName utils -Times 1
                Should -Invoke ConvertFrom-Json -ModuleName utils -Times 1
                Should -Invoke Out-File -ModuleName utils -Times 1
                Should -Invoke Add-Member -ModuleName utils -Times 1
            }

            It "should replace the value of the property if it already exists in the config" {
                Mock -ModuleName utils -CommandName 'fileExists' -MockWith { return $True }

                setConfigProperty "gamePath" "C:\\XboxGames\\Starfield\\Content" |

                Should -Invoke Get-Content -ModuleName utils -Times 1
                Should -Invoke ConvertTo-Json -ModuleName utils -Times 1
                Should -Invoke ConvertFrom-Json -ModuleName utils -Times 1
                Should -Invoke Out-File -ModuleName utils -Times 1
                Should -Invoke Add-Member -ModuleName utils -Times 0
            }
        }
    }

    Describe "findRegistryKeys" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
            $objArr = 'testKey1', 'testKey2'

            Mock -ModuleName utils -CommandName 'Get-ChildItem' -MockWith { return $objArr }
            Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $True }
        }

        It "should have a findRegistryKeys function" {
            $moduleFunctions | Should -Contain 'findRegistryKeys'
        }

        Context "parameters" {
            It "should have a parameter named path" {
                Get-Command findRegistryKeys | Should -HaveParameter path -Type String
                Get-Command findRegistryKeys | Should -HaveParameter path -Mandatory:$false
            }
        }

        Context "functionality" {
            It "should return the keys if they exist" {
                findRegistryKeys "fake\registry\path" |

                Should -eq 'testKey1', 'testKey2'
                Should -Invoke Get-ChildItem -ModuleName utils -Times 1
            }

            It "should return $false if there are no keys in path" {
                Mock -ModuleName utils -CommandName 'Get-ChildItem' -MockWith { return $False }
                
                findRegistryKeys "fake\registry\path" |

                Should -BeFalse
                Should -Invoke Get-ChildItem -ModuleName utils -Times 1
            }

            It "should write to log if the path does not exist" {
                #Add global variable for logpath
                $global:LogPath = '/path/'

                Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $False }
                Mock -ModuleName utils -CommandName 'logToFile'

                findRegistryKeys "fake\registry\path" |

                Should -BeFalse
                Should -Invoke Get-ChildItem -ModuleName utils -Times 0
                Should -Invoke Test-Path -ModuleName utils -Times 1
                Should -Invoke logToFile -ModuleName utils -Times 1

                # Remove global variable
                Remove-Variable -name LogPath -Scope Global
            }
        }
    }

    Describe "findRegistryValues" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
            $obj = [PSCustomObject]@{
                key1 = "value1";
                key2 = "value2";
            }

            Mock -ModuleName utils -CommandName 'Get-ItemProperty' -MockWith { return $obj }
            Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $True }
        }

        It "should have a findRegistryValues function" {
            $moduleFunctions | Should -Contain 'findRegistryValues'
        }

        Context "parameters" {
            It "should have a mandatory parameter named path" {
                Get-Command findRegistryValues | Should -HaveParameter path -Type String
                Get-Command findRegistryValues | Should -HaveParameter path -Mandatory:$true
            }
            It "should have an optional parameter named value" {
                Get-Command findRegistryValues | Should -HaveParameter value -Type String
                Get-Command findRegistryValues | Should -HaveParameter value -Mandatory:$false
            }
        }

        Context "functionality" {
            It "should return all values of reg key" {
                $expected = @{key1 = 'value1'; key2 = 'value2' }
                $result = findRegistryValues "fake\registry\path"

                Assert-Equivalent -Actual $result -Expected $expected
                Should -Invoke Get-ItemProperty -ModuleName utils -Times 1
                Should -Invoke Test-Path -ModuleName utils -Times 1
            }

            It "should return values matching the wildcard" {
                $expected = @{key2 = 'value2' }
                $result = findRegistryValues "fake\registry\path" "key2"
                
                Assert-Equivalent -Actual $result -Expected $expected
                Should -Invoke Get-ItemProperty -ModuleName utils -Times 1
                Should -Invoke Test-Path -ModuleName utils -Times 1
            }

            It "should return $false if there are no values" {
                Mock -ModuleName utils -CommandName 'Get-ItemProperty' -MockWith { return $False }
                
                findRegistryValues "fake\registry\path" |

                Should -BeFalse
                Should -Invoke Get-ItemProperty -ModuleName utils -Times 1
            }

            It "should write to log if the path does not exist" {
                #Add global variable for logpath
                $global:LogPath = '/path/'

                Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $False }
                Mock -ModuleName utils -CommandName 'logToFile'

                findRegistryValues "fake\registry\path" |

                Should -BeFalse
                Should -Invoke Get-ItemProperty -ModuleName utils -Times 0
                Should -Invoke Test-Path -ModuleName utils -Times 1
                Should -Invoke logToFile -ModuleName utils -Times 1

                # Remove global variable
                Remove-Variable -name LogPath -Scope Global
            }
        }
    }

    Describe "getStarfieldPackage" {
        BeforeAll {
            #Add global variable for logpath
            $global:pkgRegPath = 'fake/reg/path'
            $global:LogPath = '/path/'
                
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
            $obj = [hashtable]@{
                key1 = "value1";
            }

            Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $True }
            Mock -ModuleName utils -CommandName 'findRegistryValues' -MockWith { return $obj }
            Mock -ModuleName utils -CommandName 'logToFile'
        }

        AfterAll {
            # Remove global variable
            Remove-Variable -Name pkgRegPath -Scope Global
            Remove-Variable -Name LogPath -Scope Global
        }

        It "should have a getStarfieldPackage function" {
            $moduleFunctions | Should -Contain 'getStarfieldPackage'
        }

        Context "parameters" {
            It "should have an optional parameter named key" {
                Get-Command getStarfieldPackage | Should -HaveParameter key -Type switch
                Get-Command getStarfieldPackage | Should -HaveParameter key -Mandatory:$false
            }
        }

        Context "functionality" {
            It "should return only the key if 'key' boolean is passed" {
                getStarfieldPackage -key |
                
                Should -Be "key1"
                Should -Invoke findRegistryValues -ModuleName utils -Times 1
                Should -Invoke Test-Path -ModuleName utils -Times 1
            }

            It "should return only the value if 'key' boolean not passed" {
                getStarfieldPackage |
                
                Should -Be "value1"
                Should -Invoke findRegistryValues -ModuleName utils -Times 1
                Should -Invoke Test-Path -ModuleName utils -Times 1
            }

            It "should return $false if the package doesn't exist" {
                Mock -ModuleName utils -CommandName 'findRegistryValues' -MockWith { return $False }
                
                getStarfieldPackage |

                Should -BeFalse
                Should -Invoke findRegistryValues -ModuleName utils -Times 1
                Should -Invoke logToFile -ModuleName utils -Times 1
            }

            It "should write to log if the path does not exist" {
                Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $False }
                Mock -ModuleName utils -CommandName 'logToFile'

                getStarfieldPackage |

                Should -BeFalse
                Should -Invoke findRegistryValues -ModuleName utils -Times 0
                Should -Invoke Test-Path -ModuleName utils -Times 1
                Should -Invoke logToFile -ModuleName utils -Times 1
            }
        }
    }

    Describe "getStarfieldPath" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
            
            $obj = [hashtable]@{
                key1 = "\\?\value1";
            }

            $symObj = [PSCustomObject]@{Target = 'symlink/path' };

            Mock -ModuleName utils -CommandName 'getStarfieldPackage' -MockWith { return $True }
            Mock -ModuleName utils -CommandName 'findRegistryKeys' -MockWith { return $True }
            Mock -ModuleName utils -CommandName 'findRegistryValues' -MockWith { return $obj }
            Mock -ModuleName utils -CommandName 'findRegistryValues' -MockWith { return $obj }
            
            Mock -ModuleName utils Get-Item -MockWith { return $symObj }
            Mock -ModuleName utils Split-Path -ParameterFilter { $Path -eq $symObj.Target } -MockWith { return $symObj.Target | Split-Path }
        }

        It "should have a getStarfieldPath function" {
            $moduleFunctions | Should -Contain 'getStarfieldPath'
        }

        Context "parameters" {
            It "should have an optional parameter named symlink" {
                Get-Command getStarfieldPath | Should -HaveParameter symlink -Type switch
                Get-Command getStarfieldPath | Should -HaveParameter symlink -Mandatory:$false
            }
        }

        Context "functionality" {
            It "should return the path with the prefix removed" {
                getStarfieldPath |

                Should -Be 'value1'
                Should -Invoke getStarfieldPackage -ModuleName utils -Times 1
                Should -Invoke findRegistryKeys -ModuleName utils -Times 1
                Should -Invoke findRegistryValues -ModuleName utils -Times 1
            }

            It "should return the symlink path when pass symlink parameter" {
                getStarfieldPath -symlink |

                Should -Be 'symlink'
                Should -Invoke getStarfieldPackage -ModuleName utils -Times 1
                Should -Invoke findRegistryKeys -ModuleName utils -Times 1
                Should -Invoke findRegistryValues -ModuleName utils -Times 1
            }

            It "should return $false the path doesn't exist" {
                Mock -ModuleName utils -CommandName 'findRegistryValues' -MockWith { return $False }
                
                getStarfieldPath |

                Should -BeFalse
                Should -Invoke getStarfieldPackage -ModuleName utils -Times 1
                Should -Invoke findRegistryKeys -ModuleName utils -Times 1
                Should -Invoke findRegistryValues -ModuleName utils -Times 1
            }
        }
    }

    Describe "getRegConfigPath" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys

            Mock -ModuleName utils -CommandName 'getStarfieldPackage' -MockWith { return $True }
            Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $True }
            Mock -ModuleName utils -CommandName 'Join-Path' -MockWith { return 'Path' }
            Mock -ModuleName utils -CommandName 'logToFile'
        }

        It "should have a getRegConfigPath function" {
            $moduleFunctions | Should -Contain 'getRegConfigPath'
        }

        Context "functionality" {
            It "should return the path if exist" {
                getRegConfigPath |

                Should -Be 'Path'
                Should -Invoke logToFile -ModuleName utils -Times 0
            }

            It "should return $false and write to log if it does NOT exist" {
                Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $False }

                getRegConfigPath |

                Should -BeFalse
                Should -Invoke logToFile -ModuleName utils -Times 1
            }
        }
    }

    Describe "sfseRegistryExists" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys

            Mock -ModuleName utils -CommandName 'getRegConfigPath' -MockWith { return $True }
            Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $True }
            Mock -ModuleName utils -CommandName 'logToFile'
        }

        It "should have a sfseRegistryExists function" {
            $moduleFunctions | Should -Contain 'sfseRegistryExists'
        }

        Context "functionality" {
            It "should return $true if exist" {
                sfseRegistryExists |

                Should -BeTrue
                Should -Invoke logToFile -ModuleName utils -Times 0
                Should -Invoke getRegConfigPath -ModuleName utils -Times 1
            }

            It "should return $false and write to log if it does NOT exist" {
                Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $False }

                sfseRegistryExists |

                Should -BeFalse
                Should -Invoke logToFile -ModuleName utils -Times 1
                Should -Invoke getRegConfigPath -ModuleName utils -Times 1
            }
        }
    }

    Describe "backupGameReg" {
        BeforeAll {
            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
            
            $obj = [hashtable]@{
                Version = "0.1.70.0";
            }

            Mock -ModuleName utils -CommandName 'fileExists' -MockWith { return $True }
            Mock -ModuleName utils -CommandName 'getRegConfigPath' -MockWith { return $True }
            Mock -ModuleName utils -CommandName 'findRegistryValues' -MockWith { return $obj }
            Mock -ModuleName utils -CommandName 'logToFile'

            Mock -ModuleName utils -CommandName 'New-Item'
            Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $False }
            Mock -ModuleName utils -CommandName 'reg'
        }

        It "should have a backupGameReg function" {
            $moduleFunctions | Should -Contain 'backupGameReg'
        }

        Context "functionality" {
            It "should call reg export" {
                backupGameReg

                Should -Invoke fileExists -ModuleName utils -Times 1
                Should -Invoke getRegConfigPath -ModuleName utils -Times 1
                Should -Invoke findRegistryValues -ModuleName utils -Times 1
                Should -Invoke Test-Path -ModuleName utils -Times 1
                Should -Invoke reg -ModuleName utils -Times 1
            }

            It "should NOT call reg export if file exists" {
                Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $True }

                backupGameReg

                Should -Invoke fileExists -ModuleName utils -Times 1
                Should -Invoke getRegConfigPath -ModuleName utils -Times 1
                Should -Invoke findRegistryValues -ModuleName utils -Times 1
                Should -Invoke Test-Path -ModuleName utils -Times 1
                Should -Invoke reg -ModuleName utils -Times 0
                Should -Invoke logToFile -ModuleName utils -Times 1
            }

            It "should create the folder if it doesn't exist" {
                Mock -ModuleName utils -CommandName 'fileExists' -MockWith { return $False }
                
                backupGameReg
                Should -Invoke New-Item -ModuleName utils -Times 1
            }
            
            It "should write to log if the game version is not found" {
                Mock -ModuleName utils -CommandName 'findRegistryValues' -MockWith { return $False }

                backupGameReg
                Should -Invoke logToFile -ModuleName utils -Times 1
            }
        }
    }

    Describe "setSFSERegistry" {
        BeforeAll {
            $global:LogPath = '/path/'

            $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
            $regConfigPath = 'path/to/reg'

            Mock -ModuleName utils -CommandName 'getRegConfigPath' -MockWith { return $regConfigPath }
            Mock -ModuleName utils -CommandName 'sfseRegistryExists' -MockWith { return $False }
            Mock -ModuleName utils -CommandName 'backupGameReg'
            Mock -ModuleName utils -CommandName 'logToFile'
            
            Mock -ModuleName utils -CommandName 'Copy-Item'
            Mock -ModuleName utils -CommandName 'Set-ItemProperty'
            Mock -ModuleName utils -CommandName 'Test-Path' -MockWith { return $True }
        }

        AfterAll {
            # Remove global variable
            Remove-Variable -Name LogPath -Scope Global
        }

        It "should have a setSFSERegistry function" {
            $moduleFunctions | Should -Contain 'setSFSERegistry'
        }

        Context "functionality" {
            It "should copy and update the registry" {
                setSFSERegistry

                Should -Invoke getRegConfigPath -ModuleName utils -Times 1
                Should -Invoke sfseRegistryExists -ModuleName utils -Times 1
                Should -Invoke backupGameReg -ModuleName utils -Times 1
                Should -Invoke Test-Path -ModuleName utils -Times 2

                Should -Invoke Copy-Item -ModuleName utils -Times 1
                Should -Invoke Set-ItemProperty -ModuleName utils -Times 1
                Should -Invoke logToFile -ModuleName utils -Times 1 
            }

            It "should NOT copy and update the registry, if custom registry entry exists" {
                Mock -ModuleName utils -CommandName 'sfseRegistryExists' -MockWith { return $True }
                
                setSFSERegistry

                Should -Invoke getRegConfigPath -ModuleName utils -Times 1
                Should -Invoke sfseRegistryExists -ModuleName utils -Times 1
                Should -Invoke logToFile -ModuleName utils -Times 1 

                Should -Invoke backupGameReg -ModuleName utils -Times 0
                Should -Invoke Test-Path -ModuleName utils -Times 0
                Should -Invoke Copy-Item -ModuleName utils -Times 0
                Should -Invoke Set-ItemProperty -ModuleName utils -Times 0
            }

            It "should NOT copy and update the registry, if config path doesn't exist" {
                Mock -ModuleName utils -CommandName 'getRegConfigPath' -MockWith { return $False }
                
                setSFSERegistry

                Should -Invoke getRegConfigPath -ModuleName utils -Times 1
                Should -Invoke sfseRegistryExists -ModuleName utils -Times 1
                Should -Invoke logToFile -ModuleName utils -Times 1 

                Should -Invoke backupGameReg -ModuleName utils -Times 0
                Should -Invoke Test-Path -ModuleName utils -Times 0
                Should -Invoke Copy-Item -ModuleName utils -Times 0
                Should -Invoke Set-ItemProperty -ModuleName utils -Times 0
            }
        }
    }
}
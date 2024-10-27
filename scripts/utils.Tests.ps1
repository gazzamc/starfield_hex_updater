BeforeAll {
    $modulePath = (Join-Path $PSScriptRoot utils.psm1)
    Import-Module -Name $modulePath

    # Mock default commands
    Mock -ModuleName utils Test-Path { return $true }
    Mock -ModuleName utils Join-Path { return '/fake/' }
    Mock -ModuleName utils Write-Host {}
    Mock -ModuleName utils Write-Information {}

    Mock -ModuleName utils Get-Date {}
    Mock -ModuleName utils Out-File {}
}

Describe "Utils" {
    BeforeAll {
        $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
    }

    Describe "testPath" {

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
}

Describe "fileExists" {
    BeforeAll {
        $moduleFunctions = (Get-Module -ListAvailable $modulePath).ExportedFunctions.Keys
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

        It "should return $null if the property does not exist" {
            getConfigProperty "debug" |

            Should -BeNullOrEmpty
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
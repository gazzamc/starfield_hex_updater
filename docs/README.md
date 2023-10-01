# How-to guide:

I understand that for someone without any dev experience this might seems a bit daunting, but I've made it as simple as possible. Once you follow this guide you will see just how simple it is to build SFSE that works on Gamepass/Windows version of Starfield.

Bare in mind that not all SFSE mods will work, many require a patch as they don't use SFSE directly but as an injector. I've patched many and have them available to download on github, you can see the list [here](#supported-mods). If the source is available and it open source I can patch it. I'm hoping that in the future and with the introduction of the address library I won't need to patch these mods and they'll work out of the box.


# Table of Contents

- [Prerequisites](#Prerequisites)
- [Backing up save files](#backing-up-save-files)
- [Removing Permissions](#removing-permissions)
- [Running the script](#running-the-script)
    - [Pulling SFSE](#pulling-sfse)
    - [Pulling the Script](#pulling-the-script)
    - [Patching](#patching)
    - [Updating Addresses](#update-addresses)
    - [Building](#Building)
- [Did it work?](#did-it-work)
- [Supported Mods](#supported-mods)


## Prerequisites
Going on the assumption that you have clean windows install with absolutely no tools installed, this is what you will need to complete this guide.

- [Python 3.11](https://www.python.org/ftp/python/3.11.0/python-3.11.0-amd64.exe)
- [Git](https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe)
- [CMake](https://github.com/Kitware/CMake/releases/download/v3.27.6/cmake-3.27.6-windows-x86_64.msi)

<i>Be sure to add these to windows path if the option is available</i>

## Backing up save files

<span style="color:yellow;">Caution: I highly recommend you backup your save files!</span>

- Windows Key + R:
- Type into the input box
```
    %localappdata%/packages/BethesdaSoftworks.ProjectGold_3275kfvn8vcwc/SystemAppData/wgs
```
- Backup the folder with the random numbers


#### Note: The `BethesdaSoftworks` folder may change names, if so you may need to go to it manually, everthing else won't change.

## Removing Permissions

Windows store games have special permissions that prevents any tampering with the games exe (and in some cases the files), we will need to remove this in order to inject the mods with SFSE. Running the built SFSE in the game folder won't work.

You have two options:

1. [Copy Files](#copy-files)
2. [Hardlink](#hardlink)

<span style="color:yellow;">Note: The Hardlink script won't work across separate drives</span>

### Copy Files

If you have the space to do so, I would highly recommend just copying the files to another folder, this prevents the mods breaking when the game updates. I can still play `v1.7.29` as of right now, if it changes in the future I'll add a note.

1. Select all files/folders within `content` folder (or `CTRL + A`)
2. Right-Click `Copy`
3. Right-click `Paste` into target folder

<span style="color:yellow;">Be sure to copy the files to a directory where you have full permissions eg. Desktop</span>

### Hardlink

Hardlinking will save some space, at least with my script, it will create a new version of the files in the root of the game folder but will create a junction of the data folders. I haven't used this method but it may break when the game updates as the folders will be modified via the original game folder.

Script:
```powershell
Get-ChildItem | ForEach-Object { 
    $path  = "path/to/new/folder"

    # We can't hardlink folders, use junction
    if ($_.PSIsContainer){
        New-Item -ItemType Junction -Path "$($path)\$($_.Name)" -Value $_.FullName 
    } else{ 
        New-Item -ItemType HardLink -Path "$($path)\$($_.Name)" -Value $_.FullName 
    }
}

pause #Not really needed unless you want to check for errors
```

1. Create file `copy-files.ps1` <span style='font-size:10px'>*name doesn't matter</span>
2. Move file to the `content` folder
2. Edit and paste the above script into it
2. Right-Click > `Run with Powershell`

The files will be added to the new folder you specified.

### Can't move exe?

You'll probably get an error when trying to move `Starfield.exe`, if this happens, do the following:

1. Right-Click > Cut
2. Paste `Starfield.exe` to the target folder
3. Copy it back to the original game folder

You will notice that the icon of the exe will change to the starfield logo, this is good.

### Pulling SFSE

Now we get to the bones of the guide.

In most cases the script will lack behind the latest commit of SFSE (Not necessarily the version available), so when we pull the repo we need to checkout the correct commit or the script won't work as intended.

- Open Command Prompt *
- `CD` to the folder you want to downlaod the source

```
    cd /folder/you/will/like/to/keep/the/repo
```
- Clone the repo
```
    git clone https://github.com/ianpatt/sfse.git
```
- `CD` into the folder created
```
    cd sfse
```
- Now we checkout the commit **
```
    git checkout <commit-id>
```

*You can do this in powershell too but I'll be using CMD

**You can find the commit id on the hex_table file eg. git <i>hex_table_1.7.33_`9f55120a`.json</i>

### Pulling the Script

It's almost identical the above without the checkout part.

- Open Command Prompt
- `CD` to the folder you want to downlaod the source

```
    cd /folder/you/will/like/to/keep/the/repo
```
- Clone the repo
```
    https://github.com/gazzamc/starfield_hex_updater.git
```
- `CD` into the folder created
```
    cd starfield_hex_updater
```

### Patching

Patching the exe is incredibly simple :)

- Open Command Prompt
- `CD` to the `starfield_hex_updater` folder
```
    cd starfield_hex_updater
```
- Type the following *
```

    python hex_updater.py -m patch -p /path/to/SFSE/sfse_loader

```

*Optionally you can prevent the backup of files touches with `-b false`

**Be sure the path is pointing the folder specified in `-p`, the script expects this folder

### Updating Addresses

Very similar to the last step

- Open Command Prompt
- `CD` to the `starfield_hex_updater` folder
```
    cd starfield_hex_updater
```
- Type the following *
```

    python hex_updater.py -m update -p /path/to/SFSE/sfse -d hex_tables/<latest-hex-table-json>

```

*Optionally you can prevent the backup of files touches with `-b false`

**Be sure the path is pointing the folder specified in `-p`, the script expects this folder

### Building

The final step, with everything patched we can follow the instructions on SFSE repo and build the EXE/DLL

- Open Command Prompt
- `CD` to the folder you cloned the sfse repo
- Run the command
```

    cmake -B sfse/build -S sfse

```
- Run the second command
```

    cmake --build sfse/build --config Release

```
You will find the exe and dll within a Release folder under their respective names inside the build folder. eg. `Build/sfse_loader/Release`

As with the official version move both files to the root of the game folder we created above. Start sfse_loader.exe to run the game.


# Did it work?

Once you boot up the game, go to settings and look for the sfse version number (beside the game version). Alternatively you can go the `My Games\Starfield\SFSE\Logs` and check `sfse.txt` to see if it loaded correctly.

Enjoy the game :)


# Issues / Fixes

- `Couldn't find _get_narrow_winmain_command_line`
- `Couldn't find Starfield.exe`

When checking the logs, if you see the following at the top of the `sfse.txt` this means the permissions were not removed from the exe and it didn't inject correctly. Did you try running it from the original folder?

Re-do the [Removing Permissions](#removing-permissions) step.

- `The Windows Store (gamepass) version of Starfield is not supported.`

Did you do the [Patching](#patching) step, and point it to the sfse folder (not the root of repo)?

- `The game doesn't launch/crashes`

Be sure you're checking out the correct commit id and using the correct version of the game, this information is within the name of the hex_table file. 

Also if the game is launching and it's crashing, please be sure you're using one of the [Supported Mods](#supported-mods), not all mods for sfse will work with this modified version. If the mod has an open source repo (usually mentioned on nexus mods) you can reach out to me and I'll try and patch it.

### Supported Mods

The following is a list of mods that I have personally tested and patched for the latest supported version of this script. You won't need to build these, as I have them available to download on Github. I won't go through the trouble of putting these on nexus mods, perhaps the authors of said mods may do so themselves, or even support GP version in the future. As mentioned before if I can get the Address library working on this version of SFSE then patching mods (that have implemented it) won't be needed.

If you find a mod that's working and not in this list, reach out to me or create a PR and I'll add it.

### Patched
- [BakaQuickFullSaves](https://github.com/gazzamc/BakaQuickFullSaves/releases) - Official Nexus Mods [link](https://www.nexusmods.com/starfield/mods/1750) 
- [BakaQuitGameFix](https://github.com/gazzamc/BakaQuitGameFix/releases) - Official Nexus Mods [link](hhttps://www.nexusmods.com/starfield/mods/1662) 
- [BakaKillMyGames](https://github.com/gazzamc/BakaKillMyGames/releases) - Official Nexus Mods [link](https://www.nexusmods.com/starfield/mods/1599) 
- [AchievementEnablerSFSE](https://github.com/gazzamc/AchievementEnablerSFSE/releases) - Official Nexus Mods [link](https://www.nexusmods.com/starfield/mods/658)
- [HoldToEquipExtended](https://github.com/gazzamc/HoldToEquipExtended/releases) - Official Nexus Mods [link](https://www.nexusmods.com/starfield/mods/1956)
- [GravityAffectsCarryWeight](https://github.com/gazzamc/GravityAffectsCarryWeight/releases) - Official Nexus Mods [link](https://www.nexusmods.com/starfield/mods/3048)
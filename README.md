# Starfield Hex Updater

## Requirements
I've tried to keep it as simple as possible, I've used only build-in imports. Using the below version of python, I'm sure any version above python 3.x would work, but if you have any trouble use the one I mentioned.

Be vigilant of the hex table name `hex_table_{game_version}_{commit_id}.json`, it consists of important data, so if you're having issues after running the update be sure you're trying to update with the correct hex table.

> Python 3.11 

## Usage
        hex_script.py -m <mode> <options>

        Modes:
            generate: Creates a hex table for updating hex values
            update: Updates hex values using a hex dictionary

        <Options>
            -h, --help
            -m, --mode: Selects the mode to use
            -v, --version: script version number
                generate:
                    -p, --path: Path of the old hex values, will be used as a reference (use full path)
                    -n, --path2: Path of the new hex values, will become the value of the old key (use full path)
                    -g, --starfield: Starfield game version, will be used in the filename
                    -c, --commit: commit ID of a mod tool not to be named :?, will be used in the filename
                    -s, --silent: hides any caught exceptions / print()
                update:
                    -p, --path: Path to the folder of files to be updated, files will be backed up by default (use full path)
                    -d, --dictfile: dictionary to be used for updating hex values (use full path)
                    -b, --backup: Option to prevent backup files

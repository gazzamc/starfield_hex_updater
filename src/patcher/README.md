## Usage
        patcher.py -m <mode> <options>

        Modes:
            generate: Creates a hex table for updating hex values
            update: Updates hex values using a hex dictionary
            patch: Patches out the error message preventing program from running
            md5: Will generate a md5 checksum for the files to verify patch was successful

        <Options>
            -h, --help
            -m, --mode: Selects the mode to use
            -v, --version: script version number
            -s, --silent: hides output of commands
                generate:
                    -p, --path: Path of the old hex values, will be used as a reference (use full path)
                    -n, --path2: Path of the new hex values, will become the value of the old key (use full path)
                    -g, --starfield: Starfield game version, will be used in the filename
                    -c, --commit: Truncated commit ID of SFSE, will be used in the filename
                update:
                    -p, --path: Path to the folder of files to be updated, files will be backed up by default (use full path)
                    -d, --dictfile: dictionary to be used for updating hex values (use full path)
                    -b, --backup: Option to backup files
                patch:
                    -p, --path: Path to the folder of files to be patched, files will be backed up by default (use full path)
                    -b, --backup: Option to backup files
                md5:
                    -p, --path: Path to the folder containing the files
                    -f, --filename: Filename of the file generated
                    --verify: Verify patch/update via md5 hash

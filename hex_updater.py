import hashlib
import os
import glob
import json
import sys
import json
import re
import getopt
from tempfile import mkstemp
from shutil import move, copymode, copy
from os import fdopen, getcwd, path as ospath


def warning_msg(msg):
    print("\033[93m {}\033[00m\n".format(msg))


def error_msg(msg):
    print("\033[91m {}\033[00m\n".format(msg))


def success_msg(msg):
    print("\033[92m {}\033[00m\n".format(msg))


def get_replacement_hex(hex_to_find, dictionary):
    try:
        new_hex = dictionary[hex_to_find]
        return new_hex
    except KeyError as e:
        warning_msg(
            "No replacement found for {}, leaving it in place. Be Sure to check you have the correct hex table for this version".format(e))


def convert(list):
    string = ''
    for c in list:
       string = string + chr(c)

    return string


def get_full_path(path, filename):
    return ospath.join(path, ''.join(filename))


def move_file(old_file, new_file, backup, patched):
    copymode(old_file, new_file)

    if backup and patched:
        copy(old_file, "{}.bak".format(old_file))

    # Only replace if patched
    if patched:
        move(new_file, old_file)
        print("Patched {0}".format(ospath.basename(old_file)))


def scrape_hex_values_from_file(file, silent):
    hex_list = []

    # Read the lines of the files and create array for each
    with open(r'{}'.format(file), 'r') as file:
        for line in file.readlines():
            # check if valid hex before appending
            try:
                regex = '(0[xX][0-9a-fA-F]{7,})'
                pattern = re.findall(regex, line)

                if len(pattern) >= 1:
                    hex_list.append(pattern[0])
            except ValueError:
                if not silent:
                    warning_msg(
                        "Invalid hex, won't be added to the list: ", line)
    return hex_list


def generate_checksum(file, silent):
    checksum = hashlib.md5(open(file, 'rb').read()).hexdigest()
    if checksum and not silent:
        print('Checksum generated for: {0}'.format(file))

    return checksum


def generate_checksum_file(files, filename, silent):
    md5FolderPath = get_full_path(ospath.abspath(
        os.path.dirname(__file__)), 'md5')

    generated_checksums = []
    for file in files:
        generated_checksums.append(generate_checksum(file, silent))

    # Check checksum folder exists
    md5FolderExists = ospath.exists(md5FolderPath)

    if not md5FolderExists:
        os.mkdir(md5FolderPath)

    with open('md5/{}.md5'.format(filename), 'w') as md5_file:
        for checksum in generated_checksums:
            md5_file.write('{}\n'.format(checksum))


def getPatchedChecksums(silent=False):
    # check that md5 files exists
    md5FolderPath = get_full_path(ospath.abspath(
        os.path.dirname(__file__)), 'md5')

    if ospath.exists(md5FolderPath):
        if not silent:
            print("md5 folder found, looking for md5 file...")
    else:
        error_msg(
            "md5 folder not found in script directory!, re-download folder from repo to continue.")
        sys.exit()

    md5FileExists = ospath.exists(get_full_path(md5FolderPath, 'patched.md5'))

    if md5FileExists:
        if not silent:
            print("md5 file found, comparing hashes!")
    else:
        error_msg(
            "Patched md5 file not found in md5 directory!, re-download file from repo to continue.")
        sys.exit()

    patched_checksums = []
    # add all patched checksum into list for easier lookup
    with open(get_full_path(md5FolderPath, 'patched.md5'), 'r') as file:
        patched_checksums = file.read().splitlines()

    return patched_checksums


def verifyMd5(files, silent):
    print("Verifying Checksums!")

    patched_checksums = getPatchedChecksums()
    match_count = 0
    # Iterate over files and verify md5 hash
    for file in files:
        checksum = generate_checksum(file, True)
        isValid = checksum in patched_checksums

        if not silent:
            if isValid:
                match_count += 1
                success_msg('{}: md5 Match!'.format(ospath.basename(file)))
            else:
                error_msg('{}: md5 Mismatch!'.format(ospath.basename(file)))

    if match_count == len(files):
        success_msg('All files matched!')
    else:
        error_msg(
            'Some or all files failed to patch correctly! {0}/{1} '.format(match_count, len(files)))

def create_combined_dictionary(lookup_file, value_file):
    old_list = lookup_file
    new_list = value_file

    # compare list size and throw error if different
    if len(old_list) != len(new_list):
       error_msg('The two files do not have the same length of lines, please check')
       sys.exit()
    else:
        #create the dictionary of hex values from files
        dictionary = {"{}".format(old_list[i]): new_list[i] for i in range(len(old_list))}

    return dictionary


def update(file_with_path, dictionary, backup):
    # Prevent patcher from running on the same file twice
    # potentially changing new addresses
    patched_checksums = getPatchedChecksums(True)
    checksum = generate_checksum(file_with_path, True)

    if checksum in patched_checksums:
        print('{} already patched, skipping!'.format(
            ospath.basename(file_with_path)))
        return

    regex = '(0[xX][0-9a-fA-F]{7,})'
    patched = False

    # Create temp file
    fh, abs_path = mkstemp()
    with fdopen(fh, 'r+') as new_file:
        with open(file_with_path, "r+") as old_file:
            for line in old_file:
                # replace single hex value
                pattern = re.findall(regex, line)

                if len(pattern) == 1:
                    old_hex = pattern[0]
                    new_hex = get_replacement_hex(old_hex, dictionary)

                    # if we find no hex leave the previous line
                    if new_hex is None:
                        new_file.write(line)
                    else:
                        new_file.write(line.replace(old_hex, new_hex))
                        patched = True

                elif len(pattern) > 1:
                    # iterate through hex values and replace them
                    new_line = line

                    for hex_in_pattern in pattern:
                        new_hex = get_replacement_hex(
                            hex_in_pattern, dictionary)

                        # no hex, leave it alone
                        if new_hex is not None:
                            new_line = new_line.replace(old_hex, new_hex)
                            patched = True

                    new_file.write(new_line)
                else:
                    # keep old line if nothing found
                    new_file.write(line)

    move_file(file_with_path, abs_path, backup, patched)


def generate_hex_list_from_files(files_grabbed, path, silent):
    full_hex_list = []

    # iterate over the files and scrape the hex values into a single file
    for file in files_grabbed:
        full_hex_list = full_hex_list + scrape_hex_values_from_file(get_full_path(path, file), silent)
    
    return full_hex_list


def get_files(path, include_all=False, types=('*.cpp', '*.inl', '*.h')):
    # Grab files for the directory, should be identical for both
    files_grabbed = []
    types_to_include = []
    patched_dirs = ['sfse', 'sfse_loader']

    if include_all:
        # Grab the patched files and include them
        for type in types:
            for directory in patched_dirs:
                types_to_include.append('{0}\{1}'.format(directory, type))
    else:
        types_to_include = types

    for file in types_to_include:
        if not include_all:
            # Strip path so we can add it later for scraping the hex values
            files_grabbed.extend(ospath.basename(x) for x in glob.glob(
                get_full_path(path, file)))
        else:
            files_grabbed.extend(glob.glob(
                get_full_path(path, file), recursive=True))

    return files_grabbed

def get_dict(path):
    hex_dict = {}

    # convert json dump to dict
    with open(r'{}'.format(path), 'r') as file:
        lines = file.read()
        hex_dict = json.loads(lines)

    return hex_dict

def generate_hex_dict_for_dir(path1, path2, filename, silent):
    files_grabbed = get_files(path1)

    # Generate array of hex values from the files
    hex_list_old = generate_hex_list_from_files(files_grabbed, path1, silent)
    hex_list_new = generate_hex_list_from_files(files_grabbed, path2, silent)


    # Create the dict with both lists
    combined_dict = create_combined_dictionary(hex_list_old, hex_list_new)

    # Write file to working dir
    with open(filename, "w") as f:
        f.write(json.dumps(combined_dict))
        f.close()

def patch(path, silent, backup):
    files_to_patch = [
        convert([
            80, 108, 117, 103, 
            105, 110, 77, 97, 
            110, 97, 103, 101, 
            114, 46, 99, 112, 112]), 
        convert([
            73, 100, 101, 110, 116, 
            105, 102, 121, 69, 88, 
            69, 46, 99, 112, 112
            ]),
        convert([
            109, 97, 105, 110, 
            46, 99, 112, 112
        ])
    ]
    dirs = [
        convert([115, 102, 115, 101]), 
        convert([
            115, 102, 115, 101, 95,
            108, 111, 97, 100, 101, 
            114])
    ]

    if path == '':
        path = getcwd()

    for dir in dirs:
        for file in files_to_patch:
            path_to_file = get_full_path(ospath.join(path, dir), file)
            if ospath.exists(path_to_file):
                
                fh, abs_path = mkstemp()
                with fdopen(fh,'r+') as new_file:
                    with open(path_to_file, "r+") as old_file:
                        lines = old_file.readlines()
                        line_count = len(lines)
                        already_patched = False

                        if file == files_to_patch[2]:
                            # Check if already patched
                            if line_count != 346:
                                    already_patched = True
                            else:
                                for idx, line in enumerate(lines):
                                    if idx == 116:
                                        old_line = lines.pop(idx)
                                        new_line = "//{}".format(old_line)
                                        lines.insert(idx, new_line)

                                    if idx == 306:
                                        new_line = line.replace(
                                            convert([83, 116, 101, 97, 109]), 
                                            convert([
                                                87, 105, 110, 83, 
                                                116, 111, 114, 101
                                            ])
                                            )
                                        lines.insert(308, new_line)

                        if file == files_to_patch[1]:
                            # Check if already patched
                            if line_count != 482:
                                if str(lines[321]).startswith('//'):
                                    already_patched = True
                            else:
                                for idx, line in enumerate(lines):
                                    if idx >= 320 and idx <= 324:
                                        old_line = lines.pop(idx)
                                        new_line = "//{}".format(old_line)
                                        lines.insert(idx, new_line)

                                    if idx == 361:
                                        new_line = line.replace(
                                            convert([83, 116, 101, 97, 109]), 
                                            convert([
                                                87, 105, 110, 83, 
                                                116, 111, 114, 101
                                            ])
                                            )
                                        lines.insert(362, new_line)

                                    elif idx >= 374 and idx <= 379:
                                        old_line = lines.pop(idx)
                                        new_line = "//{}".format(old_line)
                                        lines.insert(idx, new_line)

                        if file == files_to_patch[0]:
                            # Check if already patched
                            if str(lines[398]).startswith('//'):
                                already_patched = True
                            else:
                                for idx, line in enumerate(lines):
                                    if idx == 398:
                                        old_line = lines.pop(idx)
                                        new_line = "//{}".format(old_line)
                                        lines.insert(idx, new_line)

                                    if idx == 401:
                                        old_line = lines.pop(idx)
                                        new_line = line.replace(
                                            convert([
                                                45, 37, 100, 45, 
                                                37, 100, 45, 37, 
                                                100, 45, 37, 100, 
                                                37, 115
                                                ]), 
                                            convert([
                                                45, 37, 100, 45, 37, 
                                                100, 45, 37, 100, 45, 
                                                37, 100, 45, 37, 100
                                            ])
                                            )
                                        lines.insert(idx, new_line)

                                    elif idx == 405:
                                        old_line = lines.pop(idx)
                                        new_line = line.replace(
                                            convert([
                                                98, 117, 105, 108, 100, 
                                                84, 121, 112, 101
                                                ]), 
                                            convert([49])
                                            )
                                        lines.insert(idx, new_line)

                        if not silent and already_patched:
                            warning_msg("{} already patched".format(file))            

                        new_file.writelines(lines)

                move_file(path_to_file, abs_path, backup, True)

def main(argv):
    modes = ["update", "generate", "patch", "md5"]
    version = "0.2.2"

    mode= ''
    path = ''
    path2 = ''
    game_version = ''
    commit = ''
    silent = False
    backup = False
    verify = False
    filename = 'patched'

    help_info = """
        hex_updater.py -m <mode> <options>

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
    """

    #try:
    opts, args = getopt.getopt(argv, "hvm:d:p:n:s:g:c:b:f:", [
                               "help", "mode=", "dictfile=", "path=", "path2=", "silent", "starfield=",
                               "commit=", "version", "backup", "filename=", "verify"])
    for opt, arg in opts:
        if opt in ('-h', "--help"):
                print(help_info)
                sys.exit()
        elif opt in ("-m", "--mode"):
                mode = arg
        elif opt in ("-d", "--dictfile"):
                dict_file_name = arg
        elif opt in ("-p", "--path"):
                path = arg
        elif opt in ("-n", "--path2"):
                path2 = arg
        elif opt in ("-g", "--starfield"):
                game_version = arg
        elif opt in ("-v", "--version"):
                print("Script Version: {}".format(version))
        elif opt in ("-c", "--commit"):
                commit = arg
        elif opt in ("-f", "--filename"):
            filename = arg
        elif opt in ("--verify"):
            verify = True
        elif opt in ("-b", "--backup"):
            backup = True
        elif opt in ("-s", "--silent"):
            silent = True

    if mode == modes[0]:
        if dict_file_name == '' or path == '':
            error_msg("No paths provided for generating hex table")
            sys.exit()

        # Get files to update
        files = get_files(path)
        hex_dict = get_dict(dict_file_name)

        if len(files) == 0 or hex_dict is None:
            error_msg("No files to update, or dictionary not found")
            sys.exit()

        for file in files:
            update(get_full_path(path, file), hex_dict, backup)

    elif mode == modes[1]:
        if path == '' or path2 == '':
            error_msg("No paths provided for generating hex table")
            sys.exit()
        
        hex_file_name = "hex_table_{0}_{1}.json".format(game_version, commit)
        generate_hex_dict_for_dir(path, path2, hex_file_name, silent)

    elif mode == modes[2]:
        currDirName = ospath.basename(getcwd())
        if path == '' and currDirName != convert([115, 102, 115, 101]):
            # Check if we're in the correct directory
            error_msg("Be sure to either run the script within the repo folder or point to the folder using [-p, --path] arguments")
            sys.exit()
        
        patch(path, silent, backup)

    elif mode == modes[3]:
        currDirName = ospath.basename(getcwd())
        if path == '' and currDirName != convert([115, 102, 115, 101]):
            # Check if we're in the correct directory
            error_msg(
                "Be sure to either run the script within the repo folder or point to the folder using [-p, --path] arguments")
            sys.exit()

        files = get_files(path, True)
        if len(files) == 0:
            error_msg(
                "No Files found in provided path")
            sys.exit()

        if verify:
            verifyMd5(files, silent)
        else:
            generate_checksum_file(files, filename, silent)
    else:
        warning_msg("No mode selected, use -h, --help for usage")

if __name__ == "__main__":
   main(sys.argv[1:])
import glob, os, json, sys, json, re, getopt
from tempfile import mkstemp
from shutil import move, copymode, copy
from os import fdopen

def scrape_hex_values_from_file(file, silent):
    hex_list = []

    #Read the lines of the files and create array for each
    with open(r'{}'.format(file), 'r') as file:
        for line in file.readlines():
            #check if valid hex before appending
            try:
                regex = '(0[xX][0-9a-fA-F]+)'
                pattern = re.findall(regex, line)

    	        # unlikely to have two on one line, will change if needed
                if len(pattern) == 1:
                    hex_list.append(pattern[0])
            except ValueError:
                if not silent:
                    print("Invalid hex, won't be added to the list: ", line)
    return hex_list


def create_combined_dictionary(lookup_file, value_file):
    old_list = lookup_file
    new_list = value_file

    #compare list size and throw error if differnt
    if len(old_list) != len(new_list):
       sys.exit('The two files do not have the same length of lines, please check')
    else:
        #create the dictionary of hex values from files
        dictionary = {"{}".format(old_list[i]): new_list[i] for i in range(len(old_list))}

    return dictionary


def get_replacement_hex(hex_to_find, dictionary):
    try:
        new_hex = dictionary[hex_to_find]
        return new_hex
    except KeyError as e:
        print("No replacement found for {}, leaving it in place. Be Sure to check you have the correct hex table for this version".format(e))


def update(file_path, dictionary, backup):
    regex = '(0[xX][0-9a-fA-F]+)'

    #Create temp file
    fh, abs_path = mkstemp()
    with fdopen(fh,'r+') as new_file:
        with open(file_path, "r+") as old_file:
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

                elif len(pattern) > 1:
                    # iterate through hex values and replace them
                    new_line = line

                    for hex_in_pattern in pattern:
                        new_hex = get_replacement_hex(hex_in_pattern, dictionary)

                        # no hex, leave it alone
                        if new_hex is not None:
                            new_line = new_line.replace(old_hex, new_hex)

                    new_file.write(new_line)
                else:  
                    # keep old line if nothing found  
                    new_file.write(line)

    # Backup and move newly modified files
    copymode(file_path, abs_path)
    if backup:
        copy(file_path, "{}.bak".format(file_path))
    move(abs_path, file_path)


def generate_hex_list_from_files(files_grabbed, path, silent):
    full_hex_list = []

    # iterate over the files and scrape the hex values into a single file
    for file in files_grabbed:
        full_hex_list = full_hex_list + scrape_hex_values_from_file(os.path.join(path, ''.join(file)), silent)
    
    return full_hex_list

def get_files(path):
    # Grab files for the directory, should be identical for both
    types = ('*.cpp', '*.inl', '*.h')
    files_grabbed = []

    for files in types:
        # Strip path so we scrap new hex values in other path
        files_grabbed.extend(os.path.basename(x) for x in glob.glob(os.path.join(path, ''.join(files))))

    print(files_grabbed)
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


def main(argv):
    modes = ["update", "generate"]
    version = 0.01

    mode= ''
    path = ''
    path2 = ''
    game_version = ''
    commit = ''
    silent = False
    backup = True

    help_info = """
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
                    -c, --commit: commit ID of a mod tool not to be names :?, will be used in the filename
                    -s, --silent: hides any caught exceptions
                update:
                    -p, --path: Path to the folder of files to be updated, files will be backed up by default (use full path)
                    -d, --dictfile: dictionary to be used for updating hex values (use full path)
                    -b, --backup: Option to prevent backup
    """

    #try:
    opts, args = getopt.getopt(argv,"hvm:d:p:n:s:g:c:b:",["help", "mode=", "dictfile=", "path=", "path2=", "silence=", "starfield=", "commit=", "version", "backup="])
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
        elif opt in ("-b", "--backup"):
            if arg.lower() == "false":
                backup = False
        elif opt in ("-s", "--silence"):
            if arg.lower() == "true":
                silent = True

    if mode == modes[0]:
        if dict_file_name == '' or path == '':
            print("No paths provided for generating hex table")
            sys.exit()

        # Get files to update
        files = get_files(path)
        hex_dict = get_dict(dict_file_name)

        if len(files) == 0 or hex_dict is None:
            print("No files to update, or dictionary not found")
            sys.exit()

        print("backup", backup)
        for file in files:
            update(os.path.join(path, ''.join(file)), hex_dict, backup)

    elif mode == modes[1]:
        if path == '' or path2 == '':
            print("No paths provided for generating hex table")
            sys.exit()
        
        hex_file_name = "hex_table_{0}_{1}.json".format(game_version, commit)
        generate_hex_dict_for_dir(path, path2, hex_file_name, silent)


if __name__ == "__main__":
   main(sys.argv[1:])
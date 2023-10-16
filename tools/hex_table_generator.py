# Creates a hex table of the two different Address Libraries
# Be aware this will create a much bigger files that the ones in hex_table folder

import json


def convert_add_lib_to_hex_map(lib):
    hex_list = {}

    with open(r'{}'.format(lib), 'rt') as file:
        for line in file.readlines():
            split_line = line.strip().split(' ')

            id = split_line[0]
            addr = split_line[len(split_line) - 1]

            # add hex format to addr for easy lookup
            if(addr[0] == 0):
                fixed_addr = '0x00{}'.format(addr.strip()[2::])
            else:
                fixed_addr = '0x0{}'.format(addr.strip()[2::])

            hex_list[int(id)] = fixed_addr

    return hex_list


def gen_hex_table(steam_path, win_path):
    steam = convert_add_lib_to_hex_map(steam_path)
    win = convert_add_lib_to_hex_map(win_path)

    hex_dict = {}
    # iterate through steam addreses and create new dict
    for id, hex_val in steam.items():
        try:
            if(hex_val != win[id]):
                hex_dict[hex_val] = win[id]
        except KeyError:
            # ID doesn't exists
            continue

    # dump to file
    with open("diff.json", "w") as f:
        f.write(json.dumps(hex_dict))
        f.close()



steam_path = input('Steam address library file path: ')
win_path = input('Windows address library file path: ')

gen_hex_table(steam_path, win_path)
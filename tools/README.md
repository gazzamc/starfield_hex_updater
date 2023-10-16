# Tools

I might not be able to update the hex_table file as quickly as SFSE updates come out, for this reason I've written a script that will
extract the different hex values from each Address Library available on [Nexus Mods](https://www.nexusmods.com/starfield/mods/3256?tab=files), this library usually comes out pretty quickly after a game update.


## Hex Table Generator

It's quiet simple to use, add the path for both the steam and windows offsets files (obtained from [Nexus Mods](https://www.nexusmods.com/starfield/mods/3256?tab=files)) and the script will generate a json file. Once you have this, update the hex values as you would with the `hex_table`, substituting the `hex_table` file for the one you generated.

:warning: Before uploading a hex table file I personally test it with a handful of mods to be sure it works correctly, using this method may not work as it's dependent on the Address Library having the offsets needed. There's a few specific functions for the steam version that won't be updated (this is shown when running the script to update the values). It's probably safer to comment these out rather than use the steam equivalent. 
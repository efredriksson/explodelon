## Explodelon 💣
A minimal Saturn Bomberman clone that is easy to play on RecalBox with friends. Will also work as a way to add new interesting game mechanics.

### Development setup
For developing and building, the dependencies [Lua](https://www.lua.org/), [LuaRocks](https://luarocks.org/), [Make](https://www.gnu.org/software/make/), Zip, and [Teal](https://teal-language.org/) are needed.

So, something like ```sudo apt install luarocks make zip``` and then ```sudo luarocks install tl``` or similar for your system should do the trick.

You most likely want to setup so that you have a Teal LSP, see [here](https://github.com/teal-language/tl?tab=readme-ov-file#text-editor-support).

### Running the game
First run `make package` which will produce the game file `explodelon.lutro` file. Easiest way to run it is to install [RetroArch](https://www.retroarch.com/?page=platforms).

You can now run the game directly using `./retroarch --verbose -L cores/lutro_libretro.so path/to/explodelon.lutro` (you might need to start it normally first and add the Lutro core first).

> Tip: You can create a .env file and add `LUTRO_DIST_DIR=...` to override where `make package` will put the game.

> Tip: The `--verbose` flag will give you helpful output if the game crashes during development. This is the main reason to use RetroArch over Ludo.

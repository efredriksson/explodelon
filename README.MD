### Development setup
For developing and building, the dependencies [Lua](https://www.lua.org/), [LuaRocks](https://luarocks.org/), [Make](https://www.gnu.org/software/make/), Zip, and [Teal](https://teal-language.org/) are needed.

So, something like ```sudo apt install luarocks make zip``` and then ```sudo luarocks install tl``` or similar for your system should do the trick.

You most likely want to setup so that you have a Teal LSP, see [here](https://github.com/teal-language/tl?tab=readme-ov-file#text-editor-support).

### Running the game
First run `make package` which will produce the game file `impact-man.lutro` file. Easiest way to run it is to install [Ludo](https://ludo.libretro.com/).

You can now run the game directly using `./ludo -L cores/lutro_libretro.so path/to/impact-man.lutro` (see the Lutro getting started docs). Note that Ludo does not seem to like if you run it from any other directory, so stand in the installation directory and use `./ludo ...` as above.

> Tip: You can create a .env file and add `LUTRO_DIST_DIR=...` to override where `make package` will put the game.

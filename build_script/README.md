## Binaries for Android Build Script ##
Build script for cross compiling most of the binaries present in this repo

## Prerequisites

Linux - Tested on Arch-based distro. You could try this on other distros but your mileage may vary

### Prereq Setup ###
```
sudo pacman -S git libgit2 # Needed for exa
git clone https://github.com/akhilnarang/scripts # Sets up build environment
cd scripts
bash setup/arch-manjaro.sh
cd ..
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh # Needed for exa
source $HOME/.cargo/env
rustup target add aarch64-linux-android arm-linux-androideabi i686-linux-android x86_64-linux-android
```

## Build instructions

./build.bash --help # For more info on usage

## Compatibility

The below table notes if the binary is compatible with android ndk. If static or dynamic is listed, then only that link method is working

|           | NDK?    | Notes |
| --------- |:-------:|:---------------------------------------------------------------------------:|
| **bash**      | *Static*  | |
| **bc**        | Yes       | Also includes dc |
| **coreutils** | Yes       | Advanced cp/mv (progress bar), Openssl support, Optional Selinux Support |
| **cpio**      | Yes       | Newer versions are bugged, stick with 2.12 for now |
| **diffutils** | Yes       | Also includes cmp, diff, diff3, sdiff |
| **ed**        | Yes       | |
| **exa**       | *Static*  | |
| **findutils** | Yes       | Also includes find, locate, updatedb, xargs |
| **gawk**      | Yes       | GNU awk |
| **grep**      | Yes       | Also includes egrep and fgrep, has ull perl regex support |
| **gzip**      | Yes       | Also includes gunzip and gzexe |
| **htop**      | Yes       | |
| **iftop**     | *Dynamic* | |
| **nano**      | *Static*  | |
| **ncurses**   | Yes       | Also includes capconvert, clear, infocmp, tabs, tic, toe, tput, tset |
| **nethogs**   | Yes       | |
| **patch**     | Yes       | |
| **patchelf**  | Yes       | |
| **sed**       | Yes       | |
| **sqlite3**   | *Dynamic* | |
| **tar**       | Yes       | |
| **tcpdump**   | Yes       | |
| **vim**       | Yes       | |
| **zsh**       | Yes       | |
| **zstd**      | Yes       | |

## Issues
* Sqlite3 static compile still ends up dynamically linked somehow
* Exa static compile still ends up dynamically linked somehow
* Pwcat and Grcat (part of gawk) seg fault when ndk is used, compile without it to use them
* Coreutils won't build with selinux with dynamic link - static only

### Credits for Bash/Patches

* [Alexander Gromnitsky](https://github.com/gromnitsky/bash-on-android)
* [Termux](https://github.com/termux/termux-packages/tree/master/packages/bash)
* [ATechnoHazard and koro666](https://github.com/ATechnoHazard/bash_patches)
* [BlissRoms](https://github.com/BlissRoms/platform_external_bash)

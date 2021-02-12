## Binaries for Android Build Script ##
Build script for cross compiling most of the binaries present in this repo

## Prerequisites

Linux - Tested on Arch-based distro. You could try this on other distros but your mileage may vary

### Prereq Setup ###
```
sudo pacman -S git libgit2 python-pip
pip install abimap
git clone https://github.com/akhilnarang/scripts # Sets up build environment
cd scripts
bash setup/arch-manjaro.sh
cd ..
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustup target add aarch64-linux-android armv7-linux-androideabi arm-linux-androideabi i686-linux-android x86_64-linux-android
cargo install cargo-ndk
```

## Generate Needed crt file for aria2
* Just copy the [ca-certificate.crt_gen.sh script](build_script/patches/ca-certificate.crt_gen.sh) to your device and run it in terminal as su

## Build instructions

./build.bash --help # For more info on usage

## Compatibility

The below table notes if the binary is compatible with android ndk. If static or dynamic is listed, then only that link method is working

|           | NDK?    | Notes |
| ------------ |:-------:|:---------------------------------------------------------------------------:|
| **aria2**        | Yes       | |
| **bash**         | *Static*  | |
| **bc**           | Yes       | Also includes dc |
| **bzip2**        | Yes       | |
| **boringssl**    | *Static*  | Static libs still work fine with dynamic linked binaries |
| **brotli**       | Yes       | |
| **c-ares**       | Yes       | |
| **coreutils**    | Yes       | Advanced cp/mv (progress bar), Openssl support, Selinux Support |
| **cpio**         | Yes       | Newer versions are bugged, stick with 2.12 for now |
| **curl**         | Yes       | |
| **diffutils**    | Yes       | Also includes cmp, diff, diff3, sdiff |
| **ed**           | Yes       | |
| **exa**          | *Static*  | |
| **findutils**    | Yes       | Also includes find, locate, updatedb, xargs |
| **gawk**         | Yes       | GNU awk |
| **gdbm**         | Yes       | |
| **grep**         | Yes       | Also includes egrep and fgrep, has full perl regex support |
| **gzip**         | Yes       | Also includes gunzip and gzexe |
| **htop**         | Yes       | |
| **iftop**        | *Dynamic* | |
| **libexpat**     | Yes       | |
| **libidn2**      | Yes       | |
| **libmagic**     | Yes       | |
| **libmetalink**  | Yes       | |
| **libnl**        | Yes       | |
| **libpcap**      | Yes       | |
| **libpsl**       | Yes       | |
| **libssh2**      | Yes       | |
| **libunistring** | Yes       | |
| **nano**         | *Static*  | |
| **ncurses**      | Yes       | Also includes capconvert, clear, infocmp, tabs, tic, toe, tput, tset |
| **ncursesw**     | Yes       | Also includes capconvert, clear, infocmp, tabs, tic, toe, tput, tset |
| **nethogs**      | Yes       | |
| **nghttp2**      | Yes       | Lib only |
| **openssl**      | Yes       | |
| **patch**        | Yes       | |
| **patchelf**     | Yes       | |
| **pcre**         | Yes       | |
| **pcre2**        | Yes       | |
| **quiche**       | Yes       | |
| **readline**     | Yes       | |
| **sed**          | Yes       | |
| **selinux**      | Yes       | |
| **sqlite**       | *Dynamic* | |
| **strace**       | Yes       | |
| **tar**          | Yes       | |
| **tcpdump**      | Yes       | |
| **vim**          | Yes       | |
| **wavemon**      | Yes       | |
| **zlib**         | Yes       | |
| **zsh**          | Yes       | |
| **zstd**         | Yes       | |

## Issues
* Aria2 and Curl have weird DNS error in Android Q when not run as superuser
* Aria2 static linked doesn't resolve url names - you'll have to use the --async-dns flag
* Sqlite3 static compile still ends up dynamically linked somehow
* Exa always statically compiles, limitation with rust
* Pwcat and Grcat (part of gawk) seg fault when ndk is used, compile without it to use them

### Credits 

* [Jarun](https://github.com/jarun/advcpmv)
* [Scopatz](https://github.com/scopatz/nanorc)
* [Alexander Gromnitsky](https://github.com/gromnitsky/bash-on-android)
* [Termux](https://github.com/termux/termux-packages/tree/master/packages/bash)
* [ATechnoHazard and koro666](https://github.com/ATechnoHazard/bash_patches)
* [BlissRoms](https://github.com/BlissRoms/platform_external_bash)
* [OhMyZsh](https://github.com/ohmyzsh/ohmyzsh)

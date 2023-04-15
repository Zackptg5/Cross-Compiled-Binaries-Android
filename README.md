# Cross Compiled Binaries for Android
This repo contains a variety of binaries cross compiled for android with Android NDK. All are static linked unless in a dynamic folder. Feel free to use them for whatever. Also contains some files for ccbins mod

## Disclaimer
I am not responsible for anything that happens to your device as a result of these binaries. If you don't know what a binary does, read up on its documentation first. If you're install gets borked because of a bad command, that's on you

## CCBins
Looking for ccbins? CCBins is the official magisk module terminal script that pulls these binaries and installs them. You can download it from my website here: https://zackptg5.com/android.php#ccbins

## Binaries Build Script
You can find the build script for these in the [build_scripts folder](build_script).

## Actively Maintained:
* Aria2 (v1.36.0) - to use static linked without root, use `--async-dns --async-dns-server=<yourdnserver,yourotherdnsserver>` (not needed for dynamic linked)
  * For use in an installer zip - use static linked
  * For use on a device - use dynamic linked if on Oreo (API 26) or newer
* Bash (v5.2.15)
* Bc (v6.1.1) - Gavin Howard posix Bc with GNU extensions
* Brotli (v1.0.9)
* Coreutils (v9.2) - has selinux support, openssl support, and includes patches for advanced cp/mv (adds progress bar functionality)
* Cpio (v2.12) - v2.13 is bugged so staying with this version
* Curl (v8.0.1) - boringssl support and more - working ssl, to use static linked without root, use `--dns-servers <yourdnserver,yourotherdnsserver>` (not needed for dynamic linked)
  * For use in an installer zip - use static linked
  * For use on a device - use dynamic linked if on Oreo (API 26) or newer
* Diffutils (v3.9)
* Ed (v1.19)
* Exa (v0.10.1) - dynamic only
* Findutils (v4.9.0)
* Freedup (v1.6-3)
* Gawk (Awk) (v5.2.1)
* Grep (v3.10)
* Gzip (v1.12)
* Htop (v3.2.2)
* Iw (v5.9)
* Keycheck
* Nano (v7.2)
* Nethogs (v0.8.6)
* Ncursesw (v6.4) - only terminfo files - needed for some binaries such as htop
* Nmap (v7.93) - dynamic only
* Openssl (v3.1.0)
* Patch (v2.7.6)
* Patchelf (v0.17.2)
* Sed (v4.9)
* Sqlite3 (v3.41.2) - dynamic only
* Strace (v6.2)
* Tar (v1.34)
* Tcpdump (v4.99.4)
* Vim (v9.0.1447)
* Wget2 (v2.0.1) - dynamic only
* Xmlstarlet
* Xxd (v1.10)
* Zip (v3.0)
* Zsh (v5.9)
* Zstd (v1.5.5)

## Pulled from Offical Sources
* RClone (v1.62.2)

## Deprecated:
These are binaries that will be left "as is". I will not be updating them anymore
* Iftop (v1.0pre4) - dynamic only
* Wavemon (v0.9.3) - note that your kernel must have wireless extensions enabled (which most android ones don't). [See here](https://github.com/uoaerg/wavemon#dependencies) [and here](https://github.com/uoaerg/wavemon/blob/master/wavemon.1#L129) for more details

## Credits
* [Aria2](https://github.com/aria2/aria2)
* [Daniel Stenberg](https://curl.haxx.se)
* [Gavin Howard](https://github.com/gavinhoward/bc)
* [GNU](https://www.gnu.org/software)
* [Google](https://github.com/google/brotli)
* [Gordon Lyon](https://nmap.org)
* [Htop](https://github.com/hishamhm/htop)
* [Iftop](https://ex-parrot.com/psdw/iftop)
* [james34602](https://github.com/james34602)
* [Linux Kernel](https://www.kernel.org)
* [Mikhail Grushinskiy](http://xmlstar.sourceforge.net)
* [Nethogs](https://github.com/raboof/nethogs)
* [NixOS](https://nixos.org/patchelf.html)
* [Ogham](https://github.com/ogham/exa)
* [OhMyZsh](https://ohmyz.sh)
* [Partcyborg](https://github.com/Magisk-Modules-Repo/zsh_arm64)
* [RClone](https://rclone.org)
* [Sqlite3](https://sqlite.org/index.html)
* [Strace](https://github.com/strace/strace)
* [Tcpdump](https://www.tcpdump.org)
* [Uoaerg](https://github.com/uoaerg/wavemon)
* [Vim](https://github.com/vim/vim)
* [Wget2](https://gitlab.com/gnuwget/wget2)
* [Zsh](https://www.zsh.org)
* [Zstd](https://github.com/facebook/zstd)

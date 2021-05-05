# Cross Compiled Binaries for Android
This repo contains a variety of binaries cross compiled for android with Android NDK. All are static linked unless in a dynamic folder. Feel free to use them for whatever. Also contains some files for ccbins mod

## Binaries Build Script
You can find the build script for these in the [build_scripts folder](build_script).

## Currently includes:
* Aria2 (v1.35.0) - to use static linked without root, use `--async-dns --async-dns-server=<yourdnserver,yourotherdnsserver>` (not needed for dynamic linked)
  * For use in an installer zip - use static linked
  * For use on a device - use dynamic linked if on Oreo (API 26) or newer
* Bash (v5.1.8)
* Bc (v1.07.1)
* Brotli (v1.0.9)
* Coreutils (v8.32) - has selinux support, openssl support, and includes patches for advanced cp/mv (adds progress bar functionality)
* Cpio (v2.12) - v2.13 is bugged so staying with this version
* Curl (v7.76.1) - boringssl support and more - working ssl, to use static linked without root, use `--dns-servers <yourdnserver,yourotherdnsserver>` (not needed for dynamic linked)
  * For use in an installer zip - use static linked
  * For use on a device - use dynamic linked if on Oreo (API 26) or newer
* Diffutils (v3.7)
* Ed (v1.17)
* Exa (v0.10.1) - dynamic only
* Findutils (v4.8.0)
* Gawk (Awk) (v5.1.0)
* Grep (v3.6)
* Gzip (v1.10)
* Htop (v3.0.5)
* Iftop (v1.0pre4) - dynamic only
* Iw (v5.9)
* Keycheck
* Nano (v5.6.1)
* Nethogs (v0.8.6)
* Ncursesw (v6.2) - only terminfo files - needed for some binaries such as htop
* Nmap (v7.91) - dynamic only
* Openssl (v1.1.1k)
* Patch (v2.7.6)
* Patchelf (v0.12)
* Sed (v4.8)
* Sqlite3 (v3.35.5) - dynamic only
* Strace (v5.11)
* Tar (v1.34)
* Tcpdump (v4.99.0)
* Vim (v8.2.2785)
* Wavemon (v0.9.3) - note that your kernel must have wireless extensions enabled (which most android ones don't). [See here](https://github.com/uoaerg/wavemon#dependencies) [and here](https://github.com/uoaerg/wavemon/blob/master/wavemon.1#L129) for more details
* Xmlstarlet
* Xxd (v1.10)
* Zip (v3.0)
* Zsh (v5.8.0)
* Zstd (v1.4.9)

## Credits
* [Aria2](https://github.com/aria2/aria2)
* [Daniel Stenberg](https://curl.haxx.se)
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
* [Sqlite3](https://sqlite.org/index.html)
* [Strace](https://github.com/strace/strace)
* [Tcpdump](https://www.tcpdump.org)
* [Uoaerg](https://github.com/uoaerg/wavemon)
* [Vim](https://github.com/vim/vim)
* [Zsh](https://www.zsh.org)
* [Zstd](https://github.com/facebook/zstd)

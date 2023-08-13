#!/bin/bash

# Fixes:
# 1) %n issue due to these binaries using old gnulib (This was in Jan 2019: http://git.savannah.gnu.org/gitweb/?p=gnulib.git;a=commit;h=6c0f109fb98501fc8d65ea2c83501b45a80b00ab)
# 2) minus_zero duplication error in NDK
# 3) Bionic error fix in NDK
# 4) New syscall function has been added in coreutils 8.32 - won't compile with android toolchains - fix only needed for 64bit arch's oddly enough
# 5) Coreutils doesn't detect pcre2 related functions for whatever reason - ignore resulting errors - must happen for coreutils only (after gnulib)
# 6) Fix ncurses location issues
# 7) Can't detect pthread from ndk so clear any values set by configure
# 8) pthread_cancel not in ndk, use Hax4us workaround found here: https://github.com/axel-download-accelerator/axel/issues/150
# 9) Allow static compile (will compile dynamic regardless of flags without this patch), only needed for arm64 oddly
# 10) Specify that ncursesw is defined since clang errors out with ncursesw
# 11) Add needed include
# 12) Remove ether_ntohost - not present in ndk
# 13) pthread_create not detected for some reason, just force it through
# 14) Fix libnl/libm order (libnl should be before libm)
# 15) Specify arm ndk clang for m32 support
# 16) Use ndk's static_assert macro, strace's is different
# 17) Out of date automake in coreutils, update it here
# 18) Need to use host 'file' binary for test step
# 19) Remove uneeded step from Makefile, either won't work since we're cross compiling or not worth the effort of hacking it to work currently
# 20) Force pcre2 - compile doesn't do this for some reason
# 21) Remove reference to non-essential (I hope lol) macro that doesn't exist in ndk
# 22) Renameat2 was added in ndk 21, multiple definition with existing files/macro in patch. Either use an older ndk (like r20b) or ignore the errors
# 23) googletest dependency is not present in the aosp source version
# 24) Remove no longer supported macro (needed for newer version of autoconf)
# 25) Pthread inside ndk's libc rather than separate, create empty one to skirt around errors - https://stackoverflow.com/questions/57289494/ndk-r20-ld-ld-error-cannot-find-lpthread
# 26) Add support for boringssl AES-CTR (see here: https://fuchsia-review.googlesource.com/c/third_party/libssh2/+/23460/1/src/openssl.c#417) and add missing functions (present in openssl but not in boringssl) - modified from original source: https://github.com/egorovandreyrm/libssh_android_build_scripts
# 27) Quiche needs libdl and libmath libs specified and the configure arg pointed to the pkgconfig file location
# 28) Openssl needs libdl during static compiles
# 29) Replace deprecated (and removed since API 21) getdtablesize() with sysconf(_SC_OPEN_MAX). Strange because it's properly defined elsewhere
# 30) Remove duplicate definitions
# 31) ffsl not present in ndk, use __builtin_ffsl instead
# 32) time_t stops working after Jan 2038 error fix
# 33) Remove __GNUC_PREREQ sections, not in ndk so not needed
# 34) Fix bin path, pwcat segfaults, apply termux patches
# 35) Create missing file
# 36) Fix data home directory
# 37) Duplicate definition of time
# 38) Fix htoprc path
# 39) Missing libgcc rust workaround
# 40) Legacy Index doesn't exist in ndk, switch to strchr. Remove garbage collection - quad_t doesn't exists in ndk. See https://github.com/raboof/nethogs/issues/227
# 41) Apply termux patches, --disable-strip to prevent host "install" command to use "-s", which won't work for target binaries
# 42) Use ndk strtoimax, remove bash's strtoimax - ndk r25b+
# 43) Fix for syntax error
# 44) Remove duplicate definition, needed in ndk r25b+
# 45) ldl needs manually specified
# 46) x64 won't compile with simd-checksum
# 47) signed/unsigned int error fix

echored () {
	echo "${textred}$1${textreset}"
}
echogreen () {
	echo "${textgreen}$1${textreset}"
}
usage () {
  echo " "
  echored "USAGE:"
  echogreen "bin=      (aria2, bash, bc, bc-gh, boringssl, brotli, bzip2, c-ares, coreutils, cpio, cunit, curl, diffutils, ed, exa, findutils, freedup, gawk, gdbm, \
  gmp, grep, gzip, htop, iftop, jq, ldns, libedit, libexpat, libhsts, libiconv, libidn2, libmagic, libnl, libpcap, libpcapnl (libpcap w/ libnl), libpsl, libssh2, libssh2-alt, \
  libunistring, nano, ncurses, ncursesw, nethogs, nghttp2 (lib only), nmap, openssl, patch, patchelf, pcre, pcre2, quiche, rclone, readline, rsync, sed, selinux, sqlite, \
  strace, tar, tcpdump, tinyalsa, vim, wavemon, wget2, zlib, zsh, zstd)"
  echo "           For aria, curl, nmap, and wget2 dynamic link - all non-android libs are statically linked to make it much more portable"
  echo "           libssh2-alt = libssh2 with boringssl rather than openssl"
  echo "           Note that you can put as many of these as you want together as long as they're comma separated"
  echo "           Ex: bin=cpio,gzip,tar"
  echogreen "arch=     (Default: all) (all, arm, arm64, x86, x64)"
  echo "          Don't type this or set it to all to compile for all arches"
  echogreen "static=   (Default: true) (true, false)"
  echogreen "api=      (Default: 21 for dynamic, 33 for static) (21, 22, 23, 24, 26, 27, 28, 29, 30, 31, 32, 33)"
  echo " "
  echored "Coreutils Specific Options:"
  echogreen "sep=      (Default: false) (true, false) - Determines if coreutils builds as a single busybox-like binary or as separate binaries"
  echo " "
  exit 1
}
patch_file() {
  echogreen "Applying patch"
  local dest=$(basename $1)
  cp -f $1 $dest
  patch -p0 -i $dest
  [ $? -ne 0 ] && { echored "Patching failed! Did you verify line numbers? See README for more info"; exit 1; }
  return 0
}
apply_patches() {
  [ -d "$dir/patches/$bin" ] || return 0
  for i in $dir/patches/$bin/*; do
    local pfile=$(basename $i)
    cp -f $i $pfile
    [ "$bin" == "bash" ] && sed -i "s/4.4/$ver/g" $pfile
    patch -p0 -i $pfile
    [ $? -ne 0 ] && { echored "Patching failed!"; return 1; }
    rm -f $pfile
  done
}
gnu_patches() {
  echogreen "Applying patches"
  local pver=$(echo $ver | sed 's/\.//') url="$(dirname $url)/$bin-$ver-patches"
  for i in {001..050}; do
    wget $url/$bin$pver-$i 2>/dev/null
    if [ -f "$bin$pver-$i" ]; then
      patch -p0 -i $bin$pver-$i
      rm -f $bin$pver-$i
    else
      break
    fi
  done
  apply_patches
}
setup_ohmyzsh() {
  [ -d $prefix/etc/zsh ] && return 0
  mkdir -p $prefix/etc/zsh
  git clone https://github.com/ohmyzsh/ohmyzsh.git $prefix/etc/zsh/.oh-my-zsh
  cp $prefix/etc/zsh/.oh-my-zsh/templates/zshrc.zsh-template $prefix/etc/zsh/.zshrc
  sed -i -e "s|PATH=.*|PATH=\$PATH|" -e "s|ZSH=.*|ZSH=/system/etc/zsh/.oh-my-zsh|" -e "s|ARCHFLAGS=.*|ARCHFLAGS=\"-arch $arch\"|" $prefix/etc/zsh/.zshrc
}
build_bin() {
  # Versioning and overrides
  local bin=$1 ext ver url name flags alt=false
  [ "$2" ] && local arch=$2
  [ "$lapi" ] || lapi=$api
  # Set flags
  case $arch in
    arm64|aarch64) arch=aarch64; target_host=aarch64-linux-android; osarch=android-arm64; barch=arm64-v8a; GOARCH=arm64;;
    arm) arch=arm; target_host=arm-linux-androideabi; osarch=android-arm; barch=armeabi-v7a; GOARCH=arm; GOARM=7;;
    x64|x86_64) arch=x86_64; target_host=x86_64-linux-android; osarch=android-x86_64; barch=x86_64; GOARCH=amd64;;
    x86|i686) arch=i686; target_host=i686-linux-android; osarch=android-x86; barch=x86; GOARCH=386; flags="TIME_T_32_BIT_OK=yes ";;
    *) echored "Invalid arch: $arch!"; exit 1;;
  esac
  export AR=$target_host-ar
  export AS=$target_host-as
  export LD=$target_host-ld
  export RANLIB=$target_host-ranlib
  export STRIP=$target_host-strip
  export CC=$target_host-clang
  export CXX=$target_host-clang++
  export GCC=$target_host-gcc
  export GXX=$target_host-g++

  case $bin in
    "aria2") ver="release-1.36.0"; url="https://github.com/aria2/aria2"; [ $lapi -lt 26 ] && lapi=26;;
    "bash") ext=gz; ver="5.2"; url="gnu";;
    "bc") ext=gz; ver="1.07.1"; url="gnu";;
    "bc-gh") ver="6.6.0"; url="https://github.com/gavinhoward/bc bc-gh";;
    "bzip2") ext=gz; ver="1.0.8"; url="https://www.sourceware.org/pub/bzip2/bzip2-$ver.tar.$ext";;
    "boringssl") ver="f1c75347d"; url="https://github.com/google/boringssl";; # Keep consistent with quiche boringssl
    "brotli") ver="v1.0.9"; url="https://github.com/google/brotli";;
    "c-ares") ver="cares-1_19_1"; url="https://github.com/c-ares/c-ares";;
    "coreutils") ext=xz; ver="9.3"; url="gnu"; [ $lapi -lt 28 ] && lapi=28;;
    "cpio") ext=gz; ver="2.12"; url="gnu";;
    "cunit") ver="3.2.7"; url="https://gitlab.com/cunity/cunit";;
    "curl") ver="curl-8_2_1"; url="https://github.com/curl/curl"; [ $lapi -lt 26 ] && lapi=26;;
    "diffutils") ext=xz; ver="3.10"; url="gnu";;
    "ed") ext=lz; ver="1.19"; url="gnu";;
    "exa") ver="v0.10.1"; url="https://github.com/ogham/exa"; [ $lapi -lt 24 ] && lapi=24;;
    "findutils") ext=xz; ver="4.9.0"; url="gnu"; [ $lapi -lt 23 ] && lapi=23;;
    "freedup") ext=tgz; ver="1.6-3"; url="http://freedup.org/freedup_$ver-src.$ext";;
    "gawk") ext=xz; ver="5.2.2"; url="gnu"; $static || { [ $lapi -lt 26 ] && lapi=26; };;
    "gdbm") ext=gz; ver="1.23" url="gnu";;
    "gmp") ext=xz; ver="6.2.1"; url="https://mirrors.kernel.org/gnu/gmp/gmp-$ver.tar.$ext";;
    "grep") ext=xz; ver="3.11"; url="gnu"; [ $lapi -lt 23 ] && lapi=23;;
    "gzip") ext=xz; ver="1.12"; url="gnu";;
    "htop") ver="3.2.2"; url="https://github.com/htop-dev/htop"; [ $lapi -lt 25 ] && { $static || lapi=25; };;
    "iftop") ext=gz; ver="1.0pre4"; url="http://www.ex-parrot.com/pdw/iftop/download/iftop-$ver.tar.$ext"; [ $lapi -lt 28 ] && lapi=28;;
    "jq") ver="jq-1.6"; url="https://github.com/stedolan/jq";;
    "ldns") ext=gz; ver="1.8.3"; url="https://www.nlnetlabs.nl/downloads/ldns/ldns-$ver.tar.$ext";;
    "libedit") ext=gz; ver="20221030-3.1"; url="https://thrysoee.dk/editline/libedit-$ver.tar.$ext";;
    "libexpat") ver="R_2_5_0"; url="https://github.com/libexpat/libexpat";;
    "libhsts") ver="libhsts-0.1.0"; url="https://gitlab.com/rockdaboot/libhsts";;
    "libiconv") ext=gz; ver="1.17"; url="gnu";;
    "libidn2") ext=gz; ver="2.3.4"; url="https://ftp.gnu.org/gnu/libidn/libidn2-$ver.tar.$ext"; $static && [ $lapi -lt 26 ] && lapi=26;;
    "libmagic") ext=gz; ver="5.44"; url="ftp://ftp.astron.com/pub/file/file-$ver.tar.$ext";;
    "libnl") ext=gz; ver="3.2.25"; url="https://www.infradead.org/~tgr/libnl/files/libnl-$ver.tar.$ext"; [ $lapi -lt 26 ] && lapi=26;;
    "libpcap"|"libpcapnl") ver="1.10.3"; ver="a4ad1f2"; url="https://android.googlesource.com/platform/external/libpcap"; [ $lapi -lt 23 ] && lapi=23; [ "$bin" == "libpcapnl" ] && { bin=libpcap; alt=true; };;
    "libpsl") ver="0.21.2"; url="https://github.com/rockdaboot/libpsl"; [ $lapi -lt 26 ] && lapi=26;;
    "libssh2"|"libssh2-alt") ver="libssh2-1.10.0"; url="https://github.com/libssh2/libssh2"; [ "$bin" == "libssh2-alt" ] && { bin=libssh2; alt=true; };;
    "libunistring") ext=gz; ver="1.1"; url="gnu";;
    "nano") ext=xz; ver="7.2"; url="gnu";;
    "ncurses"|"ncursesw") ext=gz; ver="6.4"; url="gnu"; [ "$bin" == "ncursesw" ] && { bin=ncurses; alt=true; };;
    "nethogs") ver="v0.8.7"; url="https://github.com/raboof/nethogs"; $static || [ $lapi -ge 26 ] || lapi=26;;
    "nghttp2") ver="v1.55.1"; url="https://github.com/nghttp2/nghttp2";;
    "nmap") ext="tgz"; ver="7.93"; url="https://nmap.org/dist/nmap-$ver.$ext";;
    "openssl") ver="openssl-3.1.1"; url="https://github.com/openssl/openssl";;
    "patch") ext=xz; ver="2.7.6"; url="gnu";;
    "patchelf") ver="0.18"; url="https://github.com/NixOS/patchelf";;
    "pcre") ext=gz; ver="8.45"; url="https://sourceforge.net/projects/pcre/files/pcre/$ver/pcre-$ver.tar.$ext/download"; [ $lapi -lt 26 ] && lapi=26;;
    "pcre2") ver="pcre2-10.42"; url="https://github.com/PhilipHazel/pcre2"; [ $lapi -lt 26 ] && lapi=26;;
    "quiche") ver="0.17.2"; url="https://github.com/cloudflare/quiche";;
    "readline") ext=gz; ver="8.2"; url="gnu";;
    "rsync") ext=gz; ver="3.2.7"; url="https://download.samba.org/pub/rsync/src/rsync-$ver.tar.$ext";;
    "sed") ext=xz; ver="4.9"; url="gnu"; [ $lapi -lt 23 ] && lapi=23;;
    "selinux") ver="3.5"; url="https://github.com/SELinuxProject/selinux.git"; [ $lapi -lt 28 ] && lapi=28;;
    "sqlite") ext=gz; ver="3420000"; url="https://sqlite.org/2023/sqlite-autoconf-$ver.tar.$ext"; $static && [ $lapi -lt 26 ] && lapi=26;;
    "strace") ver="v6.4"; url="https://github.com/strace/strace";;
    "tar") ext=xz; ver="1.34"; url="gnu"; ! $static && [ $lapi -lt 28 ] && lapi=28;;
    "tcpdump") ver="tcpdump-4.99.4"; url="https://github.com/the-tcpdump-group/tcpdump"; $static || [ $lapi -ge 26 ] || lapi=26;;
    "tinyalsa") ver="v2.0.0"; url="https://github.com/tinyalsa/tinyalsa";;
    "vim") url="https://github.com/vim/vim";;
    "wavemon") ver="v0.9.3"; url="https://github.com/uoaerg/wavemon"; $static || [ $lapi -ge 26 ] || lapi=26;;
    "wget2") ver="v2.0.1"; url="https://gitlab.com/gnuwget/wget2"; [ $lapi -lt 28 ] && lapi=28;;
    "zlib") ver="v1.2.13"; url="https://github.com/madler/zlib";;
    "zsh") ext=xz; ver="5.9"; url="https://sourceforge.net/projects/zsh/files/zsh/$ver/zsh-$ver.tar.$ext/download";;
    "zstd") ver="v1.5.5"; url="https://github.com/facebook/zstd";;
    *) echored "Invalid binary specified!"; usage;;
  esac

  # Create needed symlinks
  for i in armv7a-linux-androideabi aarch64-linux-android x86_64-linux-android i686-linux-android; do
    [ "$i" == "armv7a-linux-androideabi" ] && j="arm-linux-androideabi" || j=$i
    ln -sf $toolchain/$i$lapi-clang $toolchain/$j-clang
    ln -sf $toolchain/$i$lapi-clang++ $toolchain/$j-clang++
    ln -sf $toolchain/$i$lapi-clang $toolchain/$j-gcc
    ln -sf $toolchain/$i$lapi-clang++ $toolchain/$j-g++
  done

  # Fetch source
  echogreen "Fetching $bin"
  cd $dir
  case "$url" in
    "gnu")
      url="https://ftp.gnu.org/gnu/$bin/$bin-$ver.tar.$ext"
      ;;
    "https://github.com/"*|"https://gitlab.com/"*|*"googlesource.com"*) 
      if [ -d $bin ]; then
        cd $bin
      else
        [ "$bin" == "quiche" ] && git clone --recursive $url || git clone $url
        cd $bin
        [ "$ver" ] && git checkout $ver 2>/dev/null
      fi
      ;;
  esac
  if [ "$dir" == "$PWD" ]; then
    rm -rf $bin
    name="$(basename $(echo "$url" | sed "s|download||"))"
    [ -f "$name" ] || wget -O $name $url
    tar -xf $name --transform s/$(echo $name | sed "s/.tar.$ext//")/$bin/
    mv -f $bin-$ver $bin 2>/dev/null
    cd $bin
  fi

  # Set other flags
  local origstatic=$static
  if $static; then
    local CFLAGS="-static -O2"
    local LDFLAGS="-static -s"
    [ "$prefix" ] || local prefix=$dir/build-static/$bin/$arch
    [ -f $dir/patches/ndk_static_patches/$bin.patch ] && patch_file $dir/patches/ndk_static_patches/$bin.patch
  else
    local CFLAGS='-O2 -fPIE -fPIC'
    local LDFLAGS='-s -pie'
    [ "$prefix" ] || local prefix=$dir/build-dynamic/$bin/$arch
  fi

  $first && { [ -d "$prefix" ] && { echogreen "$bin already built! Skipping !"; return 0; }; } || first=false

  echogreen "Compiling $bin version $ver for $arch api $lapi"
  case $bin in
    "aria2")
      static=true
      build_bin libexpat
      build_bin libssh2 # Also builds openssl
      build_bin sqlite
      $origstatic && build_bin c-ares || build_bin zlib # zlib.so dependency (but not required to compile - built-in to ndk) - may not be present in rom so we build it here
      cd $dir/$bin
      static=$origstatic
      if $static; then #25
        [ "$arch" == "armeabi-v7a" ] && export target_host=arm-linux-androideabi
        $AR cr $toolchain/../sysroot/usr/lib/$target_host/libpthread.a
        $AR cr $toolchain/../sysroot/usr/lib/$target_host/librt.a
        [ "$arch" == "armeabi-v7a" ] && export target_host=armv7a-linux-androideabi
        flags="--with-libcares ARIA2_STATIC=yes $flags"
      else
        flags="--without-libcares $flags"
        LDFLAGS="$LDFLAGS -static-libstdc++"
        flags="--disable-shared $flags"
        rm -f $prefix/lib/lib*.so $prefix/lib/lib*.so.[0-9]*
      fi
      autoreconf -fi || autoreconf -fi # fails the first time for some reason
      ./configure CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS -g -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls \
        --without-gnutls \
        --with-openssl \
        --with-sqlite3 \
        --without-libxml2 \
        --with-libexpat \
        --with-libz \
        --with-libssh2 \
        --with-ca-bundle='/system/etc/security/ca-certificates.crt'
      ;;
    "bash")
      $static && { flags="$flags--enable-static-link "; sed -i 's/-rdynamic//g' configure.ac; } #9
      sed -i '/strtoimax/Id' configure.ac #42
      sed -i '/strtoimax/d' Makefile.in #42
      sed -i -e 's/strtoimax.c strtoumax.c/strtoumax.c/' -e '/strtoimax/d' lib/sh/Makefile.in #42
      rm -f m4/strtoimax.m4 lib/sh/strtoimax.c #42
      gnu_patches || exit 1
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls \
        --without-bash-malloc \
        --enable-largefile \
        --enable-alias \
        --enable-readline \
        --enable-history \
        --enable-multibyte \
        --enable-job-control \
        --enable-array-variables \
        bash_cv_dev_fd=whacky \
        bash_cv_getcwd_malloc=yes \
        bash_cv_job_control_missing=present \
        bash_cv_sys_siglist=yes \
        bash_cv_func_sigsetjmp=present \
        bash_cv_unusable_rtsigs=no \
        ac_cv_func_mbsnrtowcs=no # bash_cv args from termux: https://github.com/termux/termux-packages/blob/master/packages/bash/build.sh
    sed -i 's/${LIBOBJDIR}mbschr$U.o ${LIBOBJDIR}strtoimax$U.o/${LIBOBJDIR}mbschr$U.o/' lib/sh/Makefile #42
      ;;
    "bc")
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
      --host=$target_host --target=$target_host \
      $flags--prefix=$prefix || { echored "Configure failed!"; exit 1; }
      sed -i -e '\|./fbc -c|d' -e 's|$(srcdir)/fix-libmath_h|cp -f ../../patches/bc_libmath.h $(srcdir)/libmath.h|' bc/Makefile
      ;;
    "bc-gh")
      CFLAGS="$(echo "$CFLAGS" | sed 's/-O2/-O3/') -flto" LDFLAGS="$LDFLAGS" HOSTCC=clang ./configure \
      --prefix=$prefix \
      --disable-nls \
      --disable-man-pages
      ;;
    "boringssl")
      cd src
      wget https://github.com/google/googletest/archive/release-1.12.1.tar.gz #23
      tar -xf release-1.12.1.tar.gz
      cp -rf googletest-release-1.12.1/googletest third_party
      rm -rf release-1.12.1.tar.gz googletest-release-1.12.1
      $static && flags="-DCMAKE_EXE_LINKER_FLAGS='-static' "
      mkdir -p build
      cd build
      cmake -DANDROID_ABI=$barch \
        -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake \
        -DANDROID_NATIVE_API_LEVEL=$lapi \
        -DANDROID_PLATFORM=$lapi \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$prefix \
        -DBUILD_SHARED_LIBS=0 \
        $flags-GNinja ..
      ninja
      ;;
    "brotli")
      $static && flags="--disable-shared $flags"
      ./bootstrap
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix
      ;;
    "bzip2")
      sed -i -e '/# To assist in cross-compiling/,/RANLIB=/d' -e "s/LDFLAGS=/LDFLAGS=$LDFLAGS /" -e "s/CFLAGS=/CFLAGS=$CFLAGS /" -e "s|^PREFIX=.*|PREFIX=$prefix|" -e 's/bzip2recover test/bzip2recover/' Makefile
      ;;
    "c-ares")
      # $static && flags="--disable-shared $flags"
      # autoreconf -fi
      # ./configure CFLAGS="$CFLAGS" CPPFLAGS="-DANDROID" LDFLAGS="$LDFLAGS" \
      #   --host=$target_host --target=$target_host \
      #   $flags--prefix=$prefix
      $static && flags="-DCARES_STATIC=1 -DCARES_SHARED=0 $flags" || flags="-DCARES_STATIC=1 $flags"
      mkdir build
      cd build
      cmake -DANDROID_ABI=$barch \
        -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake \
        -DANDROID_NATIVE_API_LEVEL=$lapi \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$prefix \
        $flags-GNinja ..
      ninja
      ;;
    "coreutils")
      build_bin openssl
      build_bin selinux
      cd $dir/$bin
      autoreconf -fi #17
      patch_file $dir/patches/coreutils.patch #32
      $sep || flags="$flags--enable-single-binary=symlinks "
      sed -i 's/#ifdef __linux__/#ifndef __linux__/g' src/ls.c #4
      sed -i "s/USE_FORTIFY_LEVEL/BIONIC_FORTIFY/g" lib/cdefs.h #3
      sed -i "s/USE_FORTIFY_LEVEL/BIONIC_FORTIFY/g" lib/stdio.in.h #3
      sed -i -e '/if (!num && negative)/d' -e "/return minus_zero/d" -e "/DOUBLE minus_zero = -0.0/d" lib/strtod.c #2
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls \
        --with-openssl=yes \
        --with-linux-crypto \
        --enable-no-install-program=stdbuf \
        ac_year2038_required=no || { echored "Configure failed!"; exit 1; } #32
      sed -i "1iLDFLAGS += -Wl,--unresolved-symbols=ignore-in-object-files" src/local.mk #5
      sed -i "/## begin gnulib module copy-file-range/,/## end   gnulib module copy-file-range/d" lib/gnulib.mk #44
      ;;
    "cpio")
      sed -i 's/!defined __UCLIBC__)/!defined __UCLIBC__) || defined __ANDROID__/' gnu/vasnprintf.c #1
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls
      ;;
    "cunit")
      $static && flags="-DCMAKE_EXE_LINKER_FLAGS='-static' "
      mkdir -p build
      cd build
      cmake -DANDROID_ABI=$barch \
            -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake \
            -DANDROID_NATIVE_API_LEVEL=$lapi \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX:PATH=$prefix \
            $flags-GNinja ..
      ninja
      ;;
    "curl")
      static=true
      build_bin brotli
      build_bin zstd
      build_bin libpsl # Also builds libidn2
      build_bin nghttp2
      build_bin libssh2-alt # Also builds boringssl
      build_bin quiche
      $origstatic && build_bin c-ares || build_bin zlib # zlib.so dependency (but not required to compile - built-in to ndk) - may not be present in rom so we build it here
      cd $dir/$bin
      static=$origstatic
      [ $lapi -lt 28 ] && LIBS="-lidn2 -lunistring -liconv -ldl -lm" || LIBS="-lidn2 -lunistring -ldl -lm" #27
      flags="--disable-shared $flags"
      $static && { LDFLAGS="$LDFLAGS -all-static"; flags="--enable-ares=$prefix $flags"; } || rm -f $prefix/lib/lib*.so $prefix/lib/lib*.so.[0-9]*
      sed -i "s/\[unreleased\]/$(date +"%Y-%m-%d")/" include/curl/curlver.h
      sed -i "s/Release-Date/Build-Date/g" src/tool_help.c
      autoreconf -fi
      ./configure CFLAGS="$CFLAGS" CPPFLAGS="$CFLAGS -I$prefix/include -DANDROID" LDFLAGS="$LDFLAGS -L$prefix/lib" LIBS="$LIBS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --enable-optimize \
        --enable-symbol-hiding \
        --disable-manual \
        --enable-threaded-resolver \
        --enable-alt-svc \
        --enable-hsts \
        --with-openssl=$prefix \
        --with-brotli=$prefix \
        --with-zstd=$prefix \
        --with-ca-path=/system/etc/security/cacerts \
        --with-nghttp2=$prefix \
        --with-libidn2=$prefix \
        --with-libssh2=$prefix \
        --with-quiche=$prefix/lib/pkgconfig #27
      [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
      sed -i -e "s/#define OS .*/#define OS \"ANDROID\"/" -e "s/#define SELECT_TYPE_RETV int/#define SELECT_TYPE_RETV ssize_t/" -e "s|/\* #undef _FILE_OFFSET_BITS \*/|#define _FILE_OFFSET_BITS 64|" lib/curl_config.h
      ;;
    "diffutils")
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls
      ;;
    "ed")
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        $flags--prefix=$prefix \
        CC=$GCC CXX=$GXX
      ;;
    "exa")
      build_bin zlib # libz.so is a dependency
      cd $dir/$bin
      [ "$target_host" == "arm-linux-androideabi" ] && local target_host="armv7-linux-androideabi"
      cargo ndk -t $barch -p $lapi -- build --release -j $jobs
      # cargo b --release --target $target_host -j $jobs
      [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
      mkdir -p $prefix/bin
      cp -f $dir/$bin/target/$target_host/release/exa $prefix/bin/exa
      ;;
    "findutils")
      [ "$arch" == "i686" ] && flags="--disable-year2038 $flags" #32
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=/system \
        --disable-nls \
        --sbindir=/system/bin \
        --libexecdir=/system/bin \
        --datarootdir=/system/usr/share \
        --localstatedir=/data/local/tmp || { echored "Configure failed!"; exit 1; }
      $static || sed -i -e "/#ifndef HAVE_ENDGRENT/,/#endif/d" -e "/#ifndef HAVE_ENDPWENT/,/#endif/d" -e "/endpwent/d" -e "/endgrent/d" find/parser.c
      ;;
    "freedup")
      # no configure needed
      ;;
    "gawk")
      build_bin readline
      cd $dir/$bin
      patch_file $dir/patches/gawk.patch #34
        ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls \
        --with-readline=$prefix
      ;;
    "gdbm")
        build_bin readline # Also builds ncurses which is required for this binary
        cd $dir/$bin
        ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
          --host=$target_host --target=$target_host \
          $flags--prefix=$prefix \
          --disable-nls \
          --enable-libgdbm-compat
      ;;
    "gmp")
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix
      ;;
    "grep")
      build_bin pcre2
      cd $dir/$bin
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls \
        --enable-perl-regexp
      ;;
    "gzip")
      sed -i 's/!defined __UCLIBC__)/!defined __UCLIBC__) || defined __ANDROID__/' lib/vasnprintf.c #1
      [ "$arch" == "i686" ] && flags="--disable-year2038 $flags" #32
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix
      ;;
    "htop")
      build_bin ncursesw
      cd $dir/$bin
      ./autogen.sh
      $static && flags="--enable-static $flags"
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" LIBS="-ldl" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --enable-unicode \
        ac_cv_lib_ncursesw6_addnwstr=yes #45
      $static && sed -i "/rdynamic/d" Makefile.am #9
      sed -i 's/ ffsl/ __builtin_ffsl/' linux/LinuxProcessList.c #31
      sed -i 's|/.config|/data/local|g' Settings.c #38
      ;;
    "iftop")
      build_bin libpcap
      build_bin ncurses
      cd $dir/$bin
      echo '#include <ncurses/curses.h>' > $prefix/include/ncurses.h #6
      cp -f $prefix/include/ncurses.h $prefix/include/curses.h #6
      if [ ! "$(grep 'Bpthread.h' iftop.c)" ]; then
        sed -i '/test $thrfail = 1/ithrfail=0\nCFLAGS="$oldCFLAGS"\nLIBS="$oldLIBS"' configure #7
        cp -f $dir/patches/Bpthread.h Bpthread.h #8
        sed -i '/pthread.h/a#include <Bpthread.h>' iftop.c #8
      fi
      $static && sed -i "s/cross_compiling=no/cross_compiling=yes/" configure
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --with-libpcap=$prefix \
        --with-resolver=netdb
      ;;
    "jq")
      $static && LDFLAGS="$LDFLAGS -all-static"
      git submodule update --init
      autoreconf -fi
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --with-oniguruma=builtin
      ;;
    "ldns")
      build_bin openssl
      cd $dir/$bin
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --with-ssl=$prefix
      ;;
    "libedit")
      build_bin ncursesw
      cd $dir/$bin
      echo '#include <ncursesw/curses.h>' > $prefix/include/ncurses.h #6
      for i in form menu ncurses ncurses++ panel; do
        cp -f $prefix/lib/lib$i\w.a $prefix/lib/lib$i.a 2>/dev/null
        cp -f $prefix/lib/lib$i\w_g.a $prefix/lib/lib$i\_g.a 2>/dev/null
        cp -f $prefix/lib/lib$i\w*.so $prefix/lib/lib$i.so 2>/dev/null
        cp -f $prefix/lib/lib$i\w_g.so $prefix/lib/lib$i\_g.so 2>/dev/null
      done
      ./configure CFLAGS="$CFLAGS -I$prefix/include -D__STDC_ISO_10646__=201103L -DNBBY=CHAR_BIT" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix
      patch_file $dir/patches/libedit.patch
      ;;
    "libexpat")
      cd expat
      ./buildconf.sh
      $static && flags="--disable-shared $flags"
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix
      ;;
    "libhsts")
      sed -i '/AX_CHECK_COMPILE_FLAG/d' configure.ac #43
      autoreconf -fi
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls
      ;;
    "libiconv")
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls
      ;;
    "libidn2")
      build_bin libunistring
      cd $dir/$bin
      [ $lapi -lt 28 ] && flags="--with-libiconv-prefix=$prefix $flags"
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib -Wl,-rpath=$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls \
        --with-libunistring-prefix=$prefix
      ;;
    "libmagic")
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-xzlib \
        --disable-bzlib \
        --disable-zlib
      sed -i "s|^FILE_COMPILE =.*|FILE_COMPILE = $(which file)|" magic/Makefile # 18
      ;;
    "libnl")
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-pthreads
      ;;
    "libpcap")
      $alt && build_bin libnl || flags="--without-libnl $flags"
      cd $dir/$bin
      $static && flags="$flags--disable-shared "
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --with-pcap=linux 
      ;;
    "libpsl")
      build_bin libidn2
      cd $dir/$bin
      ./autogen.sh
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib -Wl,-rpath=$prefix/lib" \
        --host=$target_host --target=$target_host \
        --prefix=$prefix \
        --disable-nls
      ;;
    "libssh2")
      if $alt; then
        build_bin boringssl
        cp -f $dir/patches/ssh-boringssl-compat.c $dir/libssh2/src/ssh-boringssl-compat.c #26
      else
        build_bin openssl
      fi
      cd $dir/$bin
      patch_file $dir/patches/$bin.patch #26
      sed -i '/m4_undefine/d' configure.ac #24
      autoreconf -fi
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --enable-hidden-symbols \
        --disable-examples-build \
        --with-crypto=openssl \
        --with-libssl-prefix=$prefix
      ;;
    "libunistring")
      if [ $lapi -lt 28 ]; then
        build_bin libiconv
        cd $dir/$bin
        flags="--with-libiconv-prefix=$prefix $flags"
      fi
      $static && flags="--disable-shared $flags"
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix
      ;;
    "nano")
      build_bin libmagic
      build_bin ncursesw
      cd $dir/$bin
      # Workaround no longer needed, kept in case it's needed again
      # wget -O - "https://kernel.googlesource.com/pub/scm/fs/ext2/xfstests-bld/+/refs/heads/master/android-compat/getpwent.c?format=TEXT" | base64 --decode > src/getpwent.c
      # wget -O src/pty.c https://raw.githubusercontent.com/CyanogenMod/android_external_busybox/cm-13.0/android/libc/pty.c
      # sed -i 's|int ptsname_r|//hack int ptsname_r(int fd, char* buf, size_t len) {\nint bb_ptsname_r|' src/pty.c
      # sed -i "/#include \"nano.h\"/a#define ptsname_r bb_ptsname_r\n//#define ttyname bb_ttyname\n#define ttyname_r bb_ttyname_r" src/proto.h
      $static || flags="ac_cv_header_glob_h=no $flags"
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls --enable-altrcname="/system/etc/nanorc" || { echored "Configure failed!"; exit 1; }
      sed -i '/#if defined(HAVE_NCURSESW_NCURSES_H)/i#define HAVE_NCURSESW_NCURSES_H' src/definitions.h #10
      ;;
    "ncurses")
      $alt && flags="--enable-widec $flags"
      [ "$(echo $prefix | awk -F/ '{print $(NF-1)}')" == "tmux" ] && flags="--with-termlib $flags"
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls \
        --disable-stripping \
        --without-manpages
        # --enable-pc-files --with-pkg-config-libdir=$prefix/lib/pkgconfig
      ;;
    "nethogs")
      build_bin libpcap
      build_bin ncurses
      cd $dir/$bin
      echo '#include <ncurses/curses.h>' > $prefix/include/ncurses.h #6
      sed -i -e "s/decpcap_test test/decpcap_test/g" -e "1aexport PREFIX := $prefix\nexport CFLAGS := $CFLAGS -I$prefix/include\nexport CXXFLAGS := \${CFLAGS}\nexport LDFLAGS := $LDFLAGS -L$prefix/lib" Makefile # 19
      patch_file $dir/patches/nethogs.patch #40
      ;;
    "nghttp2")
      build_bin cunit
      cd $dir/$bin
      $static && flags="--disable-shared $flags"
      autoreconf -fi
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --without-systemd \
        --enable-lib-only
      ;;
    "nmap")
      static=true
      build_bin zlib
      build_bin openssl
      cd $dir/$bin
      static=$origstatic
      flags="--disable-shared $flags"
      $static && flags="--enable-static $flags" || LDFLAGS="$LDFLAGS -static-libstdc++"
      [ "$arch" == "i686" ] && LDFLAGS="$LDFLAGS -Wl,--allow-multiple-definition"
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" LIBS="-ldl" \
        --host=$target_host \
        $flags--prefix=/system \
        --sbindir=/system/bin \
        --libexecdir=/system/bin \
        --datarootdir=/system/usr/share \
        --disable-nls \
        --without-ndiff \
        --without-zenmap \
        --with-openssl=$prefix \
        --with-libpcap=included \
        --with-libpcre=included \
        --with-libssh2=included \
        --with-libz=$prefix \
        --with-libdnet=included \
        --with-liblua=included \
        --with-liblinear=included
      ;;
    "openssl")
      cd $dir/$bin
      if $static; then
        sed -i "/#if \!defined(_WIN32)/,/#endif/d" fuzz/client.c #37
        sed -i "/#if \!defined(_WIN32)/,/#endif/d" fuzz/server.c #37
        flags="-static threads $flags"
      else
        flags="shared $flags"
      fi
      ./Configure $flags$osarch \
        -D__ANDROID_API__=$lapi \
        --prefix=$prefix
      ;;
    "patch") #22
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS -Wl,--allow-multiple-definition" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix
      ;;
    "patchelf")
      ./bootstrap.sh
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix
      ;;
    "pcre")
      build_bin bzip2
      build_bin readline # comment out this and the libreadline flag to get rid of the minapi of 26 requirement
      cd $dir/$bin
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host \
        $flags--prefix= \
        --enable-unicode-properties \
        --enable-jit \
        --enable-pcre16 \
        --enable-pcre32 \
        --enable-pcregrep-libz \
        --enable-pcregrep-libbz2 \
        --enable-pcre2test-libreadline
      ;;
    "pcre2")
      build_bin bzip2
      build_bin readline # comment out this and the libreadline flag to get rid of the minapi of 26 requirement
      cd $dir/$bin
      ./autogen.sh
      $static && flags="--disable-shared $flags"
      ./configure CFLAGS="-O2 -fPIE -fPIC -I$prefix/include" LDFLAGS="-O2 -s -L$prefix/lib" \
        --host=$target_host \
        $flags--prefix= \
        --enable-unicode-properties \
        --enable-fuzz-support \
        --enable-jit \
        --enable-pcre2grep-libz \
        --enable-pcre2grep-libbz2 \
        --enable-pcre2test-libreadline
      ;;
    "quiche")
      [ "$target_host" == "arm-linux-androideabi" ] && local target_host="armv7-linux-androideabi"
      cargo ndk -t $barch -p $lapi -- build --release --features ffi,pkg-config-meta,qlog
      # cargo build --release --target $target_host -j $jobs --features ffi,pkg-config-meta,qlog
      [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
      mkdir -p $prefix/include $prefix/lib/pkgconfig 2>/dev/null
      # cp -rf deps/boringssl/src/include $prefix/
      cp -f quiche/include/quiche.h $prefix/include/quiche.h
      # cp -f $(find target/$target_host/release -name libcrypto.a -o -name libssl.a) target/$target_host/release/libquiche* $prefix/lib/
      cp -f target/$target_host/release/libquiche* $prefix/lib/
      cp -f target/$target_host/release/quiche.pc $prefix/lib/pkgconfig/quiche.pc
      sed -i -e "s|=.*/quiche/include|=$prefix/include|" -e "s|=.*/quiche/target/.*|=$prefix/lib|" $prefix/lib/pkgconfig/quiche.pc
      ;;
    "readline")
      build_bin ncurses
      cd $dir/$bin
      gnu_patches || exit 1      
      $static && flags="--disable-shared $flags"
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --with-curses
      ;;
    "rsync")
      build_bin zstd
      build_bin openssl
      cd $dir/$bin
      [ "$arch" == "x86_64" ] && flags="--disable-roll-simd $flags" #46
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-xxhash \
        --disable-lz4
      ;;
    "sed")
      sed -i "s/USE_FORTIFY_LEVEL/BIONIC_FORTIFY/g" lib/cdefs.h; sed -i "s/USE_FORTIFY_LEVEL/BIONIC_FORTIFY/g" lib/stdio.in.h #3
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls
      ;;
    "selinux")
      build_bin pcre2
      cd $dir/$bin
      sed -i "s/libsemanage .*//" Makefile # 19, libsemanage requires libaudit which ndk doesn't have
      sed -i "s/^USE_PCRE2 ?= n/USE_PCRE2 ?= y/" libselinux/Makefile # 20
      sed -i "s/ \&\& strverscmp(uts.release, \"2.6.30\") < 0//" libselinux/src/selinux_restorecon.c # 21
      sed -i 's/versionsort/alphasort/g' libsemanage/src/direct_api.c
      for i in $(find . -type f -name 'Makefile'); do sed -i '/PREFIX ?=/d' $i; done
      ;;
    "sqlite")
      build_bin ncurses
      cd $dir/$bin
      $static && flags="--disable-shared --enable-static-shell $flags"
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix
      ;;
    "strace")
      [ "$arch" == "aarch64" ] && flags="ac_cv_prog_CC_FOR_M32=arm-linux-androideabi-clang $flags" #15
      ./bootstrap
      patch_file $dir/patches/strace.patch #16, #30
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --enable-mpers=m32
      ;;
    "tar")
      sed -i 's/!defined __UCLIBC__)/!defined __UCLIBC__) || defined __ANDROID__/' gnu/vasnprintf.c #1
      sed -i "s/USE_FORTIFY_LEVEL/BIONIC_FORTIFY/g" gnu/cdefs.h #3
      sed -i "s/USE_FORTIFY_LEVEL/BIONIC_FORTIFY/g" gnu/stdio.in.h #3
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls 
      ;;
    "tcpdump")
      build_bin openssl 
      build_bin libpcap
      cd $dir/$bin
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" LIBS="-ldl" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix #28
      ;;
    "tinyalsa")
      $static && flags="-DCMAKE_EXE_LINKER_FLAGS='-static' -DBUILD_SHARED_LIBS=0 "
      mkdir -p build
      cd build
      sed -i 's/ i < num_read/ (unsigned)i < num_read/g' ../utils/tinywavinfo.c #47
      cmake -DANDROID_ABI=$barch \
            -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake \
            -DANDROID_NATIVE_API_LEVEL=$lapi \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX:PATH=$prefix \
            -DTINYALSA_BUILD_EXAMPLES=OFF \
            $flags-GNinja ..
      ninja
      ;;
    "vim")
      build_bin ncursesw
      cd $dir/$bin
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls \
        --with-tlib=ncursesw \
        --without-x \
        --with-compiledby=Zackptg5 \
        --enable-gui=no \
        --enable-multibyte \
        --enable-terminal \
        remove_size \
        ac_cv_sizeof_int=4 \
        vim_cv_getcwd_broken=no \
        vim_cv_memmove_handles_overlap=yes \
        vim_cv_stat_ignores_slash=yes \
        vim_cv_tgetent=zero \
        vim_cv_terminfo=yes \
        vim_cv_toupper_broken=no \
        vim_cv_tty_group=world
      ;;
    "wavemon")
      build_bin ncursesw
      build_bin libpcapnl
      cd $dir/$bin
      sed -i -e "s/ncurses.h //" -e "s/ ether_ntohost//" configure.ac #6,12
      ./config/bootstrap # Recreate configure with changes above
      cp -f $dir/patches/Bpthread.h . #8
      sed -i '/#include <stdio.h>/i#include "Bpthread.h"' wavemon.h #8
      sed -i '/#include <stdbool.h>/a#include <net/ethernet.h>' iw_nl80211.h #11
      sed -i '/ether_ntohost/,/return hostname/d' utils.c #12
      patch_file $dir/patches/wavemon.patch #6
      sed -i -e 's/uninstall //' -e 's/@LIBS@ @LIBNL3_LIBS@/@LIBNL3_LIBS@ @LIBS@/' Makefile.in #14, Prevent output from getting deleted with distclean
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" CPPFLAGS="$CFLAGS -I$prefix/include" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        ac_cv_lib_pthread_pthread_create=yes #13
      ;;
    "wget2")
      static=true
      build_bin openssl
      build_bin libpsl # Also builds libidn2
      build_bin nghttp2
      build_bin brotli
      build_bin zstd
      build_bin pcre2 # Also builds bzip2
      build_bin libhsts
      $origstatic || build_bin zlib
      cd $dir/$bin
      static=$origstatic
      flags="--disable-shared $flags"
      $static && LDFLAGS="$LDFLAGS -all-static" || rm -f $prefix/lib/lib*.so $prefix/lib/lib*.so.[0-9]*
      sed -i 's|%s/.local/share|/sdcard|' src/options.c #36
      # Need --ca-certificate=<ca-certificates.crt from aria2> OR --ca-directory works if files in it processed to only have cert portion
      ./bootstrap
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls \
        --disable-doc \
        --enable-threads=posix \
        --with-bzip2 \
        --without-libmicrohttpd \
        --without-lzma \
        --without-gpgme \
        --with-ssl=openssl \
        --with-openssl=yes \
        LIBHSTS_LIBS="-L$prefix/lib"
      ;;
    "zlib")
      $static && flags="--static " || flags=""
      ./configure $flags--prefix=$prefix
      ;;
    "zsh")
      build_bin pcre
      build_bin gdbm
      cd $dir/$bin
      setup_ohmyzsh
      sed -i "/exit 0/d" Util/preconfig
      . Util/preconfig
      sed -i -e "/trap 'save=0'/azdmsg=$zd\nmkdir -p $zd" -e "/# Substitute an initial/,/# Don't run if we can't write to \$zd./d" Functions/Newuser/zsh-newuser-install
      $static && flags="--disable-dynamic --disable-dynamic-nss $flags"
      ./configure \
        --host=$target_host --target=$target_host \
        --enable-cflags="$CFLAGS -I$prefix/include" \
        --enable-ldflags="$LDFLAGS -L$prefix/lib" \
        $flags--prefix=/system \
        --bindir=/system/bin \
        --datarootdir=/system/usr/share \
        --disable-restricted-r \
        --disable-runhelpdir \
        --enable-zshenv=/system/etc/zsh/zshenv \
        --enable-zprofile=/system/etc/zsh/zprofile \
        --enable-zlogin=/system/etc/zsh/zlogin \
        --enable-zlogout=/system/etc/zsh/zlogout \
        --enable-multibyte \
        --enable-pcre \
        --enable-gdbm \
        --enable-site-fndir=/system/usr/share/zsh/functions \
        --enable-fndir=/system/usr/share/zsh/functions \
        --enable-function-subdirs \
        --enable-scriptdir=/system/usr/share/zsh/scripts \
        --enable-site-scriptdir=/system/usr/share/zsh/scripts \
        --enable-etcdir=/system/etc \
        --libexecdir=/system/bin \
        --sbindir=/system/bin \
        --sysconfdir=/system/etc
      ;;
    "zstd")
      cd build
      $static && flags="-DCMAKE_EXE_LINKER_FLAGS='-static' "
      cmake -DANDROID_ABI=$barch \
        -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake \
        -DANDROID_PLATFORM=android-$lapi \
        -DANDROID_TOOLCHAIN=clang \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$prefix \
        -DZSTD_MULTITHREAD_SUPPORT=enabled \
        -DZSTD_LEGACY_SUPPORT=1 \
        $flags-G"Unix Makefiles" cmake
      make -j$JOBS
      ;;
  esac
  [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }

  if [ "$bin" != "exa" ] && [ "$bin" != "quiche" ]; then
    case "$bin" in
      "bc-gh") make -j$jobs # Running just make install will error out
               [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
               make install -j$jobs
               ;;
      "boringssl") mkdir -p $prefix/lib
                   cp -f ssl/libssl.a crypto/libcrypto.a decrepit/libdecrepit.a $prefix/lib/
                   cp -rf ../include $prefix/
                   ;;
      "c-ares") ninja install
                $static || cp $prefix/lib/libcares_static.a $prefix/lib/libcares.a
                ;;
      "cunit"|"tinyalsa") ninja install
               ;;
      "findutils") make install -j$jobs DESTDIR=$prefix
                    [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
                    mv -f $prefix/system/* $prefix
                    rm -rf $prefix/sdcard $prefix/system
                    sed -i -e "s|/usr/.*bin|/system/bin|g" -e 's|SHELL=".*"|SHELL="/system/bin/sh"|' $prefix/bin/updatedb
                    ;;
      "freedup") make freedup -j$JOBS PREFIX=$prefix LDFLAGS=$LDFLAGS
                [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
                 install -D freedup $prefix/bin/freedup
                ;;
      "libnl") make install # Using multiple cores causes weird font glitch in terminal
               [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
               ;;
      "nano") make install -j$jobs
              [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
              rm -rf $prefix/share/nano; mkdir $prefix/usr; mv -f $prefix/share $prefix/usr/share
              git clone https://github.com/scopatz/nanorc $prefix/usr/share/nano
              rm -rf $prefix/usr/share/nano/.git; find $prefix/usr/share/nano -type f ! -name '*.nanorc' -delete
              ;;
      "nmap") make install -j$jobs DESTDIR=$prefix
              [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
              cp -rf $prefix/system/* $prefix; rm -rf $prefix/system
              ;;
      "openssl") make -j$jobs # Running just make install_sw will error out
                  [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
                  make install_sw -j$jobs
                  ;;
      "pcre"|"pcre2") make install -j$jobs DESTDIR=$prefix
                      [ $? -eq 0 ] || { echored "Build failed!"; exit 1; };;
      "selinux") make install -j$jobs DESTDIR=$prefix prefix= \
                  CFLAGS="-O2 -fPIE -fPIC -I$prefix/include \
                  -DNO_PERSISTENTLY_STORED_PATTERNS -D_GNU_SOURCE -DUSE_PCRE2 -DANDROID_HOST" \
                  LDFLAGS="-s -pie -L$prefix/lib -lpcre2-8"
                  [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
                  cp -rf $prefix/share $prefix/usr/; rm -rf $prefix/share
                  mv -f $prefix/sbin/* $prefix/bin/; rm -rf $prefix/sbin
                  ;;
      "vim") make VIMRCLOC=/system/usr/share/vim VIMRUNTIMEDIR=/system/usr/share/vim/vim90 -j$jobs
             make install -j$jobs
             [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
             ;;
      "zsh") make install -j$jobs DESTDIR=$prefix
             [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
             cp -rf $prefix/system/* $prefix/; rm -rf $prefix/system
             ! $static && [ "$arch" == "aarch64" -o "$arch" == "x86_64" ] && mv -f $dest/$arch/lib $dest/$arch/lib64
            ;;
      "zstd") make install -j$jobs
              [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
              ;;
      *) make install -j$jobs
         [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
         ;;
    esac
    if [ "$bin" != "curl" ] && grep -a '^distclean:' Makefile 2>/dev/null; then
      make distclean
    else
      make clean
    fi
  fi
  if [[ "$url" == "https://github.com/"* ]] || [[ "$url" == "https://gitlab.com/"* ]] || [[ "$url" == *"googlesource.com"* ]]; then
    git clean -dxf 2>/dev/null
    git reset --hard 2>/dev/null
  fi
  $STRIP $prefix/*bin/* 2>/dev/null
  echogreen "$bin built sucessfully and can be found at: $prefix"
}

textreset=$(tput sgr0)
textgreen=$(tput setaf 2)
textred=$(tput setaf 1)
dir=$PWD
ndk=r25c #LTS
static=true
sep=false
OIFS=$IFS; IFS=\|;
while true; do
  case "${1,,}" in
    -h|--help) usage;;
    "") shift; break;;
    api=*|static=*|bin=*|arch=*|sep=*) eval $(echo "${1,,}" | sed -e 's/=/="/' -e 's/$/"/' -e 's/,/ /g'); shift;;
    *) echored "Invalid option: $1!"; usage;;
  esac
done
IFS=$OIFS
[ -z "$arch" -o "$arch" == "all" ] && arch="arm arm64 x86 x64"

case $api in
  21|22|23|24|26|27|28|29|30|31|32|33) ;;
  *) $static && api=33 || api=21
     echogreen "Setting api to $api";;
esac

if [ -f /proc/cpuinfo ]; then
  jobs=$(grep flags /proc/cpuinfo | wc -l)
elif [ ! -z $(which sysctl) ]; then
  jobs=$(sysctl -n hw.ncpu)
else
  jobs=2
fi

# Set up Android NDK
ndknum=$(echo $ndk | sed 's/[a-zA-Z]*//g')
echogreen "Fetching Android NDK $ndk"
if [ $ndknum -ge 23 ]; then
  [ -f "android-ndk-$ndk-linux.zip" ] || wget https://dl.google.com/android/repository/android-ndk-$ndk-linux.zip
  [ -d "android-ndk-$ndk" ] || unzip -qo android-ndk-$ndk-linux.zip
else
  [ -f "android-ndk-$ndk-linux-x86_64.zip" ] || wget https://dl.google.com/android/repository/android-ndk-$ndk-linux-x86_64.zip
  [ -d "android-ndk-$ndk" ] || unzip -qo android-ndk-$ndk-linux-x86_64.zip
fi
export ANDROID_NDK_HOME=$dir/android-ndk-$ndk
export toolchain=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin
export ANDROID_NDK_ROOT=$ANDROID_NDK_HOME
export PATH=$toolchain:$PATH
# Create needed symlinks
if [ $ndknum -ge 23 ]; then
  for i in aarch64-linux-android arm-linux-androideabi x86_64-linux-android i686-linux-android; do
    echo 'INPUT(-lunwind)' > $toolchain/../sysroot/usr/lib/$i/libgcc.a #39
    ln -sf $toolchain/llvm-ar $toolchain/$i-ar
    ln -sf $toolchain/ld $toolchain/$i-ld
    ln -sf $toolchain/llvm-ranlib $toolchain/$i-ranlib
    ln -sf $toolchain/llvm-strip $toolchain/$i-strip
  done
fi
for i in ar as ld ranlib strip clang gcc clang++ g++; do
  ln -sf $toolchain/arm-linux-androideabi-$i $toolchain/arm-linux-gnueabi-$i
  ln -sf $toolchain/i686-linux-android-$i $toolchain/i686-linux-gnu-$i
done
# Setup cargo for exa compile
if [ -d ~/.cargo ]; then
  [ -f ~/.cargo/config.bak ] || cp -f ~/.cargo/config ~/.cargo/config.bak
  [ $ndknum -ge 23 ] && cp -f $dir/patches/cargo_config ~/.cargo/config || cp -f $dir/patches/cargo_config_old ~/.cargo/config
  sed -i "s|<toolchain>|$toolchain|g" ~/.cargo/config 2>/dev/null
fi

for lbin in $bin; do
  for larch in $arch; do
    first=true
    build_bin $lbin $larch
  done
done
[ -d ~/.cargo ] && [ ! -f ~/.cargo/config.bak ] && cp -f ~/.cargo/config.bak ~/.cargo/config

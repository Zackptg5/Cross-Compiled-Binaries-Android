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
# 16) Use strace's static_assert macro, ndk's is different
# 17) Out of date automake in coreutils, update it here
# 18) Need to use host 'file' binary for test step
# 19) Remove uneeded stesp from Makefile, either won't work since we're cross compiling or not worth the effort of hacking it to work currently
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
# 30) Remove duplicate definitions, fix "field has incomplete type 'struct sockaddr_storage'" error (already in ndk - added to strace in v5.11)
# 31) Commit isn't compatible with current quiche release, for future version - this fix revert will be removed with next quiche update

echored () {
	echo "${textred}$1${textreset}"
}
echogreen () {
	echo "${textgreen}$1${textreset}"
}
usage () {
  echo " "
  echored "USAGE:"
  echogreen "bin=      (aria2, aria2-alt, bash, bc, boringssl, brotli, bzip2, c-ares, coreutils, cpio, curl, diffutils, ed, exa, findutils, gawk, gdbm, grep, gzip, htop, iftop, libexpat, libiconv, libidn2, libmagic, libmetalink, libnl, libpcap, libpcapnl (libpcap w/ libnl), libpsl, libssh2, libssh2-alt, libunistring, nano, ncurses, ncursesw, nethogs, nghttp2 (lib only), nmap, openssl, patch, patchelf, pcre, pcre2, quiche, readline, sed, selinux, sqlite, strace, tar, tcpdump, vim, wavemon, zlib, zsh, zstd)"
  echo "           For aria, curl, and nmap dynamic link - all non-android libs are statically linked to make it much more portable"
  echo "           libssh2-alt = libssh2 with boringssl rather than openssl"
  echo "           Note that you can put as many of these as you want together as long as they're comma separated"
  echo "           Ex: bin=cpio,gzip,tar"
  echogreen "arch=     (Default: all) (all, arm, arm64, x86, x64)"
  echo "          Don't type this or set it to all to compile for all arches"
  echogreen "static=   (Default: true) (true, false)"
  echogreen "api=      (Default: 21 for dynamic, 30 for static) (21, 22, 23, 24, 26, 27, 28, 29, 30)"
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
  [ -d "$dir/patches/$bin\_patches" ] || return 0
  for i in $dir/patches/$bin\_patches/*; do
    local PFILE=$(basename $i)
    cp -f $i $PFILE
    sed -i "s/4.4/$ver/g" $PFILE
    patch -p0 -i $PFILE
    [ $? -ne 0 ] && { echored "Patching failed!"; return 1; }
    rm -f $PFILE
  done
}
setup_ohmyzsh() {
  [ -d $prefix/system/etc/zsh ] && return 0
  mkdir -p $prefix/system/etc/zsh
  git clone https://github.com/ohmyzsh/ohmyzsh.git $prefix/system/etc/zsh/.oh-my-zsh
  cp $prefix/system/etc/zsh/.oh-my-zsh/templates/zshrc.zsh-template $prefix/system/etc/zsh/.zshrc
  sed -i -e "s|PATH=.*|PATH=\$PATH|" -e "s|ZSH=.*|ZSH=/system/etc/zsh/.oh-my-zsh|" -e "s|ARCHFLAGS=.*|ARCHFLAGS=\"-arch $arch\"|" $prefix/system/etc/zsh/.zshrc
}
build_bin() {
  # Versioning and overrides
  local bin=$1 ext ver url name flags alt=false
  [ "$2" ] && local arch=$2
  [ "$lapi" ] || lapi=$api
  # Set flags
  case $arch in
    arm64|aarch64) arch=aarch64; target_host=aarch64-linux-android; osarch=android-arm64; barch=arm64-v8a;;
    arm) arch=arm; target_host=arm-linux-androideabi; osarch=android-arm; barch=armeabi-v7a;;
    x64|x86_64) arch=x86_64; target_host=x86_64-linux-android; osarch=android-x86_64; barch=x86_64;;
    x86|i686) arch=i686; target_host=i686-linux-android; osarch=android-x86; barch=x86; flags="TIME_T_32_BIT_OK=yes ";;
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
    "aria2") ver="release-1.35.0"; url="https://github.com/aria2/aria2"; [ $lapi -lt 26 ] && lapi=26;;
    "bash") ext=gz; ver="5.1"; url="gnu";;
    "bc") ext=gz; ver="1.07.1"; url="gnu";;
    "bzip2") ext=gz; ver="1.0.8"; url="https://www.sourceware.org/pub/bzip2/bzip2-$ver.tar.$ext";;
    "boringssl") ver="067cfd9"; url="https://boringssl.googlesource.com/boringssl";; # Keep consistent with quiche boringssl
    "brotli") ver="v1.0.9"; url="https://github.com/google/brotli";;
    "c-ares") ver="cares-1_17_1"; url="https://github.com/c-ares/c-ares";;
    "coreutils") ext=xz; ver="8.32"; url="gnu"; [ $lapi -lt 28 ] && lapi=28;;
    "cpio") ext=gz; ver="2.12"; url="gnu";;
    "curl") ver="curl-7_77_0 "; url="https://github.com/curl/curl"; [ $lapi -lt 26 ] && lapi=26;;
    "diffutils") ext=xz; ver="3.7"; url="gnu";;
    "ed") ext=lz; ver="1.17"; url="gnu";;
    "exa") ver="v0.10.1"; url="https://github.com/ogham/exa"; [ $lapi -lt 24 ] && lapi=24;;
    "findutils") ext=xz; ver="4.8.0"; url="gnu"; [ $lapi -lt 23 ] && lapi=23;;
    "gawk") ext=xz; ver="5.1.0"; url="gnu"; $static || { [ $lapi -lt 26 ] && lapi=26; };;
    "gdbm") ext=gz; ver="1.19" url="gnu";;
    "grep") ext=xz; ver="3.6"; url="gnu"; [ $lapi -lt 23 ] && lapi=23;;
    "gzip") ext=xz; ver="1.10"; url="gnu";;
    "htop") ver="3.0.5"; url="https://github.com/htop-dev/htop"; [ $lapi -lt 25 ] && { $static || lapi=25; };;
    "iftop") ext=gz; ver="1.0pre4"; url="http://www.ex-parrot.com/pdw/iftop/download/iftop-$ver.tar.$ext"; [ $lapi -lt 28 ] && lapi=28;;
    "libexpat") ver="R_2_4_1"; url="https://github.com/libexpat/libexpat";;
    "libiconv") ext=gz; ver="1.16"; url="gnu";;
    "libidn2") ext=gz; ver="2.3.1"; url="https://ftp.gnu.org/gnu/libidn/libidn2-$ver.tar.$ext"; $static && [ $lapi -lt 26 ] && lapi=26;;
    "libmagic") ext=gz; ver="5.40"; url="ftp://ftp.astron.com/pub/file/file-$ver.tar.$ext";;
    "libmetalink") ver="release-0.1.3"; url="https://github.com/metalink-dev/libmetalink";;
    "libnl") ext=gz; ver="3.2.25"; url="https://www.infradead.org/~tgr/libnl/files/libnl-$ver.tar.$ext"; [ $lapi -lt 26 ] && lapi=26;;
    "libpcap"|"libpcapnl") ver="1.10"; ver="c1cf421"; url="https://android.googlesource.com/platform/external/libpcap"; [ $lapi -lt 23 ] && lapi=23; [ "$bin" == "libpcapnl" ] && { bin=libpcap; alt=true; };;
    "libpsl") ver="0.21.1"; url="https://github.com/rockdaboot/libpsl"; [ $lapi -lt 26 ] && lapi=26;;
    "libssh2"|"libssh2-alt") ver="libssh2-1.9.0"; url="https://github.com/libssh2/libssh2"; [ "$bin" == "libssh2-alt" ] && { bin=libssh2; alt=true; };;
    "libunistring") ext=gz; ver="0.9.10"; url="gnu";;
    "nano") ext=xz; ver="5.8"; url="gnu";;
    "ncurses"|"ncursesw") ext=gz; ver="6.2"; url="gnu"; [ "$bin" == "ncursesw" ] && { bin=ncurses; alt=true; };;
    "nethogs") ver="v0.8.6"; url="https://github.com/raboof/nethogs"; $static || [ $lapi -ge 26 ] || lapi=26;;
    "nghttp2") ver="v1.43.0"; url="https://github.com/nghttp2/nghttp2";;
    "nmap") ext="tgz"; ver="7.91"; url="https://nmap.org/dist/nmap-$ver.$ext";;
    "openssl") ver="OpenSSL_1_1_1k"; url="https://github.com/openssl/openssl";;
    "patch") ext=xz; ver="2.7.6"; url="gnu";;
    "patchelf") ver="0.12"; url="https://github.com/NixOS/patchelf";;
    "pcre") ext=gz; ver="8.44"; url="https://ftp.pcre.org/pub/pcre/pcre-$ver.tar.$ext"; [ $lapi -lt 26 ] && lapi=26;;
    "pcre2") ext=gz; ver="10.37"; url="https://ftp.pcre.org/pub/pcre/pcre2-$ver.tar.$ext"; [ $lapi -lt 26 ] && lapi=26;;
    "quiche") ver="0.8.1"; url="https://github.com/cloudflare/quiche";;
    "readline") ext=gz; ver="8.1"; url="gnu";;
    "sed") ext=xz; ver="4.8"; url="gnu"; [ $lapi -lt 23 ] && lapi=23;;
    "selinux") ver="cf853c1"; url="https://github.com/SELinuxProject/selinux.git"; [ $lapi -lt 28 ] && lapi=28;;
    "sqlite") ext=gz; ver="3360000"; url="https://sqlite.org/2021/sqlite-autoconf-$ver.tar.$ext"; $static && [ $lapi -lt 26 ] && lapi=26;;
    "strace") ver="v5.12"; url="https://github.com/strace/strace" # Note that the hacks for this aren't needed with versions <= 5.5
            # ver=""; url="https://android.googlesource.com/platform/external/strace" # Android version compiles without any hacks but is v4.25
              ;;
    "tar") ext=xz; ver="1.34"; url="gnu"; ! $static && [ $lapi -lt 28 ] && lapi=28;;
    "tcpdump") ver="tcpdump-4.99.1"; url="https://github.com/the-tcpdump-group/tcpdump"; $static || [ $lapi -ge 26 ] || lapi=26;;
    "vim") url="https://github.com/vim/vim";;
    "wavemon") ver="v0.9.3"; url="https://github.com/uoaerg/wavemon"; $static || [ $lapi -ge 26 ] || lapi=26;;
    "zlib") ext="gz"; ver="1.2.11"; url="http://zlib.net/zlib-$ver.tar.$ext";;
    "zsh") ext=xz; ver="5.8"; url="https://sourceforge.net/projects/zsh/files/zsh/$ver/zsh-$ver.tar.$ext/download";;
    "zstd") ver="v1.5.0"; url="https://github.com/facebook/zstd";;
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
    "https://github.com/"*|*"googlesource.com"*) 
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
    local LDFLAGS="-static"
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
      autoreconf -fi
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
      gnu_patches || exit 1
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls \
        --without-bash-malloc \
        --enable-largefile \
        --enable-alias \
        --enable-history \
        --enable-readline \
        --enable-multibyte \
        --enable-job-control \
        --enable-array-variables \
        bash_cv_dev_fd=whacky \
        bash_cv_getcwd_malloc=yes
      ;;
    "bc")
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
      --host=$target_host --target=$target_host \
      $flags--prefix=$prefix || { echored "Configure failed!"; exit 1; }
      sed -i -e '\|./fbc -c|d' -e 's|$(srcdir)/fix-libmath_h|cp -f ../../patches/bc_libmath.h $(srcdir)/libmath.h|' bc/Makefile
      ;;
    "boringssl")
      cd src
      wget https://github.com/google/googletest/archive/release-1.10.0.tar.gz #23
      tar -xf release-1.10.0.tar.gz
      cp -rf googletest-release-1.10.0/googletest third_party
      rm -rf release-1.10.0.tar.gz googletest-release-1.10.0
      $static && flags="-DCMAKE_EXE_LINKER_FLAGS='-static' "
      mkdir -p build
      cd build
      cmake -DANDROID_ABI=$barch \
        -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake \
        -DANDROID_NATIVE_API_LEVEL=$lapi \
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
      patch_file $dir/patches/coreutils.patch
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
        --enable-no-install-program=stdbuf || { echored "Configure failed!"; exit 1; }
      sed -i "1iLDFLAGS += -Wl,--unresolved-symbols=ignore-in-object-files" src/local.mk #5
      ;;
    "cpio")
      sed -i 's/!defined __UCLIBC__)/!defined __UCLIBC__) || defined __ANDROID__/' gnu/vasnprintf.c #1
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls
      ;;
    "curl")
      git revert 424aa64d54fd2c4baf69aa0c09bf5db347ff59f0 #31
      static=true
      build_bin brotli
      build_bin zstd
      build_bin libmetalink
      build_bin libpsl # Also builds libidn2
      build_bin nghttp2
      build_bin libssh2-alt # Also builds boringssl
      build_bin quiche
      $origstatic && build_bin c-ares || build_bin zlib # zlib.so dependency (but not required to compile - built-in to ndk) - may not be present in rom so we build it here
      cd $dir/$bin
      static=$origstatic
      [ $lapi -lt 28 ] && LIBS="-lidn2 -lunistring -liconv -ldl -lm" || LIBS="-lidn2 -lunistring -ldl -lm" #27
      flags="--disable-shared $flags"
      $static && flags="--enable-ares=$prefix $flags" || rm -f $prefix/lib/lib*.so $prefix/lib/lib*.so.[0-9]*
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
        --with-ssl=$prefix \
        --with-brotli=$prefix \
        --with-zstd=$prefix \
        --with-ca-path=/system/etc/security/cacerts \
        --with-libmetalink=$prefix \
        --with-nghttp2=$prefix \
        --with-libidn2=$prefix \
        --with-libssh2=$prefix \
        --with-quiche=$prefix/lib/pkgconfig #27
      [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
      sed -i -e "s/#define OS .*/#define OS \"ANDROID\"/" -e "s/#define SELECT_TYPE_RETV int/#define SELECT_TYPE_RETV ssize_t/" -e "s|/\* #undef _FILE_OFFSET_BITS \*/|#define _FILE_OFFSET_BITS 64|" lib/curl_config.h
      $static && flags=" curl_LDFLAGS=-all-static" || flags=""
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
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=/system \
        --disable-nls \
        --sbindir=/system/bin \
        --libexecdir=/system/bin \
        --datarootdir=/system/usr/share || { echored "Configure failed!"; exit 1; }
      $static || sed -i -e "/#ifndef HAVE_ENDGRENT/,/#endif/d" -e "/#ifndef HAVE_ENDPWENT/,/#endif/d" -e "/endpwent/d" -e "/endgrent/d" find/parser.c
      ;;
    "gawk")
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls
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
    "grep")
      build_bin pcre
      cd $dir/$bin
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls \
        --enable-perl-regexp
      ;;
    "gzip")
      sed -i 's/!defined __UCLIBC__)/!defined __UCLIBC__) || defined __ANDROID__/' lib/vasnprintf.c #1
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix
      ;;
    "htop")
      build_bin ncursesw
      cd $dir/$bin
      ./autogen.sh
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --enable-proc \
        --enable-unicode \
        ac_cv_lib_ncursesw6_addnwstr=yes
      $static && sed -i "/rdynamic/d" Makefile.am #9
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
    "libexpat")
      cd expat
      ./buildconf.sh
      $static && flags="--disable-shared $flags"
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix
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
      [ -$lapi -lt 28 ] && flags="--with-libiconv-prefix=$prefix $flags"
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
    "libmetalink")
      build_bin libexpat
      cd $dir/$bin
      ./buildconf
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        --prefix=$prefix
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
      ./buildconf
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --enable-hidden-symbols \
        --disable-examples-build \
        --with-crypto=openssl \
        --with-libssl-prefix=$prefix
      ;;
    "libunistring")
      if [ -$lapi -lt 28 ]; then
        build_bin libiconv
        cd $dir/$bin
        flags="--with-libiconv-prefix=$prefix $flags"
      fi
      $static && flags="--disable-shared $flags"
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --disable-nls
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
        --disable-nls || { echored "Configure failed!"; exit 1; }
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
        --enable-pc-files --with-pkg-config-libdir=$prefix/lib/pkgconfig
      ;;
    "nethogs")
      build_bin libpcap
      build_bin ncurses
      cd $dir/$bin
      echo '#include <ncurses/curses.h>' > $prefix/include/ncurses.h #6
      sed -i "1aexport PREFIX := $prefix\nexport CFLAGS := $CFLAGS -I$prefix/include\nexport CXXFLAGS := \${CFLAGS}\nexport LDFLAGS := $LDFLAGS -L$prefix/lib" Makefile
      sed -i "s/decpcap_test test/decpcap_test/g" Makefile # 19
      ;;
    "nghttp2")
      $static && flags="--disable-shared $flags"
      autoreconf -fi
      ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
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
      $static || LDFLAGS="$LDFLAGS -static-libstdc++"
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
        sed -i "/#if \!defined(_WIN32)/,/#endif/d" fuzz/client.c
        sed -i "/#if \!defined(_WIN32)/,/#endif/d" fuzz/server.c
        flags=" -static threads $flags"
      else
        flags=" shared $flags"
      fi
      ./Configure $osarch$flags \
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
      ./configure CFLAGS="-O2 -fPIE -fPIC -I$prefix/include" LDFLAGS="-O2 -s -L$prefix/lib" \
        --host=$target_host \
        $flags--prefix= \
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
      cp -f include/quiche.h $prefix/include/quiche.h
      # cp -f $(find target/$target_host/release -name libcrypto.a -o -name libssl.a) target/$target_host/release/libquiche* $prefix/lib/
      cp -f target/$target_host/release/libquiche* $prefix/lib/
      cp -f target/release/quiche.pc $prefix/lib/pkgconfig/quiche.pc
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
      build_bin readline # Also builds ncurses which is required for this binary
      cd $dir/$bin
      $static && flags="--disable-shared $flags"
      ./configure CFLAGS="$CFLAGS -I$prefix/include" LDFLAGS="$LDFLAGS -L$prefix/lib" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --enable-readline
      ;;
    "strace")
      [ "$arch" == "aarch64" ] && flags="ac_cv_prog_CC_FOR_M32=arm-linux-androideabi-clang $flags" #15
      ./bootstrap
      sed -i "/#  define static_assert(/i#  undef static_assert" src/static_assert.h #16
      sed -i '/#define RENAME_/d' bundled/linux/include/uapi/linux/fs.h #30
      sed -i 's/__kernel_sockaddr_storage/sockaddr_storage/' bundled/linux/include/uapi/linux/socket.h #30
      ./configure CFLAGS="$CFLAGS -Wno-error=unused-function" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $flags--prefix=$prefix \
        --enable-mpers=m32 \
        st_cv_have_static_assert=no #16
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
      $static && [ ! "$(grep '#Zackptg5' programs/Makefile)" ] && { sed -i "s/CFLAGS   +=/CFLAGS   += -static/" programs/Makefile; echo "#Zackptg5" >> programs/Makefile; }
      true # Needed for conditional below in dynamic builds where this returns false
      ;;
  esac
  [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }

  if [ "$bin" != "exa" ] && [ "$bin" != "quiche" ]; then
    case "$bin" in
      "boringssl") mkdir -p $prefix/lib
                   cp -f ssl/libssl.a crypto/libcrypto.a decrepit/libdecrepit.a $prefix/lib/
                   cp -rf ../include $prefix/
                   ;;
      "c-ares") ninja install
                $static || cp $prefix/lib/libcares_static.a $prefix/lib/libcares.a
                ;;
      "curl") make$flags install -j$jobs
              [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
              make clean
              ;;
      "findutils") make install -j$jobs DESTDIR=$prefix
                    [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
                    sed -i -e "s|/usr/bin|/system/bin|g" -e 's|SHELL=".*"|SHELL="/system/bin/sh|' $prefix/bin/updatedb
                    mv -f $prefix/system/* $prefix
                    rm -rf $prefix/sdcard $prefix/system
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
      "zsh") make install -j$jobs DESTDIR=$prefix
             [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
             cp -rf $prefix/system/* $prefix/; rm -rf $prefix/system
             ! $static && [ "$arch" == "aarch64" -o "$arch" == "x86_64" ] && mv -f $dest/$arch/lib $dest/$arch/lib64
            ;;
      "zstd") make install -j$jobs PREFIX=$prefix
              [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
              ;;
      *) make install -j$jobs
         [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
         ;;
    esac
    if [ "$bin" != "curl" ]; then
      grep -a '^distclean:' Makefile 2>/dev/null && make distclean || make clean
    fi
  fi
  if [[ "$url" == "https://github.com/"* ]] || [[ "$url" == *"googlesource.com"* ]]; then
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
ndk=r21e #LTS NDK
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
  21|22|23|24|26|27|28|29|30) ;;
  *) $static && api=30 || api=21
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
echogreen "Fetching Android NDK $ndk"
[ -f "android-ndk-$ndk-linux-x86_64.zip" ] || wget https://dl.google.com/android/repository/android-ndk-$ndk-linux-x86_64.zip
[ -d "android-ndk-$ndk" ] || unzip -qo android-ndk-$ndk-linux-x86_64.zip
export ANDROID_NDK_HOME=$dir/android-ndk-$ndk
export toolchain=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin
export PATH=$toolchain:$PATH
# Create needed symlinks
for i in ar as ld ranlib strip clang gcc clang++ g++; do
  ln -sf $toolchain/arm-linux-androideabi-$i $toolchain/arm-linux-gnueabi-$i
  ln -sf $toolchain/i686-linux-android-$i $toolchain/i686-linux-gnu-$i
done
# Setup cargo for exa compile
if [ -d ~/.cargo ]; then
  [ -f ~/.cargo/config.bak ] || cp -f ~/.cargo/config ~/.cargo/config.bak
  cp -f $dir/patches/cargo_config ~/.cargo/config
  sed -i "s|<toolchain>|$toolchain|g" ~/.cargo/config 2>/dev/null
fi

for lbin in $bin; do
  for larch in $arch; do
    first=true
    build_bin $lbin $larch
  done
done
[ -d ~/.cargo ] && [ ! -f ~/.cargo/config.bak ] && cp -f ~/.cargo/config.bak ~/.cargo/config

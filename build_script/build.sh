#!/bin/bash
echored () {
	echo "${TEXTRED}$1${TEXTRESET}"
}
echogreen () {
	echo "${TEXTGREEN}$1${TEXTRESET}"
}
usage () {
  echo " "
  echored "USAGE:"
  echogreen "BIN=      (Valid options are: bash, bc, coreutils, cpio, diffutils, ed, exa, findutils, gawk, grep, gzip, htop, iftop, nano, ncurses, nethogs, openssl, patch, patchelf, sed, sqlite, strace, tar, tcpdump, vim, zsh, zstd)"
  echogreen "ARCH=     (Default: all) (Valid Arch values: all, arm, arm64, aarch64, x86, i686, x64, x86_64)"
  echogreen "STATIC=   (Default: true) (Valid options are: true, false)"
  echogreen "API=      (Default: 21 for dynamic, 30 for static) (Valid options are: 21, 22, 23, 24, 26, 27, 28, 29, 30)"
  echogreen "SEP=      (Default: false) (Valid options are: true, false) - Determines if coreutils builds as a single busybox-like binary or as separate binaries"
  echogreen "SELINUX=  (Default: true) (Valid options are: true, false) - Determines if you want to include selinux support in coreutils - note that minapi for selinux is 28 but 23 for coreutils"
  echogreen "           Note that you can put as many of these as you want together as long as they're comma separated"
  echogreen "           Ex: BIN=cpio,gzip,tar"
  echogreen " "
  echo " "
  exit 1
}
patch_file() {
  echogreen "Applying patch"
  local DEST=$(basename $1)
  cp -f $1 $DEST
  patch -p0 -i $DEST
  [ $? -ne 0 ] && { echored "Patching failed! Did you verify line numbers? See README for more info"; exit 1; }
}
bash_patches() {
  echogreen "Applying patches"
  local PVER=$(echo $ver | sed 's/\.//')
  for i in {001..050}; do
    wget https://mirrors.kernel.org/gnu/bash/bash-$ver-patches/bash$PVER-$i 2>/dev/null
    if [ -f "bash$PVER-$i" ]; then
      patch -p0 -i bash$PVER-$i
      rm -f bash$PVER-$i
    else
      break
    fi
  done
  for i in $DIR/bash_patches/*; do
    local PFILE=$(basename $i)
    cp -f $i $PFILE
    sed -i "s/4.4/$ver/g" $PFILE
    patch -p0 -i $PFILE
    [ $? -ne 0 ] && { echored "Patching failed!"; return 1; }
    rm -f $PFILE
  done
}
build_ncurses() {
  [ "$1" == "-w" ] && local name="ncursesw" || local name="ncurses"
  if $DEP; then
    local NPREFIX=$PREFIX
  else
    export NPREFIX="$(echo $PREFIX | sed "s|$LBIN|$name|")"
    [ -d $NPREFIX ] && return 0
  fi
	echogreen "Building NCurses..."
	cd $DIR
	[ -f "ncurses-$NVER.tar.gz" ] || wget -O ncurses-$NVER.tar.gz https://mirrors.kernel.org/gnu/ncurses/ncurses-$NVER.tar.gz
	[ -d $name-$NVER ] || { mkdir ncurses-$NVER; tar -xf ncurses-$NVER.tar.gz --transform s/ncurses-$NVER/$name-$NVER/; }
	cd $name-$NVER
  [ "$name" == "ncursesw" ] && local FLAGS="--enable-widec $FLAGS"
	./configure $FLAGS--prefix=$NPREFIX --disable-nls --disable-stripping --host=$target_host --target=$target_host CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
  [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
	if [ "$LBIN" != "$name" ]; then
    make -j$JOBS
    [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
    make install
    make distclean
    cd $DIR/$LBIN
  fi
}
build_zlib() {
  export ZPREFIX="$(echo $PREFIX | sed "s|$LBIN|zlib|")"
  [ -d $ZPREFIX ] && return 0
	echogreen "Building ZLib..."
  cd $DIR
	[ -f "zlib-$ZVER.tar.gz" ] || wget http://zlib.net/zlib-$ZVER.tar.gz
	[ -d zlib-$ZVER ] || tar -xf zlib-$ZVER.tar.gz
	cd zlib-$ZVER
  [ "$1" == "-s" ] && ./configure --prefix=$ZPREFIX --static || ./configure --prefix=$ZPREFIX
	[ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
	make -j$JOBS
	[ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
	make install
  make clean
	cd $DIR/$LBIN
}
build_bzip2() {
  export BPREFIX="$(echo $PREFIX | sed "s|$LBIN|bzip2|")"
  [ -d $BPREFIX ] && return 0
	echogreen "Building BZip2..."
  cd $DIR
	[ -f "bzip2-latest.tar.gz" ] || wget https://www.sourceware.org/pub/bzip2/bzip2-latest.tar.gz
	tar -xf bzip2-latest.tar.gz
	cd bzip2-[0-9]*
	sed -i -e '/# To assist in cross-compiling/,/LDFLAGS=/d' -e "s/CFLAGS=/CFLAGS=$CFLAGS /" -e "s|^PREFIX=.*|PREFIX=$BPREFIX|" -e 's/bzip2recover test/bzip2recover/' Makefile
	make install -j$JOBS LDFLAGS="$LDFLAGS"
	[ $? -eq 0 ] || { echored "Bzip2 build failed!"; exit 1; }
  make clean
	$STRIP $BPREFIX/bin/bunzip2 $BPREFIX/bin/bzcat $BPREFIX/bin/bzip2 $BPREFIX/bin/bzip2recover
	cd $DIR/$LBIN
}
build_pcre() {
	build_zlib
	build_bzip2
  export PPREFIX="$(echo $PREFIX | sed "s|$LBIN|pcre|")"
  [ -d $PPREFIX ] && return 0
	cd $DIR
	rm -rf pcre-$PVER 2>/dev/null
	echogreen "Building PCRE..."
	[ -f "pcre-$PVER.tar.bz2" ] || wget https://ftp.pcre.org/pub/pcre/pcre-$PVER.tar.bz2
	[ -d pcre-$PVER ] || tar -xf pcre-$PVER.tar.bz2
	cd pcre-$PVER
	$STATIC && local FLAGS="$FLAGS--disable-shared "
	./configure $FLAGS--prefix= --enable-unicode-properties --enable-jit --enable-pcre16 --enable-pcre32 --enable-pcregrep-libz --enable-pcregrep-libbz2 --host=$target_host CFLAGS="$CFLAGS -I$ZPREFIX/include -I$BPREFIX/include" LDFLAGS="$LDFLAGS -L$ZPREFIX/lib -L$BPREFIX/lib"
	[ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
	make -j$JOBS
	[ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
	make install -j$JOBS DESTDIR=$PPREFIX
  make clean
	cd $DIR/$LBIN
  $STATIC || { [ "$LBIN" == "zsh" ] && install -D $PPREFIX/lib/libpcre.so $PREFIX/lib/libpcre.so; }
}
build_pcre2() {
	build_zlib
	build_bzip2
  export P2PREFIX="$(echo $PREFIX | sed "s|$LBIN|pcre2|")"
  [ -d $P2PREFIX ] && return 0
	cd $DIR
	rm -rf pcre2-$P2VER 2>/dev/null
	echogreen "Building PCRE2..."
	[ -f "pcre2-$P2VER.tar.gz" ] || wget https://ftp.pcre.org/pub/pcre/pcre2-$P2VER.tar.gz
	[ -d pcre2-$P2VER ] || tar -xf pcre2-$P2VER.tar.gz
	cd pcre2-$P2VER
	./configure $FLAGS--prefix= --enable-jit --enable-pcre2grep-libz --enable-pcre2grep-libbz2 --enable-fuzz-support --host=$target_host CFLAGS="-O2 -fPIE -fPIC -I$ZPREFIX/include -I$BPREFIX/include" LDFLAGS="-O2 -s -L$ZPREFIX/lib -L$BPREFIX/lib"
	[ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
	make install -j$JOBS DESTDIR=$P2PREFIX
	[ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
  make clean
	cd $DIR/$LBIN
}
build_openssl() {
  [ "$1" == "-z" ] && local zlib=true || local zlib=false
  $zlib && build_zlib
  if $DEP; then
    local OPREFIX=$PREFIX
  else
    export OPREFIX="$(echo $PREFIX | sed "s|$LBIN|openssl|")"
    [ -d $OPREFIX ] && return 0
  fi
  cd $DIR
  echogreen "Building Openssl..."
  [ -d openssl ] && cd openssl || { git clone https://github.com/openssl/openssl; cd openssl; git checkout OpenSSL_$OVER; }
  if $STATIC; then
    sed -i "/#if \!defined(_WIN32)/,/#endif/d" fuzz/client.c
    sed -i "/#if \!defined(_WIN32)/,/#endif/d" fuzz/server.c
    $zlib && local FLAGS="-static zlib --with-zlib-include=$ZPREFIX/include --with-zlib-lib=$ZPREFIX/lib $FLAGS" || local FLAGS="-static $FLAGS"
  else
    $zlib && local FLAGS="zlib-dynamic --with-zlib-include=$ZPREFIX/include --with-zlib-lib=$ZPREFIX/lib $FLAGS"
  fi
  ./Configure $FLAGS$OSARCH \
              -D__ANDROID_API__=$LAPI \
              --prefix=$OPREFIX
  [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
  make -j$JOBS
  [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
  make install_sw
  make distclean
  git reset --hard
  cd $DIR/$LBIN
}
build_selinux() {
  build_pcre2
  export SPREFIX="$(echo $PREFIX | sed "s|$LBIN|selinux|")"
  [ -d $SPREFIX ] && return 0
  cd $DIR
  rm -rf selinux
  git clone https://github.com/SELinuxProject/selinux.git selinux
  cd selinux
  sed -i "s/libsemanage .*//" Makefile # Only need libsepol and libselinux
  sed -i "s/^USE_PCRE2 ?= n/USE_PCRE2 ?= y/" libselinux/Makefile # Force pcre2 - it doesn't do this for some reason
  sed -i "s/ \&\& strverscmp(uts.release, \"2.6.30\") < 0//" libselinux/src/selinux_restorecon.c # This seemingly isn't in ndk
  cp -rf libsepol/cil/include/cil libsepol/include/sepol/
  make install DESTDIR=$SPREFIX PREFIX= -j$JOBS \
  CFLAGS="-O2 -fPIE -I$P2PREFIX/include -I$DIR/selinux/libsepol/include \
  -DNO_PERSISTENTLY_STORED_PATTERNS -D_GNU_SOURCE -DUSE_PCRE2 -DANDROID_HOST" \
  LDFLAGS="-O2 -s -L$P2PREFIX/lib -L$DIR/selinux/libsepol/src -lpcre2-8"
  [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
  mv -f $SPREFIX/sbin/* $SPREFIX/bin && rm -rf $SPREFIX/sbin
  cd $DIR/$LBIN
}
build_libmagic() {
  export MPREFIX="$(echo $PREFIX | sed "s|$LBIN|libmagic|")"
  [ -d $MPREFIX ] && return 0
	cd $DIR
	echogreen "Building libmagic..."
	[ -f "file-$MVER.tar.gz" ] || wget -O file-$MVER.tar.gz ftp://ftp.astron.com/pub/file/file-$MVER.tar.gz
	[ -d file-$MVER ] || { mkdir file-$MVER; tar -xf file-$MVER.tar.gz; }
	cd file-$MVER
	./configure $FLAGS--prefix=$MPREFIX --disable-xzlib --disable-zlib --disable-bzlib --host=$target_host --target=$target_host CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
  [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
  sed -i "s|^FILE_COMPILE =.*|FILE_COMPILE = $(which file)|" magic/Makefile # Need to use host file binary
	make -j$JOBS
	[ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
	make install
  make clean
	cd $DIR/$LBIN
}
build_gdbm() {
  export GPREFIX="$(echo $PREFIX | sed "s|$LBIN|gdbm|")"
  [ -d $GPREFIX ] && return 0
	echogreen "Building Gdbm..."
  cd $DIR
	[ -f "gdbm-latest.tar.gz" ] || wget https://mirrors.kernel.org/gnu/gdbm/gdbm-latest.tar.gz
	[[ -d "gdbm-"[0-9]* ]] || tar -xf gdbm-latest.tar.gz
	cd gdbm-[0-9]*
	$STATIC && local FLAGS="--disable-shared $FLAGS"
	./configure $FLAGS--prefix= \
              --disable-nls \
              --host=$target_host \
              --target=$target_host \
              CFLAGS="$CFLAG" \
              LDFLAGS="$LDFLAGS"
	[ $? -eq 0 ] || { echored "Gdbm configure failed!"; exit 1; }
	make -j$JOBS
	[ $? -eq 0 ] || { echored "Gdbm build failed!"; exit 1; }
	make install -j$JOBS DESTDIR=$GPREFIX
  make distclean
	cd $DIR/$LBIN
  $STATIC || install -D $GPREFIX/lib/libgdbm.so $PREFIX/lib/libgdbm.so.6
}
setup_ohmyzsh() {
  local OPREFIX="$(echo $PREFIX | sed "s|$LBIN|ohmyzsh|")"
  [ -d $PREFIX/system/etc/zsh ] && return 0
  cd $DIR
  mkdir -p $OPREFIX
  git clone https://github.com/ohmyzsh/ohmyzsh.git $OPREFIX/.oh-my-zsh
  cd $OPREFIX
  cp $OPREFIX/.oh-my-zsh/templates/zshrc.zsh-template .zshrc
  sed -i -e "s|PATH=.*|PATH=\$PATH|" -e "s|ZSH=.*|ZSH=/system/etc/zsh/.oh-my-zsh|" -e "s|ARCHFLAGS=.*|ARCHFLAGS=\"-arch $LARCH\"|" .zshrc
  cd $DIR/$LBIN
  mkdir -p $PREFIX/system/etc/zsh
  cp -rf $OPREFIX/.oh-my-zsh $PREFIX/system/etc/zsh/
  cp -f $OPREFIX/.zshrc $PREFIX/system/etc/zsh/.zshrc
}
build_readline() {
  export RPREFIX="$(echo $PREFIX | sed "s|$LBIN|readline|")"
  [ -d $RPREFIX ] && return 0
	echogreen "Building libreadline..."
  cd $DIR
	[ -f "readline-$RVER.tar.gz" ] || wget https://mirrors.kernel.org/gnu/readline/readline-$RVER.tar.gz
	[ -d "readline-$RVER" ] || tar -xf readline-$RVER.tar.gz
	cd readline-$RVER
	$STATIC && local FLAGS="--disable-shared $FLAGS"
	./configure $FLAGS--prefix=$RPREFIX \
              --host=$target_host \
              --target=$target_host \
              CFLAGS="$CFLAG" \
              LDFLAGS="$LDFLAGS"
	[ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
	make -j$JOBS
	[ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
	make install -j$JOBS
  make distclean
	cd $DIR/$LBIN
}
build_libnl() {
  export LNPREFIX="$(echo $PREFIX | sed "s|$LBIN|libnl|")"
  [ -d $LNPREFIX ] && return 0
	echogreen "Building libnl..."
  cd $DIR
  rm -rf libnl-$LNVER
	[ -f "libnl-$LNVER.tar.gz" ] || wget https://www.infradead.org/~tgr/libnl/files/libnl-$LNVER.tar.gz
	[ -d "libnl-$LNVER" ] || tar -xf libnl-$LNVER.tar.gz
	cd libnl-$LNVER
	# $STATIC && { local FLAGS="--disable-shared $FLAGS"; sed -i "s/-rdynamic//" src/lib/Makefile.*; }
  # grep -q '#include <math.h>' lib/utils.c || sed -i "/#include <netlink-private\/netlink.h>/i#include <math.h>" lib/utils.c
  # cp -f $(dirname $ANDROID_TOOLCHAIN)/sysroot/usr/include/math.h lib/math.h
  # sed -i -e '/#ifndef CCAN_HASH_H/d' -e '\|#endif /\* HASH_H \*/|d' include/netlink/hash.h
	./configure $FLAGS--prefix=$LNPREFIX \
              --host=$target_host \
              --target=$target_host \
              CFLAGS="$CFLAG" \
              LDFLAGS="$LDFLAGS" \
              --disable-pthreads
	[ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
	make # -j$JOBS # Weird font change happens when this is enabled for some reason
	[ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
	make install -j$JOBS
  make distclean
	cd $DIR/$LBIN
}
build_libpcap() {
  build_libnl
  export LPREFIX="$(echo $PREFIX | sed "s|$LBIN|libpcap|")"
  [ -d $LPREFIX ] && return 0
  echogreen "Building libpcap..."
  cd $DIR
  rm -rf libpcap-$LVER
  # [ -f "libpcap-$LVER.tar.gz" ] || wget -O libpcap-$LVER.tar.gz https://www.tcpdump.org/release/libpcap-$LVER.tar.gz
  # tar -xf libpcap-$LVER.tar.gz
  git clone https://android.googlesource.com/platform/external/libpcap # Switch to google repo cause it just works
  mv -f libpcap libpcap-$LVER
  cd libpcap-$LVER
  $STATIC && local FLAGS="--disable-shared $FLAGS"
  ./configure $FLAGS--prefix=$LPREFIX --with-pcap=linux --host=$target_host --target=$target_host CFLAGS="$CFLAGS -I$LNPREFIX/include" LDFLAGS="$LDFLAGS -L$LNPREFIX/lib"
  [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }
  make -j$JOBS
  [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
  make install -j$JOBS
  cp -rf $DIR/libpcap-$LVER/* $LPREFIX/
  make distclean
  cd $DIR/$LBIN
}

TEXTRESET=$(tput sgr0)
TEXTGREEN=$(tput setaf 2)
TEXTRED=$(tput setaf 1)
DIR=$PWD
NDKVER=r21e #LTS NDK
STATIC=true
SEP=false
SELINUX=true
export OPATH=$PATH
OIFS=$IFS; IFS=\|;
while true; do
  case "$1" in
    -h|--help) usage;;
    "") shift; break;;
    API=*|STATIC=*|BIN=*|ARCH=*|SEP=*|SELINUX=*) eval $(echo "$1" | sed -e 's/=/="/' -e 's/$/"/' -e 's/,/ /g'); shift;;
    *) echored "Invalid option: $1!"; usage;;
  esac
done
IFS=$OIFS
[ -z "$ARCH" -o "$ARCH" == "all" ] && ARCH="arm arm64 x86 x64"

case $API in
  21|22|23|24|26|27|28|29|30) ;;
  *) $STATIC && API=30 || API=21;;
esac

if [ -f /proc/cpuinfo ]; then
  JOBS=$(grep flags /proc/cpuinfo | wc -l)
elif [ ! -z $(which sysctl) ]; then
  JOBS=$(sysctl -n hw.ncpu)
else
  JOBS=2
fi

# Set up Android NDK
echogreen "Fetching Android NDK $NDKVER"
[ -f "android-ndk-$NDKVER-linux-x86_64.zip" ] || wget https://dl.google.com/android/repository/android-ndk-$NDKVER-linux-x86_64.zip
[ -d "android-ndk-$NDKVER" ] || unzip -qo android-ndk-$NDKVER-linux-x86_64.zip
export ANDROID_NDK_HOME=$DIR/android-ndk-$NDKVER
export ANDROID_TOOLCHAIN=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin
export PATH=$ANDROID_TOOLCHAIN:$PATH
# Create needed symlinks
for i in ar as ld ranlib strip clang gcc clang++ g++; do
  ln -sf $ANDROID_TOOLCHAIN/arm-linux-androideabi-$i $ANDROID_TOOLCHAIN/arm-linux-gnueabi-$i
  ln -sf $ANDROID_TOOLCHAIN/i686-linux-android-$i $ANDROID_TOOLCHAIN/i686-linux-gnu-$i
done
if [ -d ~/.cargo ]; then
  [ -f ~/.cargo/config.bak ] || cp -f ~/.cargo/config ~/.cargo/config.bak
  cp -f $DIR/config ~/.cargo/config
  sed -i "s|<ANDROID_TOOLCHAIN>|$ANDROID_TOOLCHAIN|g" ~/.cargo/ 2>/dev/null
fi

for LBIN in $BIN; do
  # Versioning and overrides
  LAPI=$API
  DEP=false
  LNVER=3.2.25
  LVER=1.10
  MVER=5.39
  NVER=6.2
  OVER=1_1_1i
  PVER=8.44
  P2VER=10.35
  RVER=8.1
  ZVER=1.2.11
  unset ext ver url name
  case $LBIN in
    "bash") ext=gz; ver="5.1";;
    "bc") ext=gz; ver="1.07.1";;
    "coreutils") ext=xz; ver="8.32"; $SELINUX && { [ $LAPI -lt 28 ] && LAPI=28; } || { [ $LAPI -lt 23 ] && LAPI=23; };;
    "cpio") ext=gz; ver="2.12";;
    "diffutils") ext=xz; ver="3.7";;
    "ed") ext=lz; ver="1.17";;
    "exa") ver="v0.9.0"; url="https://github.com/ogham/exa"; [ $LAPI -lt 24 ] && LAPI=24;;
    "findutils") ext=xz; ver="4.8.0"; [ $LAPI -lt 23 ] && LAPI=23;;
    "gawk") ext=xz; ver="5.1.0"; $STATIC || { [ $LAPI -lt 26 ] && LAPI=26; };;
    "grep") ext=xz; ver="3.6"; [ $LAPI -lt 23 ] && LAPI=23;;
    "gzip") ext=xz; ver="1.10";;
    "htop") ver="3.0.5"; url="https://github.com/htop-dev/htop"; [ $LAPI -lt 25 ] && { $STATIC || LAPI=25; };;
    "iftop") ext=gz; ver="0.17"; ver="1.0pre4"; [ $LAPI -lt 23 ] && LAPI=28;;
    "nano") ext=xz; ver="5.5";;
    "ncurses") ver="$NVER"; DEP=true;;
    "nethogs") ver="v0.8.6"; url="https://github.com/raboof/nethogs";;
    "openssl") ver="$OVER"; DEP=true;;
    "patch") ext=xz; ver="2.7.6";;
    "patchelf") ver="0.12"; url="https://github.com/NixOS/patchelf";;
    "sed") ext=xz; ver="4.8"; [ $LAPI -lt 23 ] && LAPI=23;;
    "sqlite") ext=gz; ver="3340100";;
    "strace") ver="v5.10"; url="https://github.com/strace/strace";; # Recommend v5.5 for arm64
    "tar") ext=xz; ver="1.33"; ! $STATIC && [ $LAPI -lt 28 ] && LAPI=28;;
    "tcpdump") ver="tcpdump-4.99.0"; url="https://github.com/the-tcpdump-group/tcpdump";;
    "vim") url="https://github.com/vim/vim";;
    "zsh") ext=xz; ver="5.8";;
    "zstd") ver="v1.4.8"; url="https://github.com/facebook/zstd";;
    *) echored "Invalid binary specified!"; usage;;
  esac

  # Create needed symlinks - put here in case of LAPI overrides above
  for i in armv7a-linux-androideabi aarch64-linux-android x86_64-linux-android i686-linux-android; do
    [ "$i" == "armv7a-linux-androideabi" ] && j="arm-linux-androideabi" || j=$i
    ln -sf $ANDROID_TOOLCHAIN/$i$LAPI-clang $ANDROID_TOOLCHAIN/$j-clang
    ln -sf $ANDROID_TOOLCHAIN/$i$LAPI-clang++ $ANDROID_TOOLCHAIN/$j-clang++
    ln -sf $ANDROID_TOOLCHAIN/$i$LAPI-clang $ANDROID_TOOLCHAIN/$j-gcc
    ln -sf $ANDROID_TOOLCHAIN/$i$LAPI-clang++ $ANDROID_TOOLCHAIN/$j-g++
  done

  # Fetch source
  if ! $DEP; then
    echogreen "Fetching $LBIN"
    cd $DIR
    rm -rf $LBIN

    if [ "$url" ]; then
      git clone $url
      cd $LBIN
      [ "$ver" ] && git checkout $ver 2>/dev/null
    else
      case $LBIN in
        "iftop") url="http://www.ex-parrot.com/pdw/iftop/download/iftop-$ver.tar.$ext";;
        "sqlite") url="https://sqlite.org/2021/sqlite-autoconf-$ver.tar.$ext";;
        "zsh") url="https://sourceforge.net/projects/zsh/files/zsh/$ver/zsh-$ver.tar.$ext/download"; name="zsh-$ver.tar.$ext";;
        *) [[ $(wget -S --spider https://ftp.gnu.org/gnu/$LBIN/$LBIN-$ver.tar.$ext 2>&1 | grep 'HTTP/1.1 200 OK') ]] && url="https://ftp.gnu.org/gnu/$LBIN/$LBIN-$ver.tar.$ext" || url="https://mirrors.kernel.org/gnu/$LBIN/$LBIN-$ver.tar.$ext";;
      esac
      [ -z "$name" ] && name="$(basename $url)"
      [ -f "$name" ] || wget -O $name $url
      tar -xf $name --transform s/$(echo $name | sed "s/.tar.$ext//")/$LBIN/
      cd $LBIN
    fi
  fi

  for LARCH in $ARCH; do
    echogreen "Compiling $LBIN version $ver for $LARCH"
    unset FLAGS
    case $LARCH in
      arm64) LARCH=aarch64; target_host=aarch64-linux-android; OSARCH=android-arm64;;
      arm) LARCH=arm; target_host=arm-linux-androideabi; OSARCH=android-arm;;
      x64) LARCH=x86_64; target_host=x86_64-linux-android; OSARCH=android-x86_64;;
      x86) LARCH=i686; target_host=i686-linux-android; OSARCH=android-x86; FLAGS="TIME_T_32_BIT_OK=yes ";;
      *) echored "Invalid ARCH: $LARCH!"; exit 1;;
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
    if $STATIC; then
      CFLAGS="-static -O2"
      LDFLAGS="-static"
      export PREFIX=$DIR/build-static/$LBIN/$LARCH
      [ -f $DIR/ndk_static_patches/$LBIN.patch ] && [ ! -f $LBIN.patch ] && patch_file $DIR/ndk_static_patches/$LBIN.patch
    else
      CFLAGS='-O2 -fPIE -fPIC'
      LDFLAGS='-s -pie'
      export PREFIX=$DIR/build-dynamic/$LBIN/$LARCH
    fi

    # Fixes:
    # 1) %n issue due to these binaries using old gnulib (This was in Jan 2019: http://git.savannah.gnu.org/gitweb/?p=gnulib.git;a=commit;h=6c0f109fb98501fc8d65ea2c83501b45a80b00ab)
    # 2) minus_zero duplication error in NDK
    # 3) Bionic error fix in NDK
    # 4) New syscall function has been added in coreutils 8.32 - won't compile with android toolchains - fix only needed for 64bit arch's oddly enough
    # 5) Coreutils doesn't detect pcre2 related functions for whatever reason - ignore resulting errors - must happen for coreutils only (after gnulib)
    # 6) Expects ncurses in different location, make what's essentially a symlink to real one
    # 7) Can't detect pthread from ndk so clear any values set by configure
    # 8) pthread_cancel not in ndk, use Hax4us workaround found here: https://github.com/axel-download-accelerator/axel/issues/150
    # 9) Allow static compile (will compile dynamic regardless of flags without this patch), only needed for arm64 oddly
    # 10) Specify that ncursesw is defined since clang errors out with ncursesw
    echogreen "Configuring for $LARCH"
    case $LBIN in
      "bash")
        $STATIC && { FLAGS="$FLAGS--enable-static-link "; sed -i 's/-rdynamic//g' configure; sed -i 's/-rdynamic//g' configure.ac; } #9
        bash_patches || exit 1
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
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
        $FLAGS--prefix=$PREFIX \
        --disable-nls || { echored "Configure failed!"; exit 1; }
        sed -i -e '\|./fbc -c|d' -e 's|$(srcdir)/fix-libmath_h|cp -f ../../bc_libmath.h $(srcdir)/libmath.h|' bc/Makefile
        ;;
      "coreutils")
        build_openssl -z
        build_selinux
        patch_file $DIR/coreutils.patch
        $SEP || FLAGS="$FLAGS--enable-single-binary=symlinks "
        sed -i 's/#ifdef __linux__/#ifndef __linux__/g' src/ls.c #4
        sed -i "s/USE_FORTIFY_LEVEL/BIONIC_FORTIFY/g" lib/cdefs.h #3
        sed -i "s/USE_FORTIFY_LEVEL/BIONIC_FORTIFY/g" lib/stdio.in.h #3
        sed -i -e '/if (!num && negative)/d' -e "/return minus_zero/d" -e "/DOUBLE minus_zero = -0.0/d" lib/strtod.c #2
        if $SELINUX; then
          ./configure CFLAGS="$CFLAGS -I$OPREFIX/include -I$P2PREFIX/include -I$SPREFIX/include" LDFLAGS="$LDFLAGS -L$OPREFIX/lib -L$P2PREFIX/lib -L$SPREFIX/lib" \
          --host=$target_host --target=$target_host \
          $FLAGS--prefix=$PREFIX \
          --disable-nls \
          --with-openssl=yes \
          --with-linux-crypto \
          --enable-no-install-program=stdbuf || { echored "Configure failed!"; exit 1; }
        else
          ./configure CFLAGS="$CFLAGS -I$OPREFIX/include" LDFLAGS="$LDFLAGS -L$OPREFIX/lib" \
          --host=$target_host --target=$target_host \
          $FLAGS--prefix=$PREFIX \
          --disable-nls \
          --with-openssl=yes \
          --with-linux-crypto \
          --enable-no-install-program=stdbuf || { echored "Configure failed!"; exit 1; }
        fi
        $SELINUX && [ ! "$(grep "^LDFLAGS += -Wl,--unresolved-symbols=ignore-in-object-files" src/local.mk)" ] && sed -i "1iLDFLAGS += -Wl,--unresolved-symbols=ignore-in-object-files" src/local.mk #5
        # sed -ri "/^LDFLAGS \+= -Wl,--warn-unresolved-symbol|^LDFLAGS \+= -Wl,--unresolved-symbols=ignore-all/d" src/local.mk
        # if $SELINUX; then
        #   case $LARCH in
        #     *64) sed -i "1iLDFLAGS += -Wl,--warn-unresolved-symbol" src/local.mk;;
        #     *) sed -i "1iLDFLAGS += -Wl,--unresolved-symbols=ignore-all" src/local.mk;;
        #   esac
        # fi
        [ ! "$(grep "#define HAVE_MKFIFO 1" lib/config.h)" ] && echo "#define HAVE_MKFIFO 1" >> lib/config.h
        ;;
      "cpio")
        sed -i 's/!defined __UCLIBC__)/!defined __UCLIBC__) || defined __ANDROID__/' gnu/vasnprintf.c #1
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
        --disable-nls
        ;;
      "diffutils")
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
        --disable-nls
        ;;
      "ed")
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        $FLAGS--prefix=$PREFIX \
        CC=$GCC CXX=$GXX
        ;;
      "exa")
        build_zlib
        cargo b --release --target $target_host -j $JOBS
        [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
        mkdir -p $PREFIX/bin
        cp -f $DIR/exa/target/$target_host/release/exa $PREFIX/bin/exa
      ;;
      "findutils")
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=/system \
        --disable-nls \
        --sbindir=/system/bin \
        --libexecdir=/system/bin \
        --datarootdir=/system/usr/share || { echored "Configure failed!"; exit 1; }
        $STATIC || sed -i -e "/#ifndef HAVE_ENDGRENT/,/#endif/d" -e "/#ifndef HAVE_ENDPWENT/,/#endif/d" -e "/endpwent/d" -e "/endgrent/d" find/parser.c
        ;;
      "gawk")
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
        --disable-nls
        ;;
      "grep")
        build_pcre
        ./configure CFLAGS="$CFLAGS -I$PPREFIX/include" LDFLAGS="$LDFLAGS -L$PPREFIX/lib" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
        --disable-nls --enable-perl-regexp
        ;;
      "gzip")
        sed -i 's/!defined __UCLIBC__)/!defined __UCLIBC__) || defined __ANDROID__/' lib/vasnprintf.c #1
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX
        ;;
      "htop")
        build_ncurses -w
        ./autogen.sh
        ./configure CFLAGS="$CFLAGS -I$NPREFIX/include" LDFLAGS="$LDFLAGS -L$NPREFIX/lib" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
        --enable-proc \
        --enable-unicode \
        ac_cv_lib_ncursesw6_addnwstr=yes
        $STATIC && sed -i "/rdynamic/d" Makefile.am #9
        ;;
      "iftop")
        build_libpcap
        build_ncurses
        echo '#include <ncurses/curses.h>' > $NPREFIX/include/ncurses.h #6
        cp -f $NPREFIX/include/ncurses.h $NPREFIX/include/curses.h #6
        if [ ! "$(grep 'Bpthread.h' iftop.c)" ]; then
          sed -i '/test $thrfail = 1/ithrfail=0\nCFLAGS="$oldCFLAGS"\nLIBS="$oldLIBS"' configure #7
          cp -f $DIR/Bpthread.h Bpthread.h #8
          sed -i '/pthread.h/a#include <Bpthread.h>' iftop.c #8
        fi
        $STATIC && sed -i "s/cross_compiling=no/cross_compiling=yes/" configure
        ./configure CFLAGS="$CFLAGS -I$LPREFIX/include -I$NPREFIX/include" LDFLAGS="$LDFLAGS -L$LPREFIX/lib -L$NPREFIX/lib" --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
        --with-libpcap=$LPREFIX \
        --with-resolver=netdb
        ;;
      "nano")
        build_zlib
        build_libmagic
        build_ncurses -w
        mkdir -p $PREFIX/system/usr/share
        cp -rf $NPREFIX/share/terminfo $PREFIX/system/usr/share
        # Workaround no longer needed
        # wget -O - "https://kernel.googlesource.com/pub/scm/fs/ext2/xfstests-bld/+/refs/heads/master/android-compat/getpwent.c?format=TEXT" | base64 --decode > src/getpwent.c
        # wget -O src/pty.c https://raw.githubusercontent.com/CyanogenMod/android_external_busybox/cm-13.0/android/libc/pty.c
        # sed -i 's|int ptsname_r|//hack int ptsname_r(int fd, char* buf, size_t len) {\nint bb_ptsname_r|' src/pty.c
        # sed -i "/#include \"nano.h\"/a#define ptsname_r bb_ptsname_r\n//#define ttyname bb_ttyname\n#define ttyname_r bb_ttyname_r" src/proto.h
        $STATIC || FLAGS="ac_cv_header_glob_h=no $FLAGS"
        ./configure CFLAGS="$CFLAGS -I$ZPREFIX/include -I$NPREFIX/include -I$MPREFIX/include" LDFLAGS="$LDFLAGS -L$ZPREFIX/lib -L$NPREFIX/lib -L$MPREFIX/lib" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=/system \
        --sbindir=/system/bin \
        --libexecdir=/system/bin \
        --datarootdir=/system/usr/share \
        --disable-nls || { echored "Configure failed!"; exit 1; }
        sed -i '/#if defined(HAVE_NCURSESW_NCURSES_H)/i#define HAVE_NCURSESW_NCURSES_H' src/definitions.h #10
        ;;
      "ncurses")
        build_ncurses
        ;;
      "ncursesw")
        build_ncurses -w
        ;;
      "nethogs")
        build_libpcap
        build_ncurses
        echo '#include <ncurses/curses.h>' > $NPREFIX/include/ncurses.h #6
        sed -i "1aexport PREFIX := $PREFIX\nexport CFLAGS := $CFLAGS -I$LPREFIX/include -I$NPREFIX/include\nexport CXXFLAGS := \${CFLAGS}\nexport LDFLAGS := $LDFLAGS -L$LPREFIX/lib -L$NPREFIX/lib" Makefile
        sed -i "s/decpcap_test test/decpcap_test/g" Makefile # Remove uneeded test - won't work cause we're cross-compiling
        ;;
      "openssl")
        build_openssl -z
        ;;
      "patch")
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX
        ;;
      "patchelf")
        ./bootstrap.sh
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX
        ;;
			"sed")
        $NDK && { sed -i "s/USE_FORTIFY_LEVEL/BIONIC_FORTIFY/g" lib/cdefs.h; sed -i "s/USE_FORTIFY_LEVEL/BIONIC_FORTIFY/g" lib/stdio.in.h; } #3
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
        --disable-nls
        ;;
      "sqlite")
        build_zlib
        build_ncurses
        build_readline
	      $STATIC && FLAGS="--disable-shared $FLAGS"
        ./configure CFLAGS="$CFLAGS -I$ZPREFIX/include -I$NPREFIX/include -I$RPREFIX/include" LDFLAGS="$LDFLAGS -L$ZPREFIX/lib -L$NPREFIX/lib -L$RPREFIX/lib" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
        --enable-readline
        ;;
      "strace")
        case $LARCH in
          "x86_64") FLAGS="--enable-mpers=m32 $FLAGS";;
          "aarch64") [ $(echo "$ver > 5.5" | bc -l) -eq 1 ] && FLAGS="--enable-mpers=mx32 $FLAGS";; #mpers-m32 errors since v5.6
        esac
        ./bootstrap.sh
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX
        ;;
			"tar")
        sed -i 's/!defined __UCLIBC__)/!defined __UCLIBC__) || defined __ANDROID__/' gnu/vasnprintf.c #1
        sed -i "s/USE_FORTIFY_LEVEL/BIONIC_FORTIFY/g" gnu/cdefs.h #3
        sed -i "s/USE_FORTIFY_LEVEL/BIONIC_FORTIFY/g" gnu/stdio.in.h #3
        ./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
        --disable-nls 
        ;;
      "tcpdump")
        build_openssl
        build_libpcap
        ./configure CFLAGS="$CFLAGS -I$LPREFIX/include -I$OPREFIX/include" LDFLAGS="$LDFLAGS -L$LPREFIX/lib -L$OPREFIX/lib" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX
        ;;
      "vim")
        build_ncurses -w
        ./configure CFLAGS="$CFLAGS -I$NPREFIX/include" LDFLAGS="$LDFLAGS -L$NPREFIX/lib" \
        --host=$target_host --target=$target_host \
        $FLAGS--prefix=$PREFIX \
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
      "zsh")
        build_pcre
        build_gdbm
        build_ncurses -w
        setup_ohmyzsh
        sed -i "/exit 0/d" Util/preconfig
        . Util/preconfig
        sed -i -e "/trap 'save=0'/azdmsg=$zd\nmkdir -p $zd" -e "/# Substitute an initial/,/# Don't run if we can't write to \$zd./d" Functions/Newuser/zsh-newuser-install
        $STATIC && FLAGS="--disable-dynamic --disable-dynamic-nss $FLAGS"
        ./configure \
        --host=$target_host --target=$target_host \
        --enable-cflags="$CFLAGS -I $PPREFIX/include -I$GPREFIX/include -I$NPREFIX/include" \
        --enable-ldflags="$LDFLAGS -L$PPREFIX/lib -L$GPREFIX/lib -L$NPREFIX/lib" \
        $FLAGS--prefix=/system \
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
        $STATIC && [ ! "$(grep '#Zackptg5' programs/Makefile)" ] && sed -i "s/CFLAGS   +=/CFLAGS   += -static/" programs/Makefile
        [ "$(grep '#Zackptg5' programs/Makefile)" ] || echo "#Zackptg5" >> programs/Makefile
        true # Needed for conditional below in dynamic builds
        ;;
    esac
    [ $? -eq 0 ] || { echored "Configure failed!"; exit 1; }

    if [ "$LBIN" != "exa" ] && ! $DEP; then
      make -j$JOBS
      [ $? -eq 0 ] || { echored "Build failed!"; exit 1; }
      if [ "$LBIN" == "findutils" ]; then
        sed -i -e "s|/usr/bin|/system/bin|g" -e "s|SHELL=\".*\"|SHELL=\"/system/bin/sh\"|" locate/updatedb
        make install DESTDIR=$PREFIX
        mv -f $PREFIX/system/* $PREFIX
        rm -rf $PREFIX/sdcard $PREFIX/system
      elif [ "$LBIN" == "nano" ]; then
        make install DESTDIR=$PREFIX
        $STRIP $PREFIX/system/bin/nano
        # mv -f $PREFIX/system/bin/nano $PREFIX/system/bin/nano.bin
        # cp -f $DIR/nano_wrapper $PREFIX/system/bin/nano
        rm -rf $PREFIX/system/usr/share/nano
        git clone https://github.com/scopatz/nanorc $PREFIX/system/usr/share/nano
        rm -rf $PREFIX/system/usr/share/nano/.git
        find $PREFIX/system/usr/share/nano -type f ! -name '*.nanorc' -delete
      elif [ "$LBIN" == "zsh" ]; then
        make install -j$JOBS DESTDIR=$PREFIX
        ! $STATIC && [ "$LBIN" == "zsh" ] && [ "$LARCH" == "aarch64" -o "$LARCH" == "x86_64" ] && mv -f $DEST/$LARCH/lib $DEST/$LARCH/lib64
      else
        make install -j$JOBS
      fi
      make distclean 2>/dev/null || make clean 2>/dev/null
      git reset --hard 2>/dev/null
    fi
    $STRIP $PREFIX/*bin/* 2>/dev/null
    echogreen "$LBIN built sucessfully and can be found at: $PREFIX"
  done
done
[ -d ~/.cargo ] && [ ! -f ~/.cargo/config.bak ] && cp -f ~/.cargo/config.bak ~/.cargo/config

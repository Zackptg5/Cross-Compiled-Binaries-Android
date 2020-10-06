# Since same libs are shared between multiple binaries, don't remove libs on uninstall of binary
sed -i "/libz.so.1/d" $MODDIR/.$ibinary

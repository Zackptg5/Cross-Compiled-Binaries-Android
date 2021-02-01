# Since same libs are shared between multiple binaries, don't remove libs on uninstall of binary
sed -i '/libpcap.so.1/d' $MODDIR/.$ibinary

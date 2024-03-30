[ -z "$MODDIR" ] && MODDIR=$MODPATH #legacy variable
# Since same libs are shared between multiple binaries, don't remove libs on uninstall of binary
rm -f $MODDIR/.$ibinary
# Don't replace existing libz - leads to bootloop
[ -f "/system/lib/libz.so" ] && rm -f $MODDIR/system/lib*/libz.so
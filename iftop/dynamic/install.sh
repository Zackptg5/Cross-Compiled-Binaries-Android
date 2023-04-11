[ -z "$MODDIR" ] && MODDIR=$MODPATH #legacy variable
# Since same libs are shared between multiple binaries, don't remove libs on uninstall of binary
rm -f $MODDIR/.$ibinary

[ -z "$MODDIR" ] && MODDIR=$MODPATH #legacy variable
[ $scriptver -lt 25 ] && aliasfile=/storage/emulated/0/.aliases || aliasfile=$MODDIR/system/etc/ccbins-aliases # legacy terminalmods
# dns server fix not needed
sed -i '/^alias curl=/d' $aliasfile

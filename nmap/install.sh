[ -z "$MODDIR" ] && MODDIR=$MODPATH #legacy variable
[ $scriptver -lt 25 ] && aliasfile=/storage/emulated/0/.aliases || aliasfile=$MODDIR/system/etc/ccbins-aliases # legacy terminalmods
# dns server fix
sed -i '/^alias nmap=/d' $aliasfile
echo "alias nmap='nmap --system-dns'" >> $aliasfile

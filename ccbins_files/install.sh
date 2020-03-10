filever=1
# Works best with @Skittles9823's TerminalMods module
ui_print "- Terminal Modifications"
if [ -d $NVBASE/modules/terminalmods ]; then
  ui_print "   Terminal Modifications module detected"
  ui_print "   Good, keep it"
else
  ui_print "   Terminal Modifications not module detected!"
  ui_print "   Highly recommended to install from repo"
  sleep 2
fi

# Keep current mod settings
if [ -f $NVBASE/modules/$MODID/system/bin/ccbins ]; then
  ui_print "- Using current ccbin files/settings"
  cp -af $NVBASE/modules/$MODID/system $MODPATH
  cp -pf $NVBASE/modules/$MODID/.* $MODPATH 2>/dev/null
else
  mkdir -p $MODPATH/system/bin
fi

# Setup mkshrc
mkdir -p $MODPATH/system/etc
cp -af $MAGISKTMP/mirror/system/etc/mkshrc $MODPATH/system/etc/mkshrc
echo '[ -f /sdcard/.aliases ] && . /sdcard/.aliases' >> $MODPATH/system/etc/mkshrc

# Get mod files
ui_print "- Downloading and installing needed files"
for i in service.sh post-fs-data.sh mod-util.sh "system/bin/ccbins"; do
  wget -qO $MODPATH/$i https://github.com/Zackptg5/Cross-Compiled-Binaries-Android/raw/$branch/ccbins_files/$(basename $i) 2>/dev/null
done
set_perm $MODPATH/system/bin/ccbins 0 0 0755
wget -qO $MODPATH/busybox https://github.com/Zackptg5/Cross-Compiled-Binaries-Android/raw/master/busybox/busybox-$ARCH 2>/dev/null
set_perm $MODPATH/busybox 0 0 0755
rm -f $MODPATH/busybox-*
locs="$(grep '^locs=' $MODPATH/system/bin/ccbins)"
eval $locs
for i in $locs; do
  [ -d $MODPATH$i ] && chmod -R 0755 $MODPATH$i
done

# Cleanup
rm -f $MODPATH/install.sh

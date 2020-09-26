filever=5
# Keep current mod settings
if [ -f $NVBASE/modules/$MODID/system/bin/ccbins ]; then
  ui_print "- Using current ccbin files/settings"
  cp -af $NVBASE/modules/$MODID/system $MODPATH
  cp -pf $NVBASE/modules/$MODID/.* $MODPATH 2>/dev/null
else
  mkdir -p $MODPATH/system/bin
fi

# Get mod files
ui_print "- Downloading and installing needed files"
for i in service.sh mod-util.sh "system/bin/ccbins"; do
  curl -so $MODPATH/$i https://github.com/Zackptg5/Cross-Compiled-Binaries-Android/raw/$branch/ccbins_files/$(basename $i) 2>/dev/null
done
set_perm $MODPATH/system/bin/ccbins 0 0 0755
if [ "`wget -S --spider https://github.com/Magisk-Modules-Repo/busybox-ndk/raw/master/busybox-$ARCH-selinux 2>&1 | grep 'HTTP/1.1 200 OK'`" ]; then
  curl -so $MODPATH/busybox https://github.com/Magisk-Modules-Repo/busybox-ndk/raw/master/busybox-$ARCH-selinux 2>/dev/null
else
  cp -f $MODPATH/busybox-$ARCH32 $MODPATH/busybox
fi
set_perm $MODPATH/busybox 0 0 0755

locs="$(grep '^locs=' $MODPATH/system/bin/ccbins)"
eval $locs
for i in $locs; do
  [ -d $MODPATH$i ] && chmod -R 0755 $MODPATH$i
done

# Requires @Skittles9823's TerminalMods module
ui_print "- Terminal Modifications"
if [ -d $NVBASE/modules/terminalmods ]; then
  ui_print "   Terminal Modifications module detected"
  ui_print "   Good, keep it"
else
  ui_print "   Terminal Modifications not module detected!"
  ui_print "   Installing!"
  if [ "`wget -S --spider https://github.com/Magisk-Modules-Repo/terminalmods/archive/master.zip 2>&1 | grep 'HTTP/1.1 200 OK'`" ]; then
    curl -so $TMPDIR/tmp.zip https://github.com/Magisk-Modules-Repo/terminalmods/archive/master.zip
    unzip -qo $TMPDIR/tmp.zip terminalmods-master/customize.sh terminalmods-master/module.prop 'terminalmods-master/custom/*' 'terminalmods-master/system/*' -d $MODULEROOT
    mv -f $MODULEROOT/terminalmods-master $MODULEROOT/terminalmods
    sed -i "s|\$MODPATH|$MODULEROOT/terminalmods|g" $MODULEROOT/terminalmods/customize.sh
    . $MODULEROOT/terminalmods/customize.sh
    rm -f $MODULEROOT/terminalmods/customize.sh
    mkdir $NVBASE/modules/terminalmods
    cp -f $MODULEROOT/terminalmods/module.prop $NVBASE/modules/terminalmods/
    touch $NVBASE/modules/terminalmods/update
  else
    ui_print "   Unable to download! Install through magisk manager!"
  fi
fi

# Cleanup
rm -f $MODPATH/busybox-* $MODPATH/curl-* $MODPATH/install.sh

# This script will be executed in post-fs-data mode
# More info in the main Magisk thread
MODPATH=${0%/*}
filever=1
if [ "$(grep 'Coreutils' $MODPATH/.installed)" ]; then
  grep -q 'cu()' $MODPATH/system/etc/ccbins-aliases 2>/dev/null || echo -e 'cu() {\n  coreutils --coreutils-prog=${@}\n} #cu' >> $MODPATH/system/etc/ccbins-aliases
  grep -q 'alias cp=' $MODPATH/system/etc/ccbins-aliases 2>/dev/null || echo "alias cp='cp -g'" >> $MODPATH/system/etc/ccbins-aliases
  grep -q 'alias mv=' $MODPATH/system/etc/ccbins-aliases 2>/dev/null || echo "alias mv='mv -g'" >> $MODPATH/system/etc/ccbins-aliases
else
  sed -i -e '/cp -g/d' -e '/mv -g/d' -e '/cu() {/,/} #cu/d' $MODPATH/system/etc/ccbins-aliases
fi
if [ "$(grep 'Findutils' $MODPATH/.installed)" ]; then # Needs to be set to new mirror path each boot
  sed -i '/updatedb/d' $MODPATH/system/etc/ccbins-aliases
  echo "alias updatedb='updatedb --prunepaths=\"/proc $(magisk --path)/.magisk/mirror\"'" >> $MODPATH/system/etc/ccbins-aliases
else
  sed -i '/updatedb/d' $MODPATH/system/etc/ccbins-aliases
fi

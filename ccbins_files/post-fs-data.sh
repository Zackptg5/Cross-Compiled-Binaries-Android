# This script will be executed in post-fs-data service mode
# More info in the main Magisk thread
filever=1
MODPATH=${0%/*}
[ -d $(dirname $MODPATH)/terminalmods ] && mv -f $MODPATH/system/etc/mkshrc $MODPATH/system/etc/mkshrc.bak || mv -f $MODPATH/system/etc/mkshrc.bak $MODPATH/system/etc/mkshrc

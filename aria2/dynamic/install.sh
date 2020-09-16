# Generates ca-certificate.crt file from .0 files present on device
mkdir -p $MODDIR/system/etc/security
if [ -f "$(dirname $MOUNTPATH)/mirror/system/etc/security/ca-certificates.crt" ]; then
  cp -f $(dirname $MOUNTPATH)/mirror/system/etc/security/ca-certificates.crt $MODDIR/system/etc/security/ca-certificates.crt
else
  for i in $(dirname $MOUNTPATH)/mirror/system/etc/security/cacerts*/*.0; do
    echo "$(sed -n "/BEGIN CERTIFICATE/,/END CERTIFICATE/p" $i)" >> $MODDIR/system/etc/security/ca-certificates.crt
  done
fi
echo "etc/security/ca-certificates.crt" >> $MODDIR/.$ibinary
# Since same libs are shared between multiple binaries, don't remove libs on uninstall of binary
sed -i "/lib/d" $MODDIR/.$ibinary

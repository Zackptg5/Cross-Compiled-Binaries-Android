#!/system/bin/sh
# Generates ca-certificate.crt file from .0 files present on device
[ -f "/system/etc/security/ca-certificates.crt" ] && mv -f /system/etc/security/ca-certificates.crt /system/etc/security/ca-certificates.crt.bak
for i in /system/etc/security/cacerts*/*.0; do
  echo "$(sed -n "/BEGIN CERTIFICATE/,/END CERTIFICATE/p" $i)" >> /system/etc/security/ca-certificates.crt
done
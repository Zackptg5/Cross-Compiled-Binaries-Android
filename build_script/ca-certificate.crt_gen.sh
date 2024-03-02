#!/system/bin/sh
# Generates ca-certificate.crt file from .0 files present on device
for i in /system/etc/security/cacerts*/*.0; do
  echo "$(sed -n "/BEGIN CERTIFICATE/,/END CERTIFICATE/p" $i)" >> /system/etc/security/ca-certificates-aria2.crt
done
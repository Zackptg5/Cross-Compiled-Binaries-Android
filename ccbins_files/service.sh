# This script will be executed in late_start service mode
# More info in the main Magisk thread
filever=1
(
until [ "$(getprop sys.boot_completed)" == "1" ]; do
  sleep 5
done
[ -f /storage/emulated/0/.aliases ] || touch /storage/emulated/0/.aliases
[ "$(grep 'cu()' /storage/emulated/0/.aliases 2>/dev/null)" ] || echo -e 'cu() {\n  coreutils --coreutils-prog=${@}\n}' >> /storage/emulated/0/.aliases
[ "$(grep 'TERMINFO=' /storage/emulated/0/.aliases 2>/dev/null)" ] || echo 'export TERMINFO=/system/usr/share/terminfo' >> /storage/emulated/0/.aliases
)&

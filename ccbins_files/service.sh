# This script will be executed in late_start service mode
# More info in the main Magisk thread
MODPATH=${0%/*}
filever=5
(
until [ "$(getprop sys.boot_completed)" == "1" ] && [ -d /storage/emulated/0/Android ]; do
  sleep 1
done
[ -f /storage/emulated/0/.aliases ] || touch /storage/emulated/0/.aliases
grep -q 'cu()' /storage/emulated/0/.aliases 2>/dev/null || echo -e 'cu() {\n  coreutils --coreutils-prog=${@}\n}' >> /storage/emulated/0/.aliases
grep -q 'TERMINFO=' /storage/emulated/0/.aliases 2>/dev/null || echo 'export TERMINFO=/system/usr/share/terminfo' >> /storage/emulated/0/.aliases
if ! grep -q 'alias curl=' /storage/emulated/0/.aliases 2>/dev/null || ! grep -q 'alias aria2c=' /storage/emulated/0/.aliases 2>/dev/null; then
  for i in 'net.dns1' 'net.dns2' 'net.dns3' 'net.dns4'; do
    j="$(getprop $i | sed 's/%.*//')"
    [ "$j" ] || continue
    dnsrvs="$dnsrvs,$j"
  done
  dnsrvs="$(echo "$dnsrvs" | sed 's/^,//')"
  grep -q 'alias curl=' /storage/emulated/0/.aliases 2>/dev/null || echo "alias curl='curl --dns-servers $dnsrvs \"\$@\"'" >> /storage/emulated/0/.aliases
  grep -q 'alias aria2c=' /storage/emulated/0/.aliases 2>/dev/null || echo "alias aria2c='aria2c --async-dns-server=$dnsrvs \"\$@\"'" >> /storage/emulated/0/.aliases
fi
if [ -f $MODPATH/system/etc/zsh/.zshrc ] && [ ! -f /storage/emulated/0/.zsh/.zshrc ]; then
  mkdir -p /storage/emulated/0/.zsh 2>/dev/null
  cp -f $MODPATH/system/etc/zsh/.zshrc /storage/emulated/0/.zsh/.zshrc
  [ -d /storage/emulated/0/.zsh/custom ] || cp -rf $MODPATH/system/etc/zsh/.oh-my-zsh/custom /storage/emulated/0/.zsh/
fi
)&

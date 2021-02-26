# This script will be executed in late_start service mode
# More info in the main Magisk thread
MODPATH=${0%/*}
filever=6
(
until [ "$(getprop sys.boot_completed)" == "1" ] && [ -d /storage/emulated/0/Android ]; do
  sleep 1
done
[ -f /storage/emulated/0/.aliases ] || touch /storage/emulated/0/.aliases
grep -q 'alias cp=' /storage/emulated/0/.aliases 2>/dev/null || echo "alias cp='cp -g'" >> /storage/emulated/0/.aliases
grep -q 'alias mv=' /storage/emulated/0/.aliases 2>/dev/null || echo "alias mv='mv -g'" >> /storage/emulated/0/.aliases
grep -q 'cu()' /storage/emulated/0/.aliases 2>/dev/null || echo -e 'cu() {\n  coreutils --coreutils-prog=${@}\n}' >> /storage/emulated/0/.aliases
grep -q 'TERMINFO=' /storage/emulated/0/.aliases 2>/dev/null || echo 'export TERMINFO=/system/usr/share/terminfo' >> /storage/emulated/0/.aliases

if [ -f $MODPATH/system/etc/zsh/.zshrc ] && [ ! -f /storage/emulated/0/.zsh/.zshrc ]; then
  mkdir -p /storage/emulated/0/.zsh 2>/dev/null
  cp -f $MODPATH/system/etc/zsh/.zshrc /storage/emulated/0/.zsh/.zshrc
  [ -d /storage/emulated/0/.zsh/custom ] || cp -rf $MODPATH/system/etc/zsh/.oh-my-zsh/custom /storage/emulated/0/.zsh/
fi
)&

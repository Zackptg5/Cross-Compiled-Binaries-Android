# dns server fix
sed -i '/^alias curl=/d' /storage/emulated/0/.aliases
if [ -f /data/adb/modules/ccbins/.doh ]; then
  [ "$(head -n1 /data/adb/modules/ccbins/.doh)" == "Cloudflare" ] && dns="1.1.1.1,1.0.0.1" || dns="223.5.5.5,223.6.6.6"
else
  for i in 'net.dns1' 'net.dns2' 'net.dns3' 'net.dns4'; do
    j="$(getprop $i | sed 's/%.*//')"
    [ "$j" ] || continue
    dns="$dns,$j"
  done
  dns="$(echo "$dns" | sed 's/^,//')"
fi
[ $API -lt 31 ] && [ -z "$dns" ] && exit 0
[ "$dns" ] && echo "alias curl='curl --dns-servers $dns \"\$@\"'" >> /storage/emulated/0/.aliases || echo "alias curl='curl --dns-servers 1.1.1.1,1.0.0.1 \"\$@\"'" >> /storage/emulated/0/.aliases

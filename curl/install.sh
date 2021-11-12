# dns server fix
sed -i '/^alias curl=/d' /storage/emulated/0/.aliases
for i in 'net.dns1' 'net.dns2' 'net.dns3' 'net.dns4'; do
  j="$(getprop $i | sed 's/%.*//')"
  [ "$j" ] || continue
  dnsrvs="$dnsrvs,$j"
done
[ $API -lt 31 ] && [ -z "$dnsrvs" ] && exit 0
dnsrvs="$(echo "$dnsrvs" | sed 's/^,//')"
[ "$dnsrvs" ] && echo "alias curl='curl --dns-servers $dnsrvs \"\$@\"'" >> /storage/emulated/0/.aliases || echo "alias curl='curl $dns \"\$@\"'" >> /storage/emulated/0/.aliases

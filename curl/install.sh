# dns server fix
sed -i '/^alias curl=/d' /storage/emulated/0/.aliases
for i in 'net.dns1' 'net.dns2' 'net.dns3' 'net.dns4'; do
  j="$(getprop $i | sed 's/%.*//')"
  [ "$j" ] || continue
  dnsrvs="$dnsrvs,$j"
done
[ "$dnsrvs" ] || exit 0
dnsrvs="$(echo "$dnsrvs" | sed 's/^,//')"
echo "alias curl='curl --dns-servers $dnsrvs \"\$@\"'" >> /storage/emulated/0/.aliases

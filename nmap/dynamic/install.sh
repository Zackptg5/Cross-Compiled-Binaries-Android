# dns server fix
sed -i '/^alias nmap=/d' /storage/emulated/0/.aliases
echo "alias nmap='nmap --system-dns'" >> /storage/emulated/0/.aliases

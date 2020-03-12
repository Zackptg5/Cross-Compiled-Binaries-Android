cd $MODDIR$insloc
for j in $(./$i --list); do
  if [ [ ! -e "/sbin/.magisk/mirror$(echo $insloc | sed 's|^/system/vendor|/vendor|')/$j" ] && [ ! -e "$j" ]; then
    ln -sf $i $j
    echo "/$(echo $insloc | cut -d / -f3-)" >> $MODDIR/.$ibinary
  fi
done
cd $dir

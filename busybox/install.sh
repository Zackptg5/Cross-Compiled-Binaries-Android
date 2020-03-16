cd $MODDIR$insloc
for j in $(./$i --list); do
  if [ ! -e "/sbin/.magisk/mirror$(echo $insloc | sed 's|^/system/vendor|/vendor|')/$j" ] && [ ! -e "$j" ]; then
    ln -sf $i $j
    echo "$(echo $insloc | sed "s|$MODDIR||")/$j" >> $MODDIR/.$ibinary
  fi
done
cd $dir

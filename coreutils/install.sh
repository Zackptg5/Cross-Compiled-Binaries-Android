cd $MODDIR$insloc
for j in $(./$i --help | sed -n "/^ \[/p"); do
  if ([ ! -e "/sbin/.magisk/mirror$(echo $insloc | sed 's|^/system/vendor|/vendor|')/$j" ] && [ ! -e "$j" ] && [ "$j" != "[" ] && [ "$j" != "test" ]) || ([ "$j" == "cp" ] || [ "$j" == "mv" ]); then
    ln -sf $i $j
    echo "/$(echo $insloc | cut -d / -f3-)" >> $MODDIR/.$ibinary
  fi
done
cd $dir

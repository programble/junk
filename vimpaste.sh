#!/bin/bash

FILE=$(basename $1)
vim "$1" -c TOhtml -c "w $FILE.html" -c 'qa!'
scp $FILE.html quartz:/srv/webmount/programble/paste
rm $FILE.html
echo -n "http://programble.cu.cc/paste/$FILE.html" | xclip -selection clipboard

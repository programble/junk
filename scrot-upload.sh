#!/bin/bash

scrot $@ -e 'scp -q $f quartz:/srv/webmount/programble/ss; mv $f ~/images/screenshots; echo -n "http://programble.me/ss/$n" | xclip -selection clipboard; notify-send -i up "Screenshot uploaded" "$n"'

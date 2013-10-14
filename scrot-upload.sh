#!/bin/bash

scrot $@ -e 'scp -q $f quartz:www/ss; mv $f ~/Pictures/screenshots; echo -n "http://files.programble.me/ss/$n" | xclip -selection clipboard; notify-send -i up "Screenshot uploaded" "$n"'

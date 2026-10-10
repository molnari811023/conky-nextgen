#!/bin/sh

   killall conky
   cd "$HOME/.conky/conky-nextgen"
   conky -c "$HOME/.conky/conky-nextgen/clock_cal_combi.conf" &
   cd "$HOME/.conky/conky-nextgen"
   conky -c "$HOME/.conky/conky-nextgen/cpu.conf" &
   cd "$HOME/.conky/conky-nextgen"
   conky -c "$HOME/.conky/conky-nextgen/disk_2_bars.conf" &
   cd "$HOME/.conky/conky-nextgen"
   conky -c "$HOME/.conky/conky-nextgen/info.conf" &
   cd "$HOME/.conky/conky-nextgen"
   conky -c "$HOME/.conky/conky-nextgen/google.conf" &
   cd "$HOME/.conky/conky-nextgen"
   conky -c "$HOME/.conky/conky-nextgen/mem_swap.conf" &
   cd "$HOME/.conky/conky-nextgen"
   conky -c "$HOME/.conky/conky-nextgen/network.conf" &
   cd "$HOME/.conky/conky-nextgen"
   conky -c "$HOME/.conky/conky-nextgen/now-playing.conf" &
   cd "$HOME/.conky/conky-nextgen"
   conky -c "$HOME/.conky/conky-nextgen/top.conf" &
   cd "$HOME/.conky/conky-nextgen"
   conky -c "$HOME/.conky/conky-nextgen/vnstat.conf" &
   cd "$HOME/.conky/conky-nextgen"
   conky -c "$HOME/.conky/conky-nextgen/weather.conf" &
   exit 0


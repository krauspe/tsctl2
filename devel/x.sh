#!/bin/bash

#while read myline
for h in psp8-s1 psp7-s1 cwp10-s1
do
  echo "LINE=$myline"
  ssh $h uptime 

done < list.txt 



#!/bin/bash

# Wind barbs
(cd svg; for i in wind_speed_*; do j=`echo $i|sed s,svg$,png,`; convert +antialias -background transparent $i -resize 35x35 ../$j; done)


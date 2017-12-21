#!/bin/sh

# Wrapper for creating average headposition files that can be passed to maxfilter. 
# Avergae is based on recorded head position throughout files.
#
# By Mikkel C. Vinding (mikkel.vinding@ki.se). Last updated 2017-12-08.

helptxt='''Use as: .../avgHeadPos [name of conditions to combine*]
*consistent naming of files is required. The script will combine all files in current dir starting with that name.
Multiple arguments can be passed. Each name is processed seperatly'''

if [ -z "$@" ]; then
	echo "$helptxt"
	return
fi

path_to_pyfile='/home/natmeg/data_scripts/avg_headpos' #Change depending on which computer is used!

for CON in "$@"
do
	echo "$CON"
	python $path_to_pyfile/NEW_SCRIPT.py $CON   #
done

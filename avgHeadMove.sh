#!/bin/sh

# Wrapper for creating average headposition files that can be passed to maxfilter. 
# Average is based on recorded head position throughout files.
#
# By Mikkel C. Vinding (mikkel.vinding@ki.se). 2017.

helptxt='''
Use as: .../avgHeadPos [name of conditions to combine*] [method]
*consistent naming of files is required. The script will combine all files in current dir starting with that name.
[method] must be either mean or median
'''

if [ -z "$@" ]; then
	echo "$helptxt"
	return
fi

path_to_pyfile='/home/natmeg/data_scripts/avg_headpos' #Change depending on which computer is used!

ipython $path_to_pyfile/headpos_avg.py $1 $2  #



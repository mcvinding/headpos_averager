#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Find files that belong to a condition without repetitions from split files.
Created on Thu Mar 11 13:36:45 2021. @author: mikkel
"""
from os import listdir
import sys

#%%
def find_condition_files(folder, string):

    allfiles = listdir(folder)
    strfiles = [f for f in allfiles if string in f and f.find('-') == -1 and not 'sss' in f]
    strfiles.sort()

    # return strfiles
    print(strfiles) #, sep = " ")  
    # return strfiles

#%% Run
print(len(sys.argv))
if len(sys.argv) < 2:
    raise RuntimeError('Not enough arguments given')
else:
    folder = str(sys.argv[1])             # First argument = folder path
    string = str(sys.argv[2])             # Second argument = condition identifier
    
find_condition_files(folder, string)

#End

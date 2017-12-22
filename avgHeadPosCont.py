#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
Functions for creating average head positions of continous head position estimated 
by MaxFilter head position estimator on one or several files
files to feed to MaxFilter.

@author: mikkel vinding, 2017 (mikkel.vinding@ki.se)
"""

#%% IMPORTS
import sys
import numpy as np
import glob
#import warnings
import imp
import os.path as op
from os import mkdir, getcwd
#import matplotlib.pyplot as plt

try:
    mne_info = imp.find_module('mne')
    found_mne = True
except ImportError:
    found_mne = False
    
if found_mne:
    from mne.io import read_raw_fif
#    from mne.chpi import read_head_pos, head_pos_to_trans_rot_t
    from mne.transforms import rotation_angles, rotation3d, write_trans, quat_to_rot
#    from mne.viz import plot_head_positions, plot_alignment
else:
    print('mne is not present')
    sys.exit()
    
#%% Function
def headpos_avg(condition, method="median", folder=[]):
    """
    Calculate average transformation from dewar to head coordinates, based 
    on the continous head position estimated from MaxFilter

    Parameters
    ----------
    condition : str
        String containing part of common filename, e.g. "task" for files 
        task-1.fif, task-2.fif, etc. Consistent naiming of files is mandatory!
    method : str
        How to calculate "average, "mean" or "median" (default = "median")
    folder : str
        Path to input files. Default = current dir.

    Returns
    -------
    MNE-Python transform object
        4x4 transformation matrix
    """
    
    # Check that the method works
    if method not in ['median','mean']:
        raise RuntimeError('Wrong method. Must be either \"mean\" or "median"!')

    if not folder:                                              # [!] Match up with bash script !
        rawdir = getcwd()
    else:
        rawdir = folder
    
    # Change to subject dir     
    files2combine = glob.glob('%s*' % condition)
    
    if not files2combine:
        print('No files called \"%s\" found in %s' % (condition, rawdir))
        return
    elif len(files2combine) > 1:
        print('Files used for average head pos:')    
        for ib in range(len(files2combine)):
            print('{:d}: {:s}'.format(ib + 1, files2combine[ib]))
    
    # LOAD DATA
    for idx, ffs in enumerate(files2combine):
        print op.join(rawdir,ffs)  
        if idx == 0:
            raw =  read_raw_fif(op.join(rawdir,ffs), preload=True, allow_maxshield=True).pick_types(meg=False, chpi=True)
        else:
            raw.append(read_raw_fif(ffs, preload=True, allow_maxshield=True).pick_types(meg=False, chpi=True))
        
    quat, times = raw.get_data(return_times=True)
    gof = quat[6,]                                              # Godness of fit channel
    fs = raw.info['sfreq']
    
    # In case "record raw" started before "cHPI"
    if np.any(gof < 0.98):
        begsam = np.argmax(gof>0.98)
        
        raw.crop(tmin=raw.times[begsam])
        quat = quat[:,begsam:].copy()
        times = times[begsam:].copy()
        
    H = np.empty([4,4,len(times)])      # Initiate transforms
    init_rot_angles = np.empty([len(times),3])
        
    for i,t in enumerate(times):
        print i
        Hi = np.eye(4,4)
        
        Hi[0:3,3] = quat[3:6,i].copy()
        Hi[:3,:3] = quat_to_rot(quat[0:3,i])
        init_rot_angles[i,:] = rotation_angles(Hi[:3,:3])
        assert(np.sum(Hi[-1]) == 1.0)  # sanity check result
        H[:,:,i] = Hi.copy()
    
    H_mean = np.mean(H, axis=2)                 # stack, then average over new dim
    assert(np.sum(H_mean[-1]) == 1.0)  # sanity check result

    mean_rot_xfm = rotation3d(*tuple(np.mean(init_rot_angles, axis=0)))  # stack, then average, then make new xfm
    H_mean[:3,:3] = mean_rot_xfm

    # Create the mean structure and save as .fif    
    mean_trans = raw.info['dev_head_t']  # use the last info as a template
    mean_trans['trans'] = H_mean.copy()

#    plot_alignment(raw.info,subject='0406',subjects_dir='/home/mikkel/PD_motor/fs_subjects_dir/',dig=True, meg='helmet')

    mean_trans_folder = op.join(rawdir, 'trans_files')
    if not op.exists(mean_trans_folder):                      # Make sure output folder exists
        mkdir(mean_trans_folder)
        
    mean_trans_file = op.join(mean_trans_folder, condition+'-trans.fif')
    write_trans(mean_trans_file, mean_trans)
    print("Wrote "+mean_trans_file)
    
    return mean_trans

#%% RUN FUNCTION
condi = sys.argv[1]
method = sys.argv[2]
rawdir = getcwd()

headpos_avg(condi, method, rawdir)

print('DONE')
    
        
        
    
        
        
        
        
        
        
        

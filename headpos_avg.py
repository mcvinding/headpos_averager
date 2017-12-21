#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
Created on Wed Dec  6 15:06:32 2017
@author: mikkel
"""

#%% IMPORTS
import sys
import numpy as np
import glob
import warnings
import imp
import os.path as op
from os import listdir, mkdir, path, getcwd, chdir
import matplotlib.pyplot as plt

try:
    mne_info = imp.find_module('mne')
    found_mne = True
except ImportError:
    found_mne = False
    
if found_mne:
    from mne.io import Raw
    from mne.chpi import read_head_pos, head_pos_to_trans_rot_t
    from mne.transforms import rotation_angles, rotation3d, write_trans, quat_to_rot, Transform
    from mne.viz import plot_head_positions, plot_alignment
else:
    print('mne is not present')
    sys.exit()
    
#%%    
def headpos_avg(filename, folder=[], overwrite=False):
    
    
#    fname_pos = '/archive/20055_parkinson_motor/MEG/NatMEG_0406/170420/headpos/rest_ec_1_headpos.pos'
#    fname_fif = '/archive/20055_parkinson_motor/MEG/NatMEG_0406/170420/rest_ec_1_quat.fif'


    if not folder:                     # [!] Match up with bash script !
        rawdir = getcwd()
    else:
        rawdir = folder

    fname = filename.split('/')[-1]
    fprefx = fname[:-4]                     # Remove 
    
    
#    pos = read_head_pos(fname_pos)                    #op.join(rawdir, filename))   
#    plot_head_positions(pos, mode='traces')
#    plot_head_positions(pos, mode='field')
        

# FIND FIF FILES...        
        

    raw = Raw(fname_fif, preload=True).pick_types(meg=False, chpi=True)
        
    quat, times = raw.get_data(return_times=True)
    gof = quat[6,]   # Godness of fit channel
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
    
    H_mean = np.mean(H, axis=2)  # stack, then average over new dim
    assert(np.sum(H_mean[-1]) == 1.0)  # sanity check result

    mean_rot_xfm = rotation3d(*tuple(np.mean(init_rot_angles, axis=0)))  # stack, then average, then make new xfm
    H_mean[:3,:3] = mean_rot_xfm

    # Create the mean structure and save as .fif    
    mean_trans = raw.info['dev_head_t']  # use the last info as a template
    mean_trans['trans'] = H_mean.copy()

    plot_alignment(raw.info,subject='0406',subjects_dir='/home/mikkel/PD_motor/fs_subjects_dir/',dig=True, meg='helmet')
    
    raw_meg = Raw(fname_fif)
    rawT = raw_meg.copy()
    rawT.info['dev_head_t']['trans'] = H_mean.copy()            # mean_trans.copy()
    
    write_trans()
    
#    fig = plot_alignment(raw_meg.info, trans=None, dig=True, eeg=False,
#                         surfaces=[], meg=True, coord_frame='meg')
#    plot_alignment(rawT.info, trans=None, dig=True, eeg=False,
#                         surfaces=[], meg=True, coord_frame='meg', fig=fig)
    
    
##    # Change to subject dir                                       # Combining several files will be added later
#    if not condition:
#        files2combine = listdir(rawdir)
#    #    print('Using all files in %s' % rawdir)
#    #elif isinstance(condition,basestring):
#    #    files2combine = glob.glob('%s*' % condition)
#    else:
#        files2combine = glob.glob('%s*' % condition)
#
#    if not files2combine:
#        print('No files called \"%s\" found in %s' % (condition, rawdir))
#        return
#    elif len(files2combine) < 2:
#        raise RuntimeError('Only one file, please check!')
#    
#    print('Files used for average head pos:')    
#    for ib in range(len(files2combine)):
#        print('{:d}: {:s}'.format(ib + 1, files2combine[ib]))
        
        
    
        
        
        
        
        
        
        

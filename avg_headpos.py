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
import warnings
import imp
import os.path as op
#import matplotlib.pyplot as plt
from os import listdir, mkdir, path, getcwd, environ

try:
    mne_info = imp.find_module('mne')
    found_mne = True
except ImportError:
    found_mne = False
    
if found_mne:
    from mne.io import read_raw_fif, Raw
#    from mne.chpi import read_head_pos, head_pos_to_trans_rot_t
    from mne.transforms import rotation_angles, rotation3d, write_trans, quat_to_rot
    from mne.viz import plot_head_positions, plot_alignment
else:
    print('mne is not present')
    sys.exit()
    
#A ppend toolbox dir
sys.path.append(environ["script_path"])
from summary_funs import total_dist_moved, plot_movement
#sys.path.append('/home/mikkel/avg_headpos/')                #[!!!]


###############################################################################
## MAKE FUNCTIONS
###############################################################################
#%% averager for continous head postion
def contAvg_headpos(condition, method='median', folder=[], summary=True):
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
    method = method.lower()
    if method not in ['median','mean']:
        raise RuntimeError('Wrong method. Must be either \"mean\" or "median"!')
    if not condition:
        raise RuntimeError('You must provide a conditon!')

    # Get and set folders
    if not folder:        
        rawdir =  getcwd()                                  # [!] Match up with bash script !
    else:
        rawdir = folder
        
    print(rawdir)
    quatdir = op.join(rawdir,'quat_files')
    
    mean_trans_folder = op.join(rawdir, 'trans_files')
    if not op.exists(mean_trans_folder):                      # Make sure output folder exists
        mkdir(mean_trans_folder)
        
    mean_trans_file = op.join(mean_trans_folder, condition+'-trans.fif')
    if op.isfile(mean_trans_file):
        warnings.warn('N"%s\" already exists is %s. Delete if you want to rerun' % (mean_trans_file, mean_trans_folder), RuntimeWarning)
        return
    
    # Change to subject dir     
    files2combine = [f for f in listdir(quatdir) if condition in f and '_quat' in f]
    
    if not files2combine:
        raise RuntimeError('No files called \"%s\" found in %s' % (condition, quatdir))
    elif len(files2combine) > 1:
        print('Files used for average head pos:')    
        for ib in range(len(files2combine)):
            print('{:d}: {:s}'.format(ib + 1, files2combine[ib]))
    else:
        print('Will find average head pos in %s' % files2combine)    
    
    # LOAD DATA
    for idx, ffs in enumerate(files2combine):
        if idx == 0:
            raw =  read_raw_fif(op.join(quatdir,ffs), preload=True, allow_maxshield=True).pick_types(meg=False, chpi=True)
        else:
            raw.append(read_raw_fif(op.join(quatdir,ffs), preload=True, allow_maxshield=True).pick_types(meg=False, chpi=True))
        
    quat, times = raw.get_data(return_times=True)
    gof = quat[6,]                                              # Godness of fit channel
    fs = raw.info['sfreq']
    
    # In case "record raw" started before "cHPI"
    if np.any(gof < 0.98):
        begsam = np.argmax(gof>0.98)
        
        raw.crop(tmin=raw.times[begsam])
        quat = quat[:,begsam:].copy()
        times = times[begsam:].copy()
        
    # Make summaries
    plot_movement(quat, times, dirname=rawdir, identifier=condition)
    total_dist_moved(quat, times, write=True, dirname=rawdir, identifier=condition)
    
    # Get continous transformation    
    print('Reading transformation. This will take a while...')
    H = np.empty([4,4,len(times)])                              # Initiate transforms
    init_rot_angles = np.empty([len(times),3])
        
    for i,t in enumerate(times):
        Hi = np.eye(4,4)
        Hi[0:3,3] = quat[3:6,i].copy()
        Hi[:3,:3] = quat_to_rot(quat[0:3,i])
        init_rot_angles[i,:] = rotation_angles(Hi[:3,:3])
        assert(np.sum(Hi[-1]) == 1.0)                           # sanity check result
        H[:,:,i] = Hi.copy()
    
    if method in ["mean"]:
        H_mean = np.mean(H, axis=2)                 # stack, then average over new dim
        mean_rot_xfm = rotation3d(*tuple(np.mean(init_rot_angles, axis=0)))  # stack, then average, then make new xfm
    elif method in ["median"]:
        H_mean = np.median(H, axis=2)                 # stack, then average over new dim
        mean_rot_xfm = rotation3d(*tuple(np.median(init_rot_angles, axis=0)))  # stack, then average, then make new xfm        
        
    H_mean[:3,:3] = mean_rot_xfm
    assert(np.sum(H_mean[-1]) == 1.0)  # sanity check result

    # Create the mean structure and save as .fif    
    mean_trans = raw.info['dev_head_t']  # use the last info as a template
    mean_trans['trans'] = H_mean.copy()

    # Write file
    write_trans(mean_trans_file, mean_trans)
    print("Wrote "+mean_trans_file)
    
    return mean_trans

#%% Averager for intial head position

def initAvg_headpos(condition=[], folder=[]):
    """
    Write the average head position based of the initial fit of several 
    independent  files and save to a trans fif file

    Parameters
    ----------
    condition : str
        String containing part of common filename, e.g. "task" for files 
        task_a.fif, task_b.fif, etc. Consistent naiming of files is mandatory! 
        If no condition is provided, it will average all files in folder.
    folder : str
        Path to input files. Default = current dir.

    Returns
    -------
    None
        
    """
        
    if not folder:
        rawdir = getcwd()
    else:
        rawdir = folder
    
    # Change to subject dir     
    if not condition:
        files2combine = listdir(rawdir)
        print('Using all files in %s' % rawdir)
    else:
        files2combine = glob.glob('%s*' % condition)
    
    if not files2combine:
        print('No files called \"%s\" found in %s' % (condition, rawdir))
        return
    elif len(files2combine) < 2:
        warnings.warn('Only one file, please check!', RuntimeWarning)                      # [!!!] should it just copy the initial headpos?
        
    # Define output
    mean_trans_folder = path.join(rawdir, 'trans_files')
    if not path.exists(mean_trans_folder):
        mkdir(mean_trans_folder)
        
    mean_trans_file = path.join(mean_trans_folder, condition+'-trans.fif')
    if op.isfile(mean_trans_file):
        warnings.warn('N"%s\" already exists is %s. Delete if you want to rerun' % (mean_trans_file, mean_trans_folder), RuntimeWarning)
        return        
    
    files2combine = [f for f in files2combine if '.fif' in f]               # Make sure only fif files
    files2combine.sort()

    print('Files used for average head pos:')    
    for ib in range(len(files2combine)):
        print('{:d}: {:s}'.format(ib + 1, files2combine[ib]))
    
    init_xfm = []
    init_rot = []
    for ff in files2combine:
        fname = path.join(rawdir, ff)                                           # first file is enough NOT ANYMORE!
        with warnings.catch_warnings():                                         # suppress some annoying warnings for now
            warnings.simplefilter("ignore")
            info = Raw(fname, preload=False, verbose=False, allow_maxshield=True).info
            print('Ignore the warning above. We\'ll run MaxFilter in a few moments...')
    
        init_xfm += [info['dev_head_t']['trans']]
        # translations: info['dev_head_t']['trans'][:, 3][:-1]
        init_rot += [info['dev_head_t']['trans'][:3, :3]]
        
    mean_init_xfm = np.mean(np.stack(init_xfm), axis=0)  # stack, then average over new dim
    init_rot_angles = [rotation_angles(m) for m in init_rot]
    
    mean_init_rot_xfm = rotation3d(*tuple(np.mean(np.stack(init_rot_angles), axis=0)))  # stack, then average, then make new xfm
    
    assert(np.sum(mean_init_xfm[-1]) == 1.0)            # sanity check result
    mean_trans = info['dev_head_t']                     # use the last info as a template
    mean_trans['trans'] = mean_init_xfm                 # replace the transformation
    mean_trans['trans'][:3, :3] = mean_init_rot_xfm     # replace the rotation part
    
    mean_init_headpos = mean_trans['trans'][:-1, -1]  # meters
    print('Mean head position (device coords): ({:.1f}, {:.1f}, {:.1f}) mm'.\
          format(*tuple(mean_init_headpos*1e3)))
    print('Discrepancies from mean:')
    for ib, xfm in enumerate(init_xfm):
        diff = 1e3 * (xfm[:-1, -1] - mean_init_headpos)
        rmsdiff = np.linalg.norm(diff)
        print('\tSession {:d}: norm {:.1f} mm ({:.1f}, {:.1f}, {:.1f}) mm '.\
              format(ib + 1, rmsdiff, *tuple(diff)))
              
    mean_rots = rotation_angles(mean_trans['trans'][:3, :3])  # these are in radians
    mean_rots_deg = tuple([180. * rot / np.pi for rot in mean_rots])  # convert to deg
    print('Mean head rotations (around x, y & z axes): ({:.1f}, {:.1f}, {:.1f}) deg'.\
          format(*mean_rots_deg))
    print('Block discrepancies from mean:')
    for ib, rot in enumerate(init_rot):   
        cur_rots = rotation_angles(rot)
        diff = tuple([180. * cr / np.pi - mr for cr, mr in zip(cur_rots, mean_rots_deg)])
        print('\tSession {:d}: ({:.1f}, {:.1f}, {:.1f}) deg '.\
              format(ib + 1, *tuple(diff)))
    
    # Write trans file        
    write_trans(mean_trans_file, mean_trans)
    print("Wrote "+mean_trans_file)
    
#%% RUN FUNCTIONS
print(len(sys.argv))
if len(sys.argv) < 3:
    raise RuntimeError('Not enough arguments given')
if len(sys.argv) < 4:
    avgType = str(sys.argv[1])               # First argument = method to make average
    condi = sys.argv[2]                 # Second argument = condition
    rawdir = getcwd()
    method = []
if len(sys.argv) == 4:
    avgType = str(sys.argv[1])               # First argument = method to make average
    condi = sys.argv[2]                 # Second argument = condition
    rawdir = sys.argv[3]                # Third argument = directory
    method = []
else:
    avgType = str(sys.argv[1])               # First argument = method to make average
    condi = sys.argv[2]                 # Second argument = condition
    rawdir = sys.argv[3]                # Third argument = directory
    method = str(sys.argv[4])           # Fourth argument = average method

print "AVERAGE TYOE = "+avgType
print "METHOD = "+method

if 'continous' in avgType:
    if not method:
        contAvg_headpos(condi, folder=rawdir)
    else:
        contAvg_headpos(condi, folder=rawdir, method=method)
elif 'initial' in avgType:
    initAvg_headpos(condi,folder=rawdir)
else:
    raise RuntimeError('Argument %s not accepted' % avgType)

print('DONE')     
        
        

#!/home/mikkel/bin/python
# -*- coding: utf-8 -*-
"""
Created on Thu Sep 15 13:39:48 2016
@author: mikkel, 2016-2017
Functions for creating average head positions of initial head position from several
files, to feed to MaxFilter. This script is build from script by Chris Bailey (cjb@cfin.au.dk)
"""
#%% IMPORTS
import sys
import numpy as np
import glob
import warnings
import imp
from os import listdir, mkdir, path, getcwd, chdir

try:
    mne_info = imp.find_module('mne')
    found_mne = True
except ImportError:
    found_mne = False
    
if found_mne:
    from mne.io import Raw
    from mne.transforms import rotation_angles, rotation3d, write_trans
else:
    print('mne is not present')
    sys.exit()

#%% Get sys vars 
condi = sys.argv[1]
rawdir = getcwd()

#%% Main function
def avg_headpos(condition=[], folder=[]):
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
        raise RuntimeError('Only one file, please check!')                      # [!!!] should it just copy the initial headpos?
    
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
    mean_trans_folder = path.join(rawdir, 'trans_files')
    if not path.exists(mean_trans_folder):
        mkdir(mean_trans_folder)
        
    mean_trans_file = path.join(mean_trans_folder, condition+'-trans.fif')
    write_trans(mean_trans_file, mean_trans)
    print("Wrote "+mean_trans_file)

#%% RUN FUNCTION
avg_headpos(condi, rawdir)

print('DONE')

    
    
    
    
    
    
    
    
    
    
    
    

#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
Created on Mon Nov  4 15:17:28 2019
@author: mikkel
"""
import os
from os import path as op
import mne
import numpy
import matplotlib.pyplot as plt

#%% Plot summary with MNE plot fun
def plot_movement(quat, times, dirname='.', identifier=None):
    """
    Plot trances of movement for insepction. Uses mne.viz.plot_head_positions
    """
    
    qT = numpy.vstack((times, quat)).transpose()
    fig = mne.viz.plot_head_positions(qT, mode='traces', show=False)#, info=info)
    
    #Save figure
    savepath = _save_dir_check(dirname)
    if not identifier:
        fname = 'summary.png'
    else:
        fname = str(identifier)+'_summary.png'

    fig.savefig(op.join(savepath, fname))
        
#%% Summary        
def total_dist_moved(quat, times, write=True, dirname='.', identifier=[]):
    d1 = quat[0:3,0:-2]
    d2 = quat[0:3,1:-1]
        
    dnorm = numpy.sqrt(numpy.sum((d1-d2)**2, axis=0))
    dcum = numpy.cumsum(dnorm)
    
    avg = max(dcum)/(max(times)-min(times))
    
    text = 'Moved a cummulative total of %.2f cm during the session\nTotal recording time: %.2f min. (%.1f s)\nAverage movement: %.2f mm/s\n'
    
    if write:
        savepath = _save_dir_check(dirname)
        if not identifier:
            fname = op.join(savepath, 'summary.txt')
        else:
            fname = op.join(savepath, str(identifier)+'_summary.txt')
            
        fobj = open(fname, "w")
        fobj.write((text % (max(dcum)*100, max(times)/60, max(times), avg*1000)))
        fobj.close()
        
    print(text % (max(dcum)*100, max(times)/60, max(times), avg*1000))

def _save_dir_check(dirname):
    savepath = op.join(dirname, 'summary')
    if not op.exists(savepath):
        os.mkdir(savepath)
    return savepath


#fname = op.join(data_path, 'rest_ec_headpos.pos')
#
#pos = mne.chpi.read_head_pos(fname)
#
#figure = mne.viz.plot_head_positions(pos, mode='traces')
#
#
#
#quatdir = "/archive/20079_parkinsons_longitudinal/MEG/NatMEG_0522/190426/quat_files"
#files2combine = [op.join(quatdir, 'rest_ec_quat.fif' )]
#
#
#figure = mne.viz.plot_head_positions(qT, mode='traces')
#figure2 = mne.viz.plot_head_positions(pos, mode='traces')

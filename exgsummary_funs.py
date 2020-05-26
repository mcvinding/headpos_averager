#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri May 15 14:47:38 2020
@author: mikkel
"""
import mne
import os.path as op
import numpy as np
from scipy.stats import zscore
from mne.preprocessing import create_ecg_epochs, create_eog_epochs
import matplotlib.pyplot as plt

#%% ECG summary

def get_pulsebpm(raw):
    ecg_epochs = create_ecg_epochs(raw, ch_name='ECG003', tmin=-.5, tmax=.5, preload=True)
    bpm = len(ecg_epochs)/(raw.n_times/raw.info['sfreq']/60.0)
    return bpm

#%% EOG blink summary
    
def get_blinks(raw, chan='EOG002', dur_method='gradient'):
    '''
    Get summary statistics of blink from EOG channels
    
        USE: get_blinks(raw, chan='EOG002', dur_method='gradient')
    
        raw         : MNE raw structure
        chan        : EOG channels with blinks
        dur_method  : Metohd for dermining duration of blink ('gradient' or 'zscore')
    '''
    
    # Find EOG epochs with MNE funs
    picks = mne.pick_types(raw.info, meg=False, eeg=False, eog=True, ecg = False, emg=False, misc=False, stim=False, exclude='bads')
    raw_filt = raw.copy().filter(1, 30, picks=picks)
    eog_epochs = create_eog_epochs(raw_filt, reject=dict(eog=1), tmin=-.5, tmax=.5, ch_name=chan, thresh=100e-6)  # get single EOG trials
    # eog_epochs.pick(picks)
    eog_epochs.pick_channels([chan])
    
    eog_dat = eog_epochs.get_data().squeeze()
    
    # BLINK DURATION
    # Zscore
    if dur_method == 'zscore':
        # zz_top = zscore(eog_dat[0])
        zz = zscore(eog_dat, axis=1)
       
        for ii, zi in enumerate(zz):
            startidx = np.where(abs(zi) == np.amax(abs(zi)))[0]
            while abs(zi)[startidx] > 0.5*np.amax(abs(zi)):
                startidx = startidx-1
            endidx = np.where(abs(zi) == np.amax(abs(zi)))[0]
            while abs(zi)[endidx] > 0.5*np.amax(abs(zi)):
                endidx = endidx+1   
        
        plt.plot(eog_dat[0])
        plt.vlines(startidx, np.amin(eog_dat[0]), np.amax(eog_dat[0]))
        plt.vlines(endidx, np.amin(eog_dat[0]), np.amax(eog_dat[0]))
    
    # Gradient
    if dur_method == 'gradient':

        # gr0 = np.gradient(eog_dat[0])
        gr = np.gradient(eog_dat, axis=1)
        # plt.plot(gr0)
        plt.plot(gr[0])

        for ii, gi in enumerate(gr):
            print(len(gi), ii)
            
            imin = np.where(gi == np.amin(gi))[0]
            imax = np.where(gi == np.amax(gi))[0]
       
        if imin < imax:
            startidx = imin.copy()
            endidx = imax.copy()
            while gr[startidx] < 0.5*np.amin(gr):
                startidx = startidx-1
            while gr[endidx] > 0.5*np.amax(gr):
                endidx = endidx+1
        else:
            startidx = imax
            endidx = imin
            while gr[startidx] > 0.5*np.amax(gr):
                startidx = startidx-1
            while gr[endidx] < 0.5*np.amin(gr):
                endidx = endidx+1
    
        plt.vlines(startidx, np.amin(eog_dat[0]), np.amax(eog_dat[0]), 'r')
        plt.vlines(endidx, np.amin(eog_dat[0]), np.amax(eog_dat[0]), 'r')

    
    
    # Find time of blink peaks
    # Get durations
        
    
   
print('Returned tuple of arrays :', result)
print('List of Indices of maximum element :', result[0])
   
    
eog_epochs.pick
eog_epochs.
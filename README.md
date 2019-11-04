# Headpos Averager
Project to calculate average head position that will be used as starting position in MaxFilter head movement compensation.

## Content:
* maxfilter_avgHead.sh : Wrapper that will run the entire pipeline and execute the relevant scripts incl. running Neruomag MaxFilter (see below!) Shell script.
* avg_headpos.py : Python functions for getting mean/median transformation matrix from continous head position estimation data in a fif file or average from initial head position across different files. Python script.
* maxfilter_master :  Wrapper that will run Neuromag MaxFilter with any default settings. Shell script.

## Usage:
1) Copy the master (maxfilter_avgHead.sh or maxfilter_master) to your own directory.
2) Change the settings in the headers to match your desired processing pipeline.
3) [?] Make executable [?]
4) Run script

## How to
Be aware of the following before running the scripts: make sure files you want to combine all are named in a similar way with a common string that is used to identify related files: e.g. task-1.fif, task-2.fif, etc. The common string is what you specify in in variable **trans_conditions** (multiple names can be specified for different conditions). The files must also be uniquely identified by the common string so that the common string does not occur in both files. E.g. task-1.fif and new-task.fif will both be considered to be part of a group called "task".

## Dependencies:
This pipeline is a wrapper for running Neuromag MaxFilter inside the NatMEG infrastructure at Karolinska Insitutet, Sweden (www.natmeg.se). Neuromag MaxFilter is a commercial software licenses by Electra Neuromag.
The head position averagers are written in Python and use functions from MNE-Python (https://martinos.org/mne/stable/index.html).
The pipeline has been tested to work on DANA (last: 2018-09-25), but no guarrantee is provided that it will work elsewhere!

## Feedback:
If you use this tool, please let me know how it works at https://github.com/mcvinding/headpos_averager or mailto:mikkel.vinding@ki.se
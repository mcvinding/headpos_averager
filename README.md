# Headpos Averager
Project to calculate average head position that will be used as starting position in MaxFilter head movement compensation.

## Content:
* maxfilter_avgHead.sh : Wrapper that will run the entire pipeline and execute the relevant scripts incl. running Neruomag MaxFilter (see below!) Shell script.
* avgHeadPosCont.py : Script for getting mean/median transformation matrix from continous head position estimation data in a fif file. Python script.
* avgHeadPosInt.py : Script for getting mean/median transformation matrix from initial head position across several independent fif files. Python script.
* avgHeadMove.sh : wrapper for calling avgHeadPosCont.py from terminal. Shell script.
* avgHeadPos.sh : wrapper for calling avgHeadPosInit.py from terminal. Shell script.
* maxfilter_master :  Wrapper that will run Neuromag MaxFilter with any default settings. Shell script.

## Usage:
1) Copy the master (maxfilter_avgHead.sh or maxfilter_master) to your own directory.
2) Change the settings in the headers to match your desired processing pipeline.
3) [?] Make executable [?]
4) Run script

## Dependencies:
This pipeline is a wrapper for running Neuromag MaxFilter inside the NatMEG infrastructure at Karolinska Insitutet, Sweden (www.natmeg.se). Neuromag MaxFilter is a commercial software licenses by Electra Neuromag.
The head position averagers are written in Python and use functions from MNE-Python (https://martinos.org/mne/stable/index.html).
The pipeline has been tested to work on DANA (last: 2017-12-22), but no guarrantee is provided that it will ork elsewhere!

## Feedback:
If you use this tool, please let me know how it works at https://github.com/mcvinding/headpos_averager or mailto:mikkel.vinding@ki.se

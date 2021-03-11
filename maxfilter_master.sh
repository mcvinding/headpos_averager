#!/bin/bash

## Script for automatic maxfilter processing
## by Lau M. Andersen 2016-04-12

#############################################################################################################################################################################################################################################################
## These are the ONLY parameters you should change (as according to your wishes) 
#############################################################################################################################################################################################################################################################

project=your_project_name_here    ## the name of your project in /neuro/data/sinuhe
correlation=0.98
autobad=on # on/off
badlimit=7 					# Detection rate for autobad. Default=7.
tsss_default=on # on/off (if off does Signal Space Separation, if on does temporal Signal Space Separation)
cal=/neuro/databases/sss/sss_cal.dat
ctc=/neuro/databases/ctc/ct_sparse.fif
movecomp_default=on # on/off
trans=off # on/off
transformation_to=default ## default is "default", but you can supply your own file 
empty_room_files=( 'empty_room.fif' 'also_empty_room.fif' 'etc.' ) ## put the names of your empty room files (consistent naming makes it a lot easier) (files in this array won't have "movecomp" applied) (no commas between files and leave spaces between first and last brackets)
headpos=off # on/off ## if "on", no movement compensation (movecomp is automatically turned off, even if specified "on")
force=off # on/off, "forces" the command to ignore warnings and errors and OVERWRITES if a file already exists with that name
downsampling=off # on/off, downsamples the data with the factor below
downsampling_factor=4 # must be an INTEGER greater than 1, if "downsampling = on". If "downsampling = off", this argument is ignored
sss_files=( 'only_apply_sss_to_this_file.fif' 'resting_state.fif' ) ## put the names of files you only want SSS on (can be used if want SSS on a subset of files, but tSSS on the rest)
apply_linefreq=off ## on/off
linefreq_Hz=50 ## set your own line freq filtering (ignored if above is off)

#############################################################################################################################################################################################################################################################
## DON'T CHANGE ANYTHING BELOW HERE (UNLESS YOU REALLY KNOW WHAT YOU ARE DOING!) 
#############################################################################################################################################################################################################################################################

data_path=/neuro/data/sinuhe
cd $data_path
cd $project/MEG

#############################################################################################################################################################################################################################################################
## abort if project folder doesn't exist
#############################################################################################################################################################################################################################################################

if [ $? -ne 0 ]  
then
	echo "specified project folder doesn't exist (change project variable)"
	exit 1
fi

#############################################################################################################################################################################################################################################################
## create set_movecomp function (sets movecomp according to wishes above and abort if set incorrectly, this is a function such that it can be changed throughout the script if empty_room files are found) 
#############################################################################################################################################################################################################################################################

set_movecomp () 
{

	if [ "$1" = 'on' ]
	then
		movecomp=-movecomp
		movecomp_string=_mc
	elif [ "$1" = "off" ]
	then	
		movecomp=
		movecomp_string=
	else echo 'faulty "movecomp" setting (must be on or off)'; exit 1
	fi

}

#############################################################################################################################################################################################################################################################
## create set_tsss function
#############################################################################################################################################################################################################################################################

set_tsss ()
{
	if [ "$1" = 'on' ]
	then
		tsss=-st
		tsss_string=_tsss
	elif [ "$1" = "off" ]
	then
		tsss=
		tsss_string=_sss
	else echo 'faulty "tsss" setting (must be on or off)'; exit 1
	fi
}

#############################################################################################################################################################################################################################################################
## set linefreq according to wishes above and abort if set incorrectly
#############################################################################################################################################################################################################################################################

if [ "$apply_linefreq" = 'on' ]
then
	linefreq="-linefreq $linefreq_Hz"
	linefreq_string=_linefreq_$linefreq_Hz
elif [ "$apply_linefreq" = 'off' ]
then
	linefreq=
	linefreq_string=
else echo 'faulty "apply_linefreq" setting (must be on or off)'; exit 1;
fi
	

#############################################################################################################################################################################################################################################################
## set trans according to wishes above and abort if set incorrectly
#############################################################################################################################################################################################################################################################

if [ "$trans" = 'on' ]
then
	trans="-trans ${transformation_to}"
	trans_string=_trans_${transformation_to}

elif [ "$trans" = "off" ]
then
	trans=
	trans_string=
else echo 'faulty "trans" setting (must be on or off)'; exit 1;
fi

#############################################################################################################################################################################################################################################################
## set headpos (head position)  according to wishes above and abort if set incorrectly
#############################################################################################################################################################################################################################################################

if [ "$headpos" = 'on' ]
then
	headpos=-headpos
	headpos_string=_quat
elif [ "$headpos" = "off" ]
then
	headpos=
	headpos_string=
else echo 'faulty "headpos" setting (must be on or off)'; exit 1;
fi

#############################################################################################################################################################################################################################################################
## set <force> parameter according to wishes above and abort if set incorrectly
#############################################################################################################################################################################################################################################################

if [ "$force" = 'on' ]
then
	force="-force"
elif [ "$force" = "off" ]
then
	force=
else echo 'faulty "force" setting (must be on or off)'; exit 1;
fi

#############################################################################################################################################################################################################################################################
## set <downloading> parameter according to wishes above and abort if set incorrectly
#############################################################################################################################################################################################################################################################

if [ "$downsampling" = 'on' ]
then
	if [ $downsampling_factor -gt 1 ]
	then
		ds="-ds "$downsampling_factor
		ds_string=_ds_$downsampling_factor
	else echo "downsampling factor must be an INTEGER greater than 1";
	fi
	
	
elif [ "$downsampling" = 'off' ]
then
	ds=
	ds_string=
else echo 'faulty "downsampling" setting (must be on or off)'; exit 1;
fi


############################################################################################################################################################################################################################################################
## find all subject folders in project
############################################################################################################################################################################################################################################################

subjects_and_dates=( $(find . -maxdepth 2 -mindepth 2 -type d -exec echo {} \;) )

############################################################################################################################################################################################################################################################
## loop over subject folders
############################################################################################################################################################################################################################################################

for subject_and_date in "${subjects_and_dates[@]}"
do
	
	cd $data_path/$project/MEG/$subject_and_date/
	mkdir log ## create log file directory if it doesn't already exist
	####################################################################################################################################################################################################################################################
	## loop over files in subject folders	####################################################################################################################################################################################################################################################
	
	for filename in `ls -p | grep -v / `;
	do


		############################################################################################################################################################################################################################################
		## check whether file is in the empty_room_files array and change movement compensation to off is so, otherwise use the movecomp_default setting		############################################################################################################################################################################################################################################
		
		if [ $movecomp_default = 'on' ]
		then
			set_movecomp 'on'
		else set_movecomp 'off'
		fi
		
		for empty_room_file in ${empty_room_files[*]}
		do
			if [ -n $filename ]
			then	if [ $empty_room_file = $filename ]
				then
					set_movecomp 'off'
				fi
			fi
		done
		
		if [ -n "$headpos" ]
			then 	if [ $headpos = "-headpos" ]
				then
				set_movecomp 'off'
				fi
		fi

		############################################################################################################################################################################################################################################
		## check whether file is in the sss_files array and change tsss to off is so, otherwise use the tsss_default setting		############################################################################################################################################################################################################################################
		
		if [ $tsss_default = 'on' ]
		then
			set_tsss 'on'
		else set_tsss 'off'
		fi
		
		for sss_file in $sss_files
		do
			if [ -n $sss_file ]
			then	if [ $sss_file = $filename ]
				then
					set_tsss 'off'
				fi
			fi
		done


		############################################################################################################################################################################################################################################
		## output arguments		############################################################################################################################################################################################################################################

		length=${#filename}-4  ## the indices that we want from $file (everything except ".fif")
		output_file=${filename:0:$length}${tsss_string}${movecomp_string}${trans_string}${headpos_string}${linefreq_string}${ds_string}.fif ## the name of the output file
		
		############################################################################################################################################################################################################################################
		## the actual maxfilter command		############################################################################################################################################################################################################################################

		/neuro/bin/util/maxfilter -f ${filename} -o ${output_file} $force $tsss $ds -corr $correlation $movecomp $trans -autobad $autobad -badlimit $badlimit -cal $cal -ctc $ctc -v $headpos $linefreq | tee -a ./log/${filename:0:$length}${tsss_string}${movecomp_string}${trans_string}${headpos_string}${linefreq_string}${ds_string}.log
	done

	####################################################################################################################################################################################################################################################
	## file loop ends	####################################################################################################################################################################################################################################################

done

############################################################################################################################################################################################################################################################
## subjects loop ends
############################################################################################################################################################################################################################################################

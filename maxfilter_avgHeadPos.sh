#!/bin/bash

## Script for automatic maxfilter processing where movement correction is done by shifting to
## the average headposition across the session.
##
## Run SSS movement estimation
## Run Python or matlab scripts to get average position from output
## Save in -trans file or update in SSS file
## Re-run maxfilter with correct settings (tSSS, movecomp, etc.) and transform to avg. headpos.
##
## by Mikkel C. Vinding (2017-12-08) and Lau M. Andersen (2016-04-12)
## for question contact: mikkel.vinding@ki.se

###########################################################################################################################################################################
# TO DO:
# - Run SSS movement estimation
# - Run Python or matlab scripts to get average position from output [Mot present on this PC yet - 2017-12-08]
# - - Save in -trans file or update in SSS file
# - re-run maxfilter with correct settings (tSSS, movecomp, etc.) and transform to avg. headpos.
#
# - Read in more than one file (e.g. for recordings over 2GB)
#

#############################################################################################################################################################################################################################################################
## These are the ONLY parameters you should change (as according to your wishes)
#############################################################################################################################################################################################################################################################

project=parkinson_motor    ## the name of your project in /neuro/data/sinuhe
correlation=0.98
autobad=on # on/off
tsss_default=on # on/off (if off does Signal Space Separation, if on does temporal Signal Space Separation)
cal=/neuro/databases/sss/sss_cal.dat
ctc=/neuro/databases/ctc/ct_sparse.fif
movecomp_default=on # on/off

trans_option='on' # on/off NB! See below
#transformation_to=default ## default is "default", but you can supply your own file 
trans_conditions=( 'rest_eo' 'rest_ec' 'tap' 'pam' 'singlefinger' )
calc_avg_headpos='yes' #yes/no
empty_room_files=( 'empty_room1_before.fif' 'empty_room1_after.fif' 'empty_room2_before.fif' 'empty_room2_after.fif' ) #'empty_room_12_after.fif' 'empty_room_12_before.fif' ) ## put the names of your empty room files (consistent naming makes it a lot easier) (files in this array won't have "movecomp" applied) (no commas between files and leave spaces between first and last brackets)
headpos=off # on/off ## if "on", no movement compensation (movecomp is automatically turned off, even if specified "on")
force=off # on/off, "forces" the command to ignore warnings and errors and OVERWRITES if a file already exists with that name

downsampling=off # on/off, downsamples the data with the factor below
downsampling_factor=4 # must be an INTEGER greater than 1, if "downsampling = on". If "downsampling = off", this argument is ignored
sss_files=( 'only_apply_sss_to_this_file.fif' ) ## put the names of files you only want SSS on (can be used if want SSS on a subset of files, but tSSS on the rest)
apply_linefreq=off ## on/off
linefreq_Hz=50 ## set your own line freq filtering (ignored if above is off),



#############################################################################################################################################################################################################################################################
#############################################################################################################################################################################################################################################################
## DON'T CHANGE ANYTHING BELOW HERE (UNLESS YOU REALLY KNOW WHAT YOU ARE DOING!)
#############################################################################################################################################################################################################################################################
#############################################################################################################################################################################################################################################################

data_path=/neuro/data/sinuhe
trans_path=/trans_files
cd $data_path
cd $project/MEG

#############################################################################################################################################################################################################################################################
## Qbort if project folder doesn't exist
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

#if [ "$trans_option" = 'on' ]
#then
#	trans="-trans ${transformation_to}"
#	trans_string=_trans_${transformation_to}
#
#elif [ "$trans_option" = "off" ]
#then
#	trans=
#	trans_string=
#else echo 'faulty "trans_option" setting (must be on or off)'; exit 1;
#fi

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

	if [ ! -d log ]; then
		echo "not a dir"
		mkdir log 		## create log file directory if it doesn't already exist
	else echo "a dir"
	fi

	if [ ! -d quat ]; then
		echo 'quat folder does not exist. Will make one for $subject_and_date'
		mkdir quat_files 		## create file directory for quad files if it doesn't already exist
		mkdir headpos
	else echo "a dir"
	fi
	####################################################################################################################################################################################################################################################
	## loop over files in subject folders	####################################################################################################################################################################################################################################################
	
	for filename in `ls -p | grep -v / `;
	do
		echo -----------------------------------------------------------
		echo "Now running initiat mafilter process to get head movement"
		echo -----------------------------------------------------------

		for prefx in ${trans_conditions[*]}
		do
			fname=$( find ./quat -type f -print | grep $prefix)
			echo $filename
		############################################################################################################################################################################################################################################
		## Run initial maxfilter to estimate continous head position		############################################################################################################################################################################################################################################
		length=${#filename}-4  ## the indices that we want from $file (everything except ".fif")
		pos_file=${filename:0:$length}_headpos.pos 	# the name of the text output file with movement quaternions (not used for anything)
		quat_file=${filename:0:$length}_quat.fif 	# the name of the quat output file

		/neuro/bin/util/maxfilter -f ${filename} -o ./quat_files/$quat_file -headpos -hp ./headpos/$pos_file #This will make output files for all files including spilt files. This has to be taken into account.


		if [ "$calc_avg_headpos" = 'yes' ]; then
			for condition in ${trans_conditions[*]}
			do
#				echo $condition
				source /home/natmeg/data_scripts/avg_headpos/avgHeadMove.sh $condition  # Here we need to know if it need to get all filenames or if MNE can handle that!
			done
		fi

		############################################################################################################################################################################################################################################
		## check whether file is in the empty_room_files array and change movement compensation to off is so, otherwise use the movecomp_default setting 		############################################################################################################################################################################################################################################
		
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
		## check whether file is in the average head pos array and change trans argument
############################################################################################################################################################################################################################################
		if [ "$trans_option" = 'on' ]
		then
			for prefix in ${trans_conditions[*]}
			do
#				echo $prefix
				if [[ $filename == $prefix* ]]
				then
#					echo 'found $prefix'
#					echo $filename
					trans_fname=$( find ./quat -type f -print | grep $prefix)  # What will the actual filename be [!?!]
#					echo $trans_fname
					trans="-trans ${trans_fname}"
					trans_string=_trans
					break
				else
					trans=
					trans_string=					
				fi
			done
		elif [ "$trans_option" = "off" ]
		then
			trans=
			trans_string=
		else echo 'faulty "trans" setting (must be on or off)'; echo $trans_option #exit 1;
		fi

		echo 'Trans is:'
		echo $trans

		echo 'trans sting is:'
		echo $trans_string
		############################################################################################################################################################################################################################################
		## check whether file is in the sss_files array and change tsss to off is so, otherwise use the tsss_default setting 		############################################################################################################################################################################################################################################
		
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
		## output arguments 		############################################################################################################################################################################################################################################

		output_file=${filename:0:$length}${movecomp_string}${trans_string}${headpos_string}${linefreq_string}${ds_string}${tsss_string}.fif 
		echo $output_file

############################################################################################################################################################################################################################################
		## Initial maxfilter to get estimate of headposition ############################################################################################################################################################################################################		


		############################################################################################################################################################################################################################################
		## the actual maxfilter commands ############################################################################################################################################################################################################
		
		/neuro/bin/util/maxfilter -f ${filename} -o ${output_file} $force $tsss $ds -corr $correlation $movecomp $trans -autobad $autobad -cal $cal -ctc $ctc -v $headpos $linefreq | tee -a ./log/${filename:0:$length}${tsss_string}${movecomp_string}${trans_string}${headpos_string}${linefreq_string}${ds_string}.log
#		echo "Would run MaxF here!"
	done
	####################################################################################################################################################################################################################################################
	## file loop ends ##################################################################################################################################################################################################################################

done

############################################################################################################################################################################################################################################################
## subjects loop ends ######################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################

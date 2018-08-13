#!/bin/bash

## Script for automatic maxfilter processing where movement correction is done by shifting to
## the average headposition, calculated from continous head position estimation in MaxFilter,
## across the session.
##
## Procedure:
## 1) Run SSS movement estimation with MaxFilter (only if trans_option=continous)
## 2) Run Python (or matlab - NB not implemented yet!) scripts to get average transformation from output
## 3) Save transformation in -trans file
## 4) Run MaxFilter with correct settings (tSSS, movecomp, etc.) and transform to average headpos.
##
## (c) Mikkel C. Vinding and Lau M. Andersen (2016-2018)
##
## No warraty guarateed. This is a wrapper for calling Neuromag MaxFilter within the NatMEG (www.natmeg.se) infrastructure. Neuromag MaxFilter is 
## a comercial software. For reference read the MaxFilter Manual.
##
## For questions contact: mikkel.vinding@ki.se

#############################################################################################################################################################################################################################################################
## These are the ONLY parameters you should change (as according to your wishes). For more info we recommend reading the MaxFilter Manual.
## NB! Do not use spaces between "equal to" signs.
#############################################################################################################################################################################################################################################################

## STEP 1: On which conditions should average headposition be done (consistent naming is mandatory!)?
project=working_memory_WorkInProgress    			# The name of your project in /neuro/data/sinuhe
trans_conditions=( 'nback' ) 			# Name(s) of condition(s) on which head position correction should be applied
trans_option=continous 				# continous/initial, how to estimate average head position: From INITIAL head fit across files, or from CONTINOUS head position estimation within (and across) files, e.g. split files?
trans_type=median 				# mean/median, method to estimate "average" head position (only for trans_option=continous).

## STEP 2: Put the names of your empty room files (files in this array won't have "movecomp" applied) (no commas between files and leave spaces between first and last brackets)
empty_room_files=( 'empty_room_before.fif' 'empty_room_after.fif' )
sss_files=( 'only_apply_sss_to_this_file.fif' ) 	# put the names of files you only want SSS on (can be used if want SSS on a subset of files, but tSSS on the rest)

## STEP 3: Select MaxFilter options.
autobad=on 					# Options: on/off
tsss_default=on 				# on/off (if off does Signal Space Separation, if on does temporal Signal Space Separation)
correlation=0.98 				# tSSS correlation rejection limit (default is 0.98)
movecomp_default=on 				# on/off, do movement compensation?

#############################################################################################################################################################################################################################################################
## Default initial settings for headposition estimation (only change if you are certain that this is what you want to do)
#############################################################################################################################################################################################################################################################

force=off 						# on/off, "forces" the command to ignore warnings and errors and OVERWRITES if a file already exists with that name
downsampling=off 					# on/off, downsamples the data with the factor below
downsampling_factor=4 					# must be an INTEGER greater than 1, if "downsampling = on". If "downsampling = off", this argument is ignored
apply_linefreq=off 					# on/off
linefreq_Hz=50 						# set your own line freq filtering (ignored if above is off),
cal=/neuro/databases/sss/sss_cal.dat
ctc=/neuro/databases/ctc/ct_sparse.fif

#############################################################################################################################################################################################################################################################
## Default ifolder and path settings (only change if you are certain that this is what you want to do)
#############################################################################################################################################################################################################################################################

data_path=/neuro/data/sinuhe   	#Sinhue folder where project folder containing data is located 
#data_path=/archive/
quat_folder=quat_files 		# name of folder where quat files will be put (within each subject/date folder)
headpos_folder=headpos		# name of folder where headpos files will be put (within each subject/date folder)
trans_folder=trans_files        # name of folder where average transformation files will be put (within each subject/date folder)

#############################################################################################################################################################################################################################################################
#############################################################################################################################################################################################################################################################
## DON'T CHANGE ANYTHING BELOW HERE (UNLESS YOU REALLY KNOW WHAT YOU ARE DOING!)
#############################################################################################################################################################################################################################################################
#############################################################################################################################################################################################################################################################

export script_path="/home/natmeg/data_scripts/avg_headpos"			#Change depending on which computer is used!
echo $script_path 																		#[!!!]
cd $data_path
cd $project/MEG

#############################################################################################################################################################################################################################################################
## Abort if project folder doesn't exist and check if tran and pos folders exist
#############################################################################################################################################################################################################################################################

if [ $? -ne 0 ]  
then
	echo "specified project folder doesn't exist (change project variable)"
	exit 1
fi

#############################################################################################################################################################################################################################################################
#############################################################################################################################################################################################################################################################
## Setup the varios MaxFilter option for the real run
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
	echo $subject_and_date

	# create log file directory if it doesn't already exist
	if [[ ! -d log ]]; then
		echo "Creating folder for MaxFilter logfiles"
		mkdir log 		#
	fi

####################################################################################################################################################################################################################################################
	## Get the average head position	####################################################################################################################################################################################################################################################

	trans_option="$trans_option"    #Make fail safe
#	export $trans_option
#	echo $trans_option
	
	#Look for correct files
	run_trans= 						# Intitate variable
	for condition in ${trans_conditions[*]}; do
		confiles=$(find ./*$condition* 2> /dev/null)
		if [[ ! -z $confiles ]]; then
			run_trans="yes"
			echo "Found files to transform for condition '$condition':"
			echo $confiles
			break
		fi
	done	
	
	if [[ $run_trans == "yes" ]]; then

		## create file directory for quad files if it doesn't already exist
		if [[ ! -d $quat_folder ]]; then
			echo "quat folder '$quat_folder' does not exist. Will make one for $subject_and_date"
			mkdir $quat_folder 		
			mkdir $headpos_folder
		fi
	
	
		if [[ "$trans_option" == "initial" ]]; then
			for condition in ${trans_conditions[*]}
			do
				echo "Will use the average of INITIAL head position fit"
				ipython $script_path/avg_headpos.py $trans_option $condition
			done
		
		elif [[ "$trans_option" == "continous" ]]; then
			for condition in ${trans_conditions[*]}
			do

				condition_files=$( find ./*$condition* -type f )    # -print | grep $condition*) )
#				echo $condition_files
				echo "Will use the $trans_option of the CONTINOUS head position"
				for fname in ${condition_files[@]}
				do
					echo $fname
					echo -----------------------------------------------------------------------------------
					echo "Now running initiat MaxFilter on $fname to get continous head position"
					echo -----------------------------------------------------------------------------------
					length=${#fname}-4  ## the indices that we want from $file (everything except ".fif")
					pos_fname=${fname:0:$length}_headpos.pos 	# the name of the text output file with movement quaternions (not used for anything)
					quat_fname=${fname:0:$length}_quat.fif 	# the name of the quat output file
				
					if [[ ! -f ./$quat_folder/$quat_fname ]]; then

						# Run maxfilter
						/neuro/bin/util/maxfilter -f ${fname} -o ./$quat_folder/$quat_fname $ds -headpos -hp ./$headpos_folder/$pos_fname -autobad $autobad
#						echo "Would run initial MaxF here"
					else
						echo "File $quat_fname already exists. If you want to run head position estimation again you must delete the old files!"
						continue
					fi
				done
			
				### MAKE AVERAGE HEADPOS
				ipython $script_path/avg_headpos.py $trans_option $condition $(pwd) $trans_type 
#				echo "would run Py script here..."
			done
		
		else
			echo "Option 'trans_option' must be 'continous' or 'initial'. You wrote: $trans_option"
			exit 1
		fi
	else
		echo "Did not find any matches to transform for $subject_and_date"
	fi

############################################################################################################################################################################################################
	## loop over files in subject folders
##############################################################################################################################################################################################################
#	for filename in `ls -p | grep -v / `;
#	list=$(find ./*.fif 2> /dev/null)
#	echo $list
	
	for filename in $(find ./*'.fif' 2> /dev/null)
	do
	
		if [[ ! "$filename" == *".fif" ]]; then
			echo "$filename not a fif file"
			continue
		fi

############################################################################################################################################################################################################################################
		## check whether file is in the empty_room_files array and change movement compensation to off is so, otherwise use the movecomp_default setting 	############################################################################################################################################################################################################################################
		
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
		
		do_transform="no" 								# Initiate variable
		for prefix in ${trans_conditions[*]}
		do
			if [[ $filename == *"$prefix"* ]]; then
				do_transform='yes'
				break
			fi
		done
		
		echo "Do transform: $do_transform"
			
		if [ "$do_transform" == 'yes' ]
		then
			echo $(pwd)
			echo $trans_folder
			trans_fname=$( find ./$trans_folder -type f -print | grep $prefix)  # Find the appropiate trans file

			if [[ -z $trans_fname ]]; then
				echo "No -trans files in folder $(pwd)/$trans_fname with name $prefix"
				exit 1
			fi

			trans="-trans ${trans_fname}"
			trans_string=_avgtrans
			echo "Trans is: $trans_fname"
			echo $trans
		else
			trans=
			trans_string=					
		fi

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
			then	
				if [ $sss_file = $filename ]
				then
					set_tsss 'off'
				fi
			fi
		done

############################################################################################################################################################################################################################################
		## output arguments 		############################################################################################################################################################################################################################################
		length=${#filename}-4  ## the indices that we want from $file (everything except ".fif")

		output_file=${filename:0:$length}${movecomp_string}${trans_string}${linefreq_string}${ds_string}${tsss_string}.fif   ## !This does not conform to MNE naming conventions
		echo "Output is: $output_file"

############################################################################################################################################################################################################################################
		## the actual maxfilter commands 
############################################################################################################################################################################################################
		
		/neuro/bin/util/maxfilter -f ${filename} -o ${output_file} $force $tsss $ds -corr $correlation $movecomp $trans -autobad $autobad -cal $cal -ctc $ctc -v $headpos $linefreq | tee -a ./log/${filename:0:$length}${tsss_string}${movecomp_string}${trans_string}${linefreq_string}${ds_string}.log
#		echo "Would run MaxF here!"
	done

####################################################################################################################################################################################################################################################
## file loop ends 
##################################################################################################################################################################################################################################

done

############################################################################################################################################################################################################################################################
## subjects loop ends 
######################################################################################################################################################################################################################################

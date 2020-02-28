#!/usr/bin/env bash

###############################################################################
# BlackAlert.sh                                                               #
# Version 0.27                                                                #
#                                                                             #
# Copyright 2020 - Joe Hurley                                                 #
#                                                                             #
###############################################################################
#                                                                             #
# Workflow to pre- and post-process Bluray media for Plex using filebot, jq,  #
# ffprobe and mkvpropedit to dynamically build commands for Don Melton's      #
# other-transcode script and then move generated content to the NAS.          #
#                                                                             #
###############################################################################


clear
SECONDS=0
DELAY=3


echo "############################################################################################"
echo "#                                                                                          #"
echo "# BLACKALERT.SH (v0.27)                                                                    #"
echo "#                                                                                          #"
echo "############################################################################################"


usage() {

	strName=$(basename $0)
	echo "#                                                                                          #"
	echo "# USAGE:       $strName -r [pre|post|batch] -e [live|test] [-d directory for batch]   #"
	echo "#                                                                                          #"
	echo "#   -r pre     Run the PRE-transcoding workflow for on raw rips                            #"
	echo "#              so that they have standardised stream titles, forced subs,                  #"
	echo "#              correct default audio in addition to saved JSON, mkvpropedits               #"
	echo "#              and TSVs.                                                                   #"
	echo "#              MKVs are also renamed correctly using FileBot to conform with               #"
	echo "#              Plex's naming for movies and TV shows.                                      #"
	echo "#              Most importantly, the individual other-transcode command per                #"
	echo "#              MKV is generated and then concatenated into one commands.bat                #"
	echo "#              file to be run on Windows.                                                  #"
	echo "#                                                                                          #"
	echo "#   -r post    Run the POST-transcoding workflow on raw, JSON, mkvpropedit,                #"
	echo "#              CVS and transcoded content. This content is moved to its final              #"
	echo "#              locations within the Media (raw) and Plex NAS folders.                      #"
	echo "#                                                                                          #"
	echo "#   -r batch   Takes the mkv raw content provided by -d and processes it automatically     #"
	echo "#                                                                                          #"
	echo "#   -e live    Location/path selections for the real content stored on the NAS             #"
	echo "#              and correctly archived in addition to being made available                  #"
	echo "#              for Plex                                                                    #"
	echo "#   -e test    Location/path selections for the content stored locally as part             #"
	echo "#              of testing on both Mac and Windows                                          #"
	echo "#   -d <path>  Path to the parent directory of MKVs for batch processing                   #"
    echo "#                                                                                          #"
	echo "############################################################################################"
	echo ""
	exit
}






##########################################################################
# STEP PRE01 - Set-up checks                                             #
##########################################################################

pre_setup_checks() {

	# Part of the run-time options includes the '-e' argument which sets the environment
	# to either 'live' or 'test' as part of the strEnv variable from the getopt startup
	
	case $strEnv in
		live) 	pre_setup_checks_live
				shift
				;;
		test)	pre_setup_checks_test
				shift
				;;
		*)		usage
				exit
				;;
	esac					
	
	dirWinWorkDir="E:\Engine_Room"

	echo ""
	echo ""
	echo "-----------------------------------------------------------------"
	echo "Working Directory:  	$dirMacWorkDir"
	echo "Windows Directory:  	$dirWinWorkDir"
	echo "-----------------------------------------------------------------"
	echo ""
	echo ""
	

	# -----------------------------------------------------------------
	#  Variables
	# -----------------------------------------------------------------

	IFS=$'\n'
	strRawPathAndFile=$1
	strRawFilename=`echo $strRawPathAndFile | rev | cut -d'/' -f 1 | rev`
	strRawName=`echo $strRawFilename | sed 's/\.mkv//g'`

	dirInbox="$dirMacWorkDir/01_Inbox"
	dirProcessing="$dirMacWorkDir/02_Processing"
	dirOutbox="$dirMacWorkDir/03_Outbox"
	dirOutboxCommands="$dirOutbox/Commands"
	dirOutboxSummaries="$dirOutbox/Summaries"
	dirOutboxLogs="$dirOutbox/Logs"
	dirReadyForTranscoding="$dirMacWorkDir/04_ReadyForTranscoding"
	dirTranscoded="$dirMacWorkDir/05_Transcoded"
	dirArchive="$dirMacWorkDir/06_Archive"

	dirPlexMovieFolder="/Volumes/Plex/Movies"
	strPlexMovieName="${strPlexFolder}/${strMovieName}/${strMovieName}.mkv"
	strTVRegEx="([sS]([0-9]{2,}|[X]{2,})[eE]([0-9]{2,}|[Y]{2,}))"

}


pre_setup_checks_live() {

while true; do
	cat << _EOF_



*******************************************************************************
*                                                                             *
*                         LIVE PRODUCTION ENVIRONMENT                         *
*                                                                             *
*******************************************************************************



-------------------------------------------------------------------------------
Current Working Directory
-------------------------------------------------------------------------------

Please select one of the following:
===============================================================================

  1. /Volumes/E/Engine_Room
  2. /Volumes/Media/Engine_Room
  3. /mnt/e/Engine_Room
  0. Quit
	
===============================================================================

_EOF_

	  read -p "Enter selection [0-3] > "

  		if [[ $REPLY =~ ^[0-3]$ ]]; then
    	case $REPLY in
     	1)
           	dirMacWorkDir="/Volumes/E/Engine_Room"
          	break
          	;;
      	2)
      	  	dirMacWorkDir="/Volumes/Media/Engine_Room"
          	break
          	;;
      	3)
      	  	dirMacWorkDir="/mnt/e/Engine_Room"
          	break
          	;;
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry."
    	sleep $DELAY
  	fi
	done

}




pre_setup_checks_test() {

while true; do
	cat << _EOF_



*******************************************************************************
*                                                                             *
*                              TEST ENVIRONMENT                               *
*                                                                             *
*******************************************************************************



-------------------------------------------------------------------------------
Current Working Directory
-------------------------------------------------------------------------------

Please select one of the following:
===============================================================================

  1. /Volumes/4TB/Engine_Room-TEST
  2. /mnt/e/Engine_Room-TEST
  3. /home/parallels/Desktop/Engine_Room-TEST
  0. Quit
	
===============================================================================

_EOF_

	  read -p "Enter selection [0-3] > "

  		if [[ $REPLY =~ ^[0-3]$ ]]; then
    	case $REPLY in
     	1)
           	dirMacWorkDir="/Volumes/4TB/Engine_Room-TEST"
          	break
          	;;
      	2)
      	  	dirMacWorkDir="/mnt/e/Engine_Room-TEST"
          	break
          	;;
      	3)
      	  	dirMacWorkDir="/home/parallels/Desktop/Engine_Room-TEST"
          	break
          	;;
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry."
    	sleep $DELAY
  	fi
	done

}




pre_runbook() {

	# -----------------------------------------------------------------
	#  Runbook
	# -----------------------------------------------------------------

	strStartDateTime=$(date "+%Y%m%d-%H%M%S")
	echo "Start time:   $strStartDateTime"
	echo ""

	# Step 1:  	Set-up checks
	setup_checks

	# Step 2:  	Take the raw data and correctly name the files with names from theMovieDB 
	#       	and from TheTVDB to comply with Plex naming standards
	raw_media_plex_naming

	# Step 3:  	Standardise the titling 
	raw_media_title_and_default_consistency_checks

	# Step 4:  	Summarise and modify the current video, audio and subtitle streams with mkvpropedit
	raw_media_stream_naming

	# Step 5:  	Dynamic building of other-transcode command
	other-transcode_commands
	other-transcode_commands_concatenate
	
	strEndDateTime=$(date "+%Y%m%d-%H%M%S")
	echo ""
	echo "End time:   $strEndDateTime"
	echo ""

	strMinutes=$(( $SECONDS / 60 ))
	strSeconds=$(( $SECONDS - ( $strMinutes*60 ) ))
	echo "Total time:   ${strMinutes} minutes, ${strSeconds} seconds."
	echo ""
}



batch_runbook() {

	# -----------------------------------------------------------------
	#  Runbook
	# -----------------------------------------------------------------

	strStartDateTime=$(date "+%Y%m%d-%H%M%S")
	echo "Start time:   $strStartDateTime"
	echo ""

	# Step 1:  	Source and Destination
	setup_checks
	
	# Replace the standard $dirProcessing and $dirReadyForTranscoding variable with the batch folder ($strDirModePath)
	dirProcessing="$strDirModePath"
	dirReadyForTranscoding="$strDirModePath"
	
	# Step 5:  	Dynamic building of other-transcode command
	other-transcode_commands
	other-transcode_commands_concatenate
	
	strEndDateTime=$(date "+%Y%m%d-%H%M%S")
	echo ""
	echo "End time:   $strEndDateTime"
	echo ""

	strMinutes=$(( $SECONDS / 60 ))
	strSeconds=$(( $SECONDS - ( $strMinutes*60 ) ))
	echo "Total time:   ${strMinutes} minutes, ${strSeconds} seconds."
	echo ""
}






##########################################################################
# STEP 1 - Set-up checks                                                 #
##########################################################################

setup_checks() {
		
	echo "*******************************************************************************"
	echo "Starting Step 1 - setup_checks" 
	echo " "
		
	# Verify that environment is correct, and all directories
	if [ ! -d "$dirMacWorkDir" ]; then
		echo "$dirMacWorkDir is not present. Aborting."
  		strExit="True"
	fi

	for tool in ffprobe jq filebot mkvpropedit
	do
    	command -v $tool >/dev/null 2>&1 || { echo "Executable not in \$PATH: $tool" >&2; strExit="True"; }
	done

	if [ "$strExit" = "True" ]; then
		exit 1
	fi
		
	#Create an array of all the working folders and test for their availability
	arrDirArray=($dirInbox $dirProcessing $dirReadyForTranscoding $dirOutbox $dirOutboxCommands $dirOutboxSummaries $dirOutboxLogs $dirTranscoded $dirArchive)
		
	for folder in "${arrDirArray[@]}"
	do
		if [ ! -d $folder ]; then
			echo " - Making $folder"
			mkdir $folder
		fi			
	done
	
	echo " "
	echo "Step 1 complete" 
	echo "*******************************************************************************"
	echo " "
	echo " "	
}


##########################################################################
# STEP 2 - Take the raw data and correctly name the files with names     #
#          from theMovieDB and from TheTVDB to comply with Plex          #
#          naming standards                                              #
##########################################################################

raw_media_plex_naming() {

	echo "*******************************************************************************"
	echo "Starting Step 2 - raw_media_plex_naming" 
	echo " "

	local OldIFS="$IFS"
	local IFS=$'\n'
	local str02File=""

	cd $dirInbox
	
	for str02FileName in `find . -type f -name "*.mkv" | sort` 
	do
		str02FileName=${str02FileName:2}
		echo "-------------------------------------------------------------------------------"
		echo "File being processed:   $str02FileName"
		
		# Need to change the path for filebot to add compatibility between the Mac and WSL/Unix distros		
		strFilebotLocation=$(dirname `which filebot`)

  		if [[ "$str02FileName" =~ $strTVRegEx ]]; then
			echo "$str02FileName =~ $strTVRegEx"
			${strFilebotLocation}/filebot -rename "$str02FileName" --db TheTVDB --format "$dirProcessing/{n} - {s00e00} - {t}" -non-strict
		else
			${strFilebotLocation}/filebot -rename "$str02FileName" --db TheMovieDB --format "$dirProcessing/{n.colon(' - ')} ({y})" -non-strict
		fi
		
	    read line </dev/null
	done
	
	echo "-------------------------------------------------------------------------------"
	echo " "
	echo "Step 2 complete" 
	echo "*******************************************************************************"
	echo " "
	echo " "
	
}



##########################################################################
# STEP 3 - Ensure file and metadata title consistency                    #
##########################################################################

raw_media_title_and_default_consistency_checks() {

	echo "*******************************************************************************"
	echo "Starting Step 3 - raw_media_title_and_default_consistency_checks" 
	echo " "
		
	local OldIFS="$IFS"
	local IFS=$'\n'

	# Need to identify the files for mkvpropedit processing next
	cd $dirProcessing
	
	for str03FileName in `find . -type f -name "*.mkv" | sort` 
	do	
		# Get the ffprobe data from the raw file and extract its internal title name
		strFFprobeDetail=$(ffprobe -i "$str03FileName" -v error -show_format -show_streams -show_data -print_format json=compact=1 2>/dev/null)
		str03FileName=$(basename "$str03FileName")
		str03FileNameNoExt="${str03FileName%.*}"

		strFFprobeCurrentTitle=$(echo "$strFFprobeDetail" | jq -r '.format|.tags|.title')
		if [ "$strFFprobeCurrentTitle" != "$str03FileNameNoExt" ]
		then
			if [ -z "$strFFprobeCurrentTitle" ]
			then
				strFFprobeCurrentTitle="<blank>"
			fi
			echo " - Retitling \"${strFFprobeCurrentTitle}\" to \"${str03FileNameNoExt}\" " 
			mkvpropedit "$str03FileName" --edit info --set "title=$str03FileNameNoExt" >/dev/null 2>&1
		fi 

		# For each subtitle, the .disposition.default needs to be set to '0' even for Forced subtitles (usually set to 1) because
		# forced subtitle streams will be automatically burn-ed in.
		# Check to see if a subtitle stream has been set up with .disposition.default ACTIVE (=1) and if more than one is set (incorrectly), then they are all reset to zero

		strFFprobeSubtitleDispositionDefaultCheck=$(echo "$strFFprobeDetail" | jq -r '.streams[] | select(.codec_type=="subtitle" and .disposition.default==1) | .index')
		strFFprobeSubtitleDispositionDefaultCount=$(echo "$strFFprobeDetail" | jq -r '.streams[] | select(.codec_type=="subtitle" and .disposition.default==1) | .index' | wc -l)
		
		if [ "$strFFprobeSubtitleDispositionDefaultCount" -ge 1 ]
		then
			for strFFprobeSubtitleDispositionDefaultCounter in $strFFprobeSubtitleDispositionDefaultCheck
			do
				((strFFprobeSubtitleDispositionDefaultCounter++))
				mkvpropedit "$str03FileName" --edit track:${strFFprobeSubtitleDispositionDefaultCounter} --set flag-default=0 >/dev/null 2>&1
				echo " - ${str03FileName}:  Subtitle index ${strFFprobeSubtitleDispositionDefaultCounter}: default flag set to \"0\" "
			done
		fi
		
		strFFprobeAudioDispositionDefaultCheck=$(echo "$strFFprobeDetail" | jq -r '.streams[] | select(.codec_type=="audio" and .disposition.default==1) | .index')
		strFFprobeAudioDispositionDefaultCount=$(echo "$strFFprobeDetail" | jq -r '.streams[] | select(.codec_type=="audio" and .disposition.default==1) | .index' | wc -l)
		
		# For each audio stream, there should only be one default stream (usually the FLAC track). 
		# In the event of 2 or more, the .disposition.default will be set to '0' for all audio streams which can be subsequently corrected in the automated section.
		if [ "$strFFprobeAudioDispositionDefaultCount" -ge 2 ]
		then
			echo " - *** WARNING ***   2 or more audio streams have been set to default - they will now be reset to \"0\" "
			for strFFprobeAudioDispositionDefaultCounter in $strFFprobeAudioDispositionDefaultCheck
			do
				((strFFprobeAudioDispositionDefaultCounter++))
				mkvpropedit "$str03FileName" --edit track:${strFFprobeAudioDispositionDefaultCounter} --set flag-default=0 >/dev/null 2>&1
				echo " - ${str03FileName}:  Audio index ${strFFprobeAudioDispositionDefaultCounter}: default flag set to \"0\" "
			done
		fi
		
	 
	    read line </dev/null
	
	done
	
		echo " "
		echo "Step 3 complete" 
	echo "*******************************************************************************"
	echo " "
	echo " "

}



##########################################################################
# STEP 4 - Summarise and modify the current video, audio and subtitle    #
#          streams to set names, default audio and forced-flags on       #
#          subtitle streams which can be burned-in.                      #
#          Also save out a complete and final mkvpropedit command        #
##########################################################################
	
raw_media_stream_naming() {

	echo "*******************************************************************************"
	echo "Starting Step 4 - raw_media_stream_naming" 
	echo " "
		
	# Need to identify the files for mkvpropedit processing next
	cd $dirProcessing


	for str04FileName in `find . -type f -name "*.mkv" | sort` 
	do
		str04File=${str04FileName:2}
		FILE=${dirProcessing}/${str04File}
		
		str04RawFilename=`echo $FILE | rev | cut -d'/' -f 1 | rev`
	    str04RawName=`echo $str04RawFilename | sed 's/\.mkv//g'`
		

		IFS=$'\n'
		# Function calls here	
  		step4_track_editing	
  		
	    read line </dev/null
	done

		
	echo " "
	echo "Step 4 complete" 
	echo "*******************************************************************************"
	echo " "
	echo " "
}



step4_track_editing() {
	
	while true; do
	step4_ffprobe_summary
	
	cat << _EOF_

=================================================================
Please select one of the following:
=================================================================

	1. Rename or add a title to a VIDEO stream
	2. Rename or add a title to a AUDIO stream
	3. Rename or add a title to a SUBTITLE stream
	4. Set audio default track
	5. Set the forced-subtitle flag
	6. Copy original video (no video transcoding)
	7. AUDIO Options
		- Copy the main audio track (no audio transcoding)
		- Copy all audio tracks (no audio transcoding)
		- EAC-3 surround & AAC stereo/mono
		- Enable DTS pass-through
		- Keep AC-3 stereo 		
	8. MORE Options
		- Create single/unified mkvpropedit script
		- Use --x264-avbr software encoding
		- Disable forced subtitle burn-in
		- Surround bitrate override
		- Stereo bitrate override
		- Mono bitrate override	
	9. Next
	0. Quit

=================================================================

_EOF_

	  read -p "Enter selection [0-9] > "

  		if [[ $REPLY =~ ^[0-9]$ ]]; then
    	case $REPLY in
     	1)
           	step4_ffprobe_tsv
      	  	step4_rename_track video
          	continue
          	;;
      	2)
      	  	step4_ffprobe_tsv
      	  	step4_rename_track audio
          	continue
          	;;
      	3)
      	  	step4_ffprobe_tsv
      	  	step4_rename_track subtitle
          	continue
          	;;
        4)
      	  	step4_ffprobe_tsv
      	  	step4_set_default_audio_track
          	continue
          	;;
        5)
      	  	step4_ffprobe_tsv
      	  	step4_set_forced_subtitle_track
      	  	continue
          	;;	
        6)
        	step4_ffprobe_tsv
        	step4_copy_original_video
        	continue
          	;;
        7)
        	step4_ffprobe_tsv
        	step4_track_editing_AudioOptions
        	continue
        	;;  		  	
        8)
        	step4_ffprobe_tsv
        	step4_track_editing_MoreOptions
        	continue
        	;;
        9)  step4_ffprobe_tsv
        	step4_mkvpropedit_unfied_command
        	step4_tsv_cleanup
        	step4_ffprobe_json_output raw

        	break
        	;;	
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry."
    	sleep $DELAY
  	fi
	done

}



step4_track_editing_AudioOptions() {
	
	while true; do
	step4_ffprobe_summary
	
	cat << _EOF_

=================================================================
AUDIO OPTIONS
=================================================================

Please select one of the following:

	1. Copy the main audio track (no transcoding)
	2. Copy all audio tracks (no transcoding)
	3. EAC-3 surround & AAC stereo/mono
	4. Enable DTS pass-through
	5. Keep AC-3 stereo 
	6. Back
	0. Quit

=================================================================

_EOF_

	  read -p "Enter selection [0-6] > "

  		if [[ $REPLY =~ ^[0-6]$ ]]; then
    	case $REPLY in
     	1)
           	step4_ffprobe_tsv
      	  	step4_copy_main_audio
          	continue
          	;;
      	2)
      	  	step4_ffprobe_tsv
      	  	step4_copy_all_audio_tracks
          	continue
          	;;
      	3)
      	  	step4_ffprobe_tsv
      	  	step4_EAC3plusAAC
          	continue
          	;;
        4)
      		step4_ffprobe_tsv
      	  	step4_EnableDTSPassthrough
      	  	continue
          	;;  
        5)
      		step4_ffprobe_tsv
      	  	step4_KeepAC3Stereo
          	continue
          	;;          
        6)
        	break
        	;;	
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry"
    	sleep $DELAY
  	fi
	done

}



step4_track_editing_MoreOptions() {
	
	while true; do
	step4_ffprobe_summary
	
	cat << _EOF_

=================================================================
AUDIO OPTIONS
=================================================================

Please select one of the following:

	1. Create single/unified mkvpropedit script
	2. Use --x264-avbr software encoding
	3. Disable forced subtitle burn-in	
	4. Surround bitrate override
	5. Stereo bitrate override
	6. Mono bitrate override
	7. Back
	0. Quit

=================================================================

_EOF_

	  read -p "Enter selection [0-7] > "

  		if [[ $REPLY =~ ^[0-7]$ ]]; then
    	case $REPLY in
     	1)
           	step4_ffprobe_tsv
      	  	step4_mkvpropedit_unfied_command
          	continue
          	;;
      	2)
      	  	step4_ffprobe_tsv
      	  	step4_usex264-avbr
          	continue
          	;;
      	3)
      	  	step4_ffprobe_tsv
      	  	step4_DisableForcedSubtitleAutoBurnIn
          	continue
          	;;
      	4)
      	  	step4_ffprobe_tsv
      	  	step4_SurroundBitrateOverride
          	continue
          	;;
      	5)
      	  	step4_ffprobe_tsv
      	  	step4_StereoBitrateOverride
          	continue
          	;;
      	6)
      	  	step4_ffprobe_tsv
      	  	step4_MonoBitrateOverride
          	continue
          	;;          	          	          	
        7)
        	break
        	;;	
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry"
    	sleep $DELAY
  	fi
	done

}






step4_ffprobe_summary() {

	# This is the main summary sheet which is displayed at the beginning and then revised after each edit.
	echo ""
	echo "######################################################################################################################################################"
	echo ""
	echo "$FILE"
	echo ""
	echo "######################################################################################################################################################"
	echo ""
	step4_ffprobe_command $FILE | step4_jq_selectall_command
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"

}



step4_ffprobe_command() {

	#ffprobe -v error -show_entries stream=index,format,codec_name,channel_layout,channels,codec_type:stream_tags=language,title,BPS-eng,NUMBER_OF_FRAMES-eng:stream_disposition=forced,default -print_format json=compact=1 $1
	ffprobe -v error -show_entries stream=index,format,codec_name,profile,channel_layout,channels,codec_type,field_order:stream_tags=language,title,BPS-eng,NUMBER_OF_FRAMES-eng:stream_disposition=forced,default -print_format json=compact=1 $1

}


step4_jq_selectall_command() {

#	jq -r '["TYPE","INDEX","LANGUAGE","CODEC","CHANNEL LAYOUT","BITRATE","NO OF ELEMENTS","DEFAULT","FORCED FLAG","TITLE"], (.streams[] | select(.codec_type=="video" or .codec_type=="audio" or .codec_type=="subtitle") | [.codec_type, .index, .tags.language, .codec_name, .channel_layout, .tags."BPS-eng", .tags."NUMBER_OF_FRAMES-eng",.disposition.default, .disposition.forced, .tags.title ]) | @csv ' | sed 's/\"//g' | sed 's/,/ ,/g' | column -t -s ','
	jq -r '["TYPE","INDEX","LANGUAGE","CODEC","PROFILE","CHANNEL LAYOUT","BITRATE","NO OF ELEMENTS","DEFAULT","FORCED FLAG","TITLE"], (.streams[] | select(.codec_type=="video" or .codec_type=="audio" or .codec_type=="subtitle") | [.codec_type, .index, .tags.language, .codec_name, .profile, .channel_layout, .tags."BPS-eng", .tags."NUMBER_OF_FRAMES-eng",.disposition.default, .disposition.forced, .tags.title ]) | @tsv ' | sed 's/\"//g' | sed -E 's/'$(printf '\t')'/'$(printf ' \t')'/g' | column -t -s $'\t'
}

step4_jq_selectstream_command() {

	# expects an argument of "video", "audio" or "subtitle"
#	jq -r --arg STREAM "$1" '["TYPE","INDEX","LANGUAGE","CODEC","CHANNEL LAYOUT","BITRATE","NO OF ELEMENTS","DEFAULT","FORCED FLAG","TITLE"], (.streams[] | select(.codec_type==$STREAM) | [.codec_type, .index, .tags.language, .codec_name, .channel_layout, .tags."BPS-eng", .tags."NUMBER_OF_FRAMES-eng",.disposition.default, .disposition.forced, .tags.title ]) | @csv ' | sed 's/\"//g' | sed 's/,/ ,/g' | column -t -s ','
	jq -r --arg STREAM "$1" '["TYPE","INDEX","LANGUAGE","CODEC","PROFILE","CHANNEL LAYOUT","BITRATE","NO OF ELEMENTS","DEFAULT","FORCED FLAG","TITLE"], (.streams[] | select(.codec_type==$STREAM) | [.codec_type, .index, .tags.language, .codec_name, .profile, .channel_layout, .tags."BPS-eng", .tags."NUMBER_OF_FRAMES-eng",.disposition.default, .disposition.forced, .tags.title ]) | @tsv ' | sed 's/\"//g' | sed -E 's/'$(printf '\t')'/'$(printf ' \t')'/g' | column -t -s $'\t'
}




step4_ffprobe_tsv() {

	# Define the variables for this function
	strFfprobeTsvFile=""
	strVideoStreamCount=""
	strAudioStreamCount=""
	strSubtitleStreamCount=""
	strStartingVideoStreamIndexNo=""
	strEndingVideoStreamIndexNo=""
	strStartingAudioStreamIndexNo=""
	strEndingAudioStreamIndexNo=""
	strStartingSubtitleStreamIndexNo=""
	strEndingSubtitleStreamIndexNo=""
	
	# This function creates a temp tsv with ffprobe output. Variables are then defined for the mkv in question 
	# FILE includes the full path
	FILEwithoutExt=$( echo $FILE | sed 's/\.mkv$//g')
	strFfprobeTsvFile="${FILEwithoutExt}.tsv"
	if [ ! -f $strFfprobeTsvFile ]
	then
		touch $strFfprobeTsvFile
	fi	

#	step4_ffprobe_command $FILE | jq -r '.streams[] | select(.codec_type=="video" or .codec_type=="audio" or .codec_type=="subtitle") | [.codec_type, .index, .tags.language, .codec_name, .channel_layout, .tags."BPS-eng", .tags."NUMBER_OF_FRAMES-eng",.disposition.default, .disposition.forced, .tags.title ] | @csv ' | sed 's/\"//g' > $strFfprobeTsvFile
	step4_ffprobe_command $FILE | jq -r '.streams[] | select(.codec_type=="video" or .codec_type=="audio" or .codec_type=="subtitle") | [.codec_type, .index, .tags.language, .codec_name, .profile, .channel_layout, .tags."BPS-eng", .tags."NUMBER_OF_FRAMES-eng",.disposition.default, .disposition.forced, .tags.title ] | @tsv ' | sed 's/\"//g' > $strFfprobeTsvFile

	# =================================================================================
	# These variables work out the totals
	# =================================================================================
	strVideoStreamCount=$( cat $strFfprobeTsvFile | grep ^video | wc -l )
	strAudioStreamCount=$( cat $strFfprobeTsvFile | grep ^audio | wc -l )
	strSubtitleStreamCount=$( cat $strFfprobeTsvFile | grep ^subtitle | wc -l )

	# =================================================================================
	# These variables are used in identifying track ranges in interactive prompts
	# =================================================================================
	strStartingVideoStreamIndexNo=$( grep ^video $strFfprobeTsvFile | cut -f2 | head -n 1 )
	strEndingVideoStreamIndexNo=$( grep ^video $strFfprobeTsvFile | cut -f2 | tail -n 1 )
	strStartingAudioStreamIndexNo=$( grep ^audio $strFfprobeTsvFile | cut -f2 | head -n 1 )
	strEndingAudioStreamIndexNo=$( grep ^audio $strFfprobeTsvFile | cut -f2 | tail -n 1 )
	strStartingSubtitleStreamIndexNo=$( grep ^subtitle $strFfprobeTsvFile | cut -f2 | head -n 1 )
	strEndingSubtitleStreamIndexNo=$( grep ^subtitle $strFfprobeTsvFile | cut -f2 | tail -n 1 )

}




step4_rename_track() {

	# Three values are passed into this function automatically:  "audio", "video" and
	# "subtitle" because 'jq --arg' or '--env' do not seem to work on Mac to accept script 
	# variables within the jq select structure.

	# Define the variables for this function
	strRenameTrackArg1=""
	strStreamNumber=""
	strCurrentStreamTitle=""
	strAudioStreamNewTitle=""
	REPLY=""
	
	strRenameTrackArg1=$1

	# Get presented with the audio-only options
	echo ""
	echo "######################################################################################################################################################"
	echo ""
	echo "$FILE"
	echo ""
	echo "######################################################################################################################################################"
	echo ""

	while true; do
		case $strRenameTrackArg1 in
			video) 
				step4_ffprobe_command $FILE | step4_jq_selectstream_command video
				break
				;;
			audio)
				step4_ffprobe_command $FILE  | step4_jq_selectstream_command audio
				break
				;;
			subtitle)
				step4_ffprobe_command $FILE | step4_jq_selectstream_command subtitle
				break
				;;
			*)
    	    	break
        		;;
		esac
	done

	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo ""

	case $strRenameTrackArg1 in
     	video)
    		while true
    		do
    	       	read -p "Please choose a video stream to rename:  index [${strStartingVideoStreamIndexNo}-${strEndingVideoStreamIndexNo}] > " number
           		[[ $number =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  				if ((number >= ${strStartingVideoStreamIndexNo} && number <= ${strEndingVideoStreamIndexNo}))
  				then
    				break
  				else
    				echo "Please chose a valid steam index number, try again"
  				fi
			done
           	;;
           		
      	audio)
      		while true
    		do
    	       	read -p "Please choose an audio stream to rename:  index [${strStartingAudioStreamIndexNo}-${strEndingAudioStreamIndexNo}] > " number
           		[[ $number =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  				if ((number >= ${strStartingAudioStreamIndexNo} && number <= ${strEndingAudioStreamIndexNo}))
  				then
    				break
  				else
    				echo "Please chose a valid steam index number, try again"
  				fi
			done
           	;;
      	
		subtitle)
			while true
    		do
    	       	read -p "Please choose a subtitle stream to rename:  index [${strStartingSubtitleStreamIndexNo}-${strEndingSubtitleStreamIndexNo}] > " number
           		[[ $number =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  				if ((number >= ${strStartingSubtitleStreamIndexNo} && number <= ${strEndingSubtitleStreamIndexNo}))
  				then
    				break
  				else
    				echo "Please chose a valid steam index number, try again"
  				fi
			done
           	;;
	esac
	
	strStreamNumber=$number
	strCurrentStreamTitle=$( grep "${strRenameTrackArg1}\t$strStreamNumber" $strFfprobeTsvFile | cut -f11 )
	read -p "Rename track $strStreamNumber from $strCurrentStreamTitle to:  "
	strAudioStreamNewTitle=$REPLY
	((strStreamNumber++))

	mkvpropedit $FILE --edit track:$strStreamNumber --set name=${strAudioStreamNewTitle}
	step4_ffprobe_tsv

}




step4_set_default_audio_track() {

	# Define the variables for this function
	strCheckCurrentAudioDefaultIndex=""
	strCurrentAudioDefaultIndexNumber=""
	strDefaultAudioChoice=""
	strChangeDefaultAudioStream=""
	strDefaultAudioStream=""
	strAudioTrackListing=""

	# Identify the current default audio track and index number
	local strCheckCurrentAudioDefaultIndex=$( grep ^audio $strFfprobeTsvFile | cut -f9 | grep "1" | wc -l )

	if [ $strCheckCurrentAudioDefaultIndex -eq 1 ] 
		then
			strCurrentAudioDefaultIndexNumber=$( grep ^audio $strFfprobeTsvFile | cut -f2,9 | grep "\t1" | cut -f1 )	
			echo ""
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
			step4_ffprobe_command $FILE | step4_jq_selectstream_command audio
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
			echo ""	
			echo "**************************************************************************"
			echo "Audio track *** $strCurrentAudioDefaultIndexNumber *** is the current default track"
			echo "**************************************************************************"
			echo ""
						
			read -p "Is this correct? [y|n] > " strDefaultAudioChoice
			if [[ $strDefaultAudioChoice =~ ^[yYnN]$ ]]; then
			case $strDefaultAudioChoice in
				y|Y) 
					echo "CONFIRMED:  Audio track *** $strCurrentAudioDefaultIndexNumber *** remains the current default track "
					echo ""
					;;		
				n|N)
					while true
    				do
    	       			read -p "Please choose a default audio stream:  index [${strStartingAudioStreamIndexNo}-${strEndingAudioStreamIndexNo}] > "	strChangeDefaultAudioStream
           				[[ $strChangeDefaultAudioStream =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  						if ((${strChangeDefaultAudioStream} >= ${strStartingAudioStreamIndexNo} && ${strChangeDefaultAudioStream} <= ${strEndingAudioStreamIndexNo}))
  						then
    						break
  						else
    						echo "Please chose a valid steam index number, try again"
  						fi
					done
					
					((strChangeDefaultAudioStream++))
					((strCurrentAudioDefaultIndexNumber++))
					
					mkvpropedit $FILE --edit track:$strCurrentAudioDefaultIndexNumber --set flag-default=0
					mkvpropedit $FILE --edit track:$strChangeDefaultAudioStream --set flag-default=1
					step4_ffprobe_tsv
					;;
				*) 
					exit
					;;
			esac	
			else
    			echo "Invalid entry."
    			sleep $DELAY
  			fi	
			
	elif [ $strCheckCurrentAudioDefaultIndex -eq 0 ] 
		then
			echo ""
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
			step4_ffprobe_command $FILE | step4_jq_selectstream_command audio
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
			echo ""			
			echo "**************************************************************************"
			echo "WARNING:  NO audio tracks have been set to a default track."
			echo "**************************************************************************"
			echo ""
			
			while true
    		do
    	       	read -p "Please choose a default audio stream to:  index [${strStartingAudioStreamIndexNo}-${strEndingAudioStreamIndexNo}] > "
           		[[ $REPLY =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  				if ((REPLY >= ${strStartingAudioStreamIndexNo} && REPLY <= ${strEndingAudioStreamIndexNo}))
  				then
    				break
  				else
    				echo "Please chose a valid steam index number, try again"
  				fi
			done
			
          	strDefaultAudioStream=$REPLY
			((strDefaultAudioStream++))

			mkvpropedit $FILE --edit track:$strDefaultAudioStream --set flag-default=1
			step4_ffprobe_tsv
        				
	elif [ $strCheckCurrentAudioDefaultIndex -gt 1 ]
		then
			echo ""
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
			step4_ffprobe_command $FILE | step4_jq_selectstream_command audio
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
			echo ""			
			echo "**************************************************************************"
			echo "WARNING:  Multiple audio tracks have been set to default track."
			echo "         	Only one track can be set to default."
			echo "**************************************************************************"
			echo ""
			
			while true
    		do
    	       	read -p "Please choose a default audio stream:  index [${strStartingAudioStreamIndexNo}-${strEndingAudioStreamIndexNo}] > "
           		[[ $REPLY =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  				if ((REPLY >= ${strStartingAudioStreamIndexNo} && REPLY <= ${strEndingAudioStreamIndexNo}))
  				then
    				break
  				else
    				echo "Please chose a valid steam index number, try again"
  				fi
			done
			
          	strDefaultAudioStream=$REPLY
			((strDefaultAudioStream++))

			strAudioTrackListing=$( grep ^audio $strFfprobeTsvFile | cut -f2 )
			declare -a arrAudioTrackListing=($strAudioTrackListing)
			
			echo "Setting all audio tracks to Default=0"
			for i in "${arrAudioTrackListing[@]}"
			do
				((i++))
				mkvpropedit $FILE --edit track:$i --set flag-default=0
				ffprobe_tsv
			done	
			
			echo "Setting index $strDefaultAudioStream to default"
			mkvpropedit $FILE --edit track:$strDefaultAudioStream --set flag-default=1
			step4_ffprobe_tsv		
	fi	

}



step4_set_forced_subtitle_track() {

	# Define the variables for this function
	strCheckCurrentForcedSubIndex=""
	strCurrentForcedSubtitleIndexNumber=""
	strForcedChoice=""
	strChangeForcedStream=""
	strForcedChoice=""
	strNewForcedStream=""
	strSubtitleListing=""
		

	# Identify the current forced subtitle and index number
	strCheckCurrentForcedSubIndex=$( grep ^subtitle $strFfprobeTsvFile | cut -f10 | grep "1" | wc -l )

	if [ $strCheckCurrentForcedSubIndex -eq 1 ] 
		then
			strCurrentForcedSubtitleIndexNumber=$( grep ^subtitle $strFfprobeTsvFile | cut -f2,10 | grep "\t1" | cut -f1 )	
			echo ""
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
			step4_ffprobe_command $FILE | step4_jq_selectstream_command subtitle
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
			echo ""	
			echo "**************************************************************************"
			echo "Subtitle stream *** $strCurrentForcedSubtitleIndexNumber *** is currently set to forced"
			echo "**************************************************************************"
			echo ""
						
			read -p "Is this correct? [y|n] > " strForcedChoice
			if [[ $strForcedChoice =~ ^[yYnN]$ ]]; then
			case $strForcedChoice in
				y|Y) 
					echo "CONFIRMED:  Forced subtitle index *** $strCurrentForcedSubtitleIndexNumber *** remains set to forced "
					echo ""
					;;		
				n|N)
					while true
    				do
    	       			read -p "Please choose a new forced subtitle:  index [${strStartingSubtitleStreamIndexNo}-${strEndingSubtitleStreamIndexNo}] > "	strChangeForcedStream
           				[[ $strChangeForcedStream =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  						if ((${strChangeForcedStream} >= ${strStartingSubtitleStreamIndexNo} && ${strChangeForcedStream} <= ${strEndingSubtitleStreamIndexNo}))
  						then
    						break
  						else
    						echo "Please chose a valid steam index number, try again"
  						fi
					done
				
					((strChangeForcedStream++))
					((strCurrentForcedSubtitleIndexNumber++))
					mkvpropedit $FILE --edit track:$strCurrentForcedSubtitleIndexNumber --set flag-forced=0
					mkvpropedit $FILE --edit track:$strChangeForcedStream --set flag-forced=1
					step4_ffprobe_tsv
					;;
				*) 
					exit
					;;
			esac	
			else
    			echo "Invalid entry."
    			sleep $DELAY
  			fi	
			
	elif [ $strCheckCurrentForcedSubIndex -eq 0 ] 
		then
			echo ""
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
			step4_ffprobe_command $FILE | step4_jq_selectstream_command subtitle
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
			echo ""			
			echo "**************************************************************************"
			echo "WARNING:  NO forced subtitles have been set."
			echo "**************************************************************************"
			echo ""
			
           	read -p "Is this correct? [y|n] > " strForcedChoice
           	if [[ $strForcedChoice =~ ^[yYnN]$ ]]; then
			case $strForcedChoice in
				y|Y) 
					echo "CONFIRMED:  No Forced subtitle will be set. "
					echo ""
					;;		
				n|N)
					while true
    				do
    	       			read -p "Please choose a new forced subtitle:  index [${strStartingSubtitleStreamIndexNo}-${strEndingSubtitleStreamIndexNo}] > "	strNewForcedStream
           				[[ $strNewForcedStream =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  						if ((${strNewForcedStream} >= ${strStartingSubtitleStreamIndexNo} && ${strNewForcedStream} <= ${strEndingSubtitleStreamIndexNo}))
  						then
    						break
  						else
    						echo "Please chose a valid steam index number, try again"
  						fi
					done
				
					((strNewForcedStream++))
					mkvpropedit $FILE --edit track:$strNewForcedStream --set flag-forced=1
					step4_ffprobe_tsv
					;;
				*) 
					exit
					;;
			esac	
        	else
    			echo "Invalid entry."
    			sleep $DELAY
  			fi
        	
        				
	elif [ $strCheckCurrentForcedSubIndex -gt 1 ]
		then
			echo ""
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
			step4_ffprobe_command $FILE | step4_jq_selectstream_command subtitle
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
			echo ""			
			echo "**************************************************************************"
			echo "WARNING:  Multiple forced subtitles have been set."
			echo "         	Only one track can be set to forced."
			echo "**************************************************************************"
			echo ""

			while true
    		do
    	    	read -p "Please choose a new forced subtitle:  index [${strStartingSubtitleStreamIndexNo}-${strEndingSubtitleStreamIndexNo}] > "
           		[[ $REPLY =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  				if ((REPLY >= ${strStartingSubtitleStreamIndexNo} && REPLY <= ${strEndingSubtitleStreamIndexNo}))
  				then
    				break
  				else
    				echo "Please chose a valid steam index number, try again"
  				fi
			done

          	changeForcedStream=$REPLY
			((changeForcedStream++))

			strSubtitleListing=$( grep ^subtitle $strFfprobeTsvFile | cut -f2 )
			declare -a arrSubtitleTrackListing=($strSubtitleListing)
			
			echo "Setting all subtitle forced values to 0"
			for i in "${arrSubtitleTrackListing[@]}"
			do
				((i++))
				mkvpropedit $FILE --edit track:$i --set flag-forced=0
				step4_ffprobe_tsv
			done	
			
			echo "Setting index $REPLY to default"
			mkvpropedit $FILE --edit track:$changeForcedStream --set flag-forced=1
			step4_ffprobe_tsv		
	fi	

}



step4_copy_original_video() {
	
	# When this option is chosen, no video transcoding will take place but instead
	# the main video track will be copied directly using the --copy-video argument.
	# 
	# The --copy-video argument necessitates the removal of --nvenc --hevc --nvenc-temporal-aq
	# from the final other-transcode command.
	#
	# As this option will not rely on the metadata contained within an ffprobe search,
	# a trigger (override) file will be required for this and other options so that 
	# batch processing or future retranscoding has a record of the switch.

		
	# Step 1 - ensure there is only one video track
	
	# Define the variables for this function
	strCheckVideoTrackCount=""
	SetCopyVideo=""	

	# Identify the current forced subtitle and index number
	strCheckVideoTrackCount=$( grep ^video $strFfprobeTsvFile | cut -f1 | wc -l )

	if [ $strCheckVideoTrackCount -eq 1 ] 
		then
			echo "Output file:  $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt "
			echo "SetCopyVideo,true" >> $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt 
	elif [ $strCheckVideoTrackCount -ne 1 ]
		then
			echo "More than one video track has been found."
			echo "Please use mkvpropedit GUI to remove the addition video tracks"
			echo "so that only one video track remains."
	fi

	echo "---------------------------------------------------"
	echo "The --copy-video flag has been set."
	echo "---------------------------------------------------"

}



step4_copy_main_audio() {
	
	# When this option is chosen, the default audio track will be copied directly 
	# using the --main-audio=original argument.
	
	# Step 1 - ensure the default audio track is set
	
	# Define the variables for this function
	strCurrentAudioDefaultIndexCount=""
	strCurrentAudioDefaultIndex=""
	SetMainAudioTrackCopy=""	

	# Identify the current default audio track and index number
	strFFprobeDetail_MainAudio=$(ffprobe -i "$FILE" -v error -show_format -show_streams -show_data -print_format json=compact=1 2>/dev/null)
	strCurrentAudioDefaultIndex=$(echo "$strFFprobeDetail_MainAudio" | jq -r '.streams[] | select(.codec_type=="audio" and .disposition.default==1) | .index')
	strCurrentAudioDefaultIndexCount=$(echo "$strFFprobeDetail_MainAudio" | jq -r '.streams[] | select(.codec_type=="audio" and .disposition.default==1) | .index' | wc -l)


	echo "strRawName:   $strRawName"
	
	if [ $strCurrentAudioDefaultIndexCount -eq 1 ] 
		then
			echo "SetMainAudioTrackCopy,true" >> $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt
			echo "FILE:  $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt"

	else 
		echo "More than one default track has been found."
		echo "Please use mkvpropedit GUI to correct this so that only one"
		echo "default audio track is set."
	fi

	echo "---------------------------------------------------------------------"
	echo "The --main-audio ${strCurrentAudioDefaultIndex}=original has been set."
	echo "---------------------------------------------------------------------"


}


step4_copy_all_audio_tracks() {

	# List of audio tracks
	# Tracks can be either the default track or any other (identified by index)
	#  -> need to know which one is the default because --main-audio 1=original would be used instead of 
	#     --add-audio all=original
	#  -> If it's the main audio track, then the stereo pair will still be created
	#  -> --add-audio "Commentary" and --add-audio "AD" flags will be disabled


	# Define the variables for this function
	strCheckCurrentAudioDefaultIndex=""
	strCurrentAudioDefaultIndexNumber=""
	strCopyAllAudioChoice=""
	CopyAllOtherAudio=""

	# Identify the current default audio track and index number
	local strCheckCurrentAudioDefaultIndex=$( grep ^audio $strFfprobeTsvFile | cut -f9 | grep "1" | wc -l )
	strCurrentAudioDefaultIndexNumber=$( grep ^audio $strFfprobeTsvFile | cut -f2,9 | grep "\t1" | cut -f1 )	
	
	echo ""
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	step4_ffprobe_command $FILE | step4_jq_selectstream_command audio
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo ""	
	
	
	read -p "Copy ALL audio tracks using (=original) .... is this correct? [y|n] > " strCopyAllAudioChoice
	if [[ $strCopyAllAudioChoice =~ ^[yYnN]$ ]]; then
		case $strCopyAllAudioChoice in
			y|Y) 
				echo "CONFIRMED:  All audio tracks will be COPIED with no transcoding."
				echo ""
				step4_copy_main_audio
				CopyAllOtherAudio="true"
				echo "CopyAllOtherAudio,true" >> $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt
				;;		
			n|N)
				echo "DECLINED:  All audio tracks will NOT be COPIED "
				echo ""
				break
    	  		;;	
			*) 
				exit
				;;
		esac	
	else
    	echo "Invalid entry."
    	sleep $DELAY
  	fi	
	
}



step4_EAC3plusAAC() {

	# From Feb 2020, my default audio format is switching from 640 EAC-3 surround plus 256/128 AAC stereo/mono
	# to all EAC-3 covering 5.1/stereo/mono with 640/256/160 defaults.
	#
	# To revert to surround EAC-3 plus AAC for stereo/mono, the --all-eac3 flag needs to change back to --eac3
	
	echo "EAC3SurroundAACStereoMono,true" >> $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt
	echo ""
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo "EAC-3/Dolby Digital+ will be used for surround only. Stereo/Mono tracks will be AAC."
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo ""	

}


step4_EnableDTSPassthrough() {

	# Adds the --pass-dts to the end
	
	echo "EnableDTSPassthrough,true" >> $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt
	echo ""
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo "DTS Passthrough will be enabled"
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo ""	

}


step4_KeepAC3Stereo() {

	# Adds --keep-ac3-stereo at the end
	
	echo "KeepAC3Stereo,true" >> $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt
	echo ""
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo "AC-3 Stereo tracks will be kept"
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo ""	

}


step4_DisableForcedSubtitleAutoBurnIn() {

	
	echo "DisableForcedSubtitleAutoBurnIn,true" >> $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt
	echo ""
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo "Forced subtitle auto burn-in will be disabled"
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo ""	

}


step4_SurroundBitrateOverride() {

	while true
    do
    	read -p "Please enter the bitrate (kbit/s) override for SURROUND tracks [256-768] > "	strSurroundOverride
    [[ $strSurroundOverride =~ ^[0-9]+$ ]] || { echo "Enter a valid bitrate"; continue; }
  		if ((${strSurroundOverride} >= 256 && ${strSurroundOverride} <= 768))
  		then
    		break
  		else
    		echo "Please chose a valid bitrate, try again"
  		fi
	done
	
	echo "SurroundBitrateOverride,$strSurroundOverride" >> $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt
	echo ""
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo "The 640 kbit/s default for 5.1 surround has been changed to $strSurroundOverride."
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo ""	

}


step4_StereoBitrateOverride() {

	while true
    do
    	read -p "Please enter the bitrate (kbit/s) override for STEREO tracks [128-320] > "	strStereoOverride
    [[ $strStereoOverride =~ ^[0-9]+$ ]] || { echo "Enter a valid bitrate"; continue; }
  		if ((${strStereoOverride} >= 128 && ${strStereoOverride} <= 320))
  		then
    		break
  		else
    		echo "Please chose a valid bitrate, try again"
  		fi
	done
	
	echo "StereoBitrateOverride,$strStereoOverride" >> $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt
	echo ""
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo "The 256 kbit/s default for stereo has been changed to $strStereoOverride."
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo ""	

}


step4_MonoBitrateOverride() {

	while true
    do
    	read -p "Please enter the bitrate (kbit/s) override for MONO tracks [64-256] > "	strMonoOverride
    [[ $strMonoOverride =~ ^[0-9]+$ ]] || { echo "Enter a valid bitrate"; continue; }
  		if ((${strMonoOverride} >= 64 && ${strMonoOverride} <= 256))
  		then
    		break
  		else
    		echo "Please chose a valid bitrate, try again"
  		fi
	done
	
	echo "MonoBitrateOverride,$strMonoOverride" >> $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt
	echo ""
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo "The 128 kbit/s default for mono has been changed to $strMonoOverride."
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo ""	

}



step4_mkvpropedit_unfied_command() {

	# Define the variables for this function
	FILEwithoutExt=$( echo $FILE | sed 's/\.mkv$//g')
	strFfprobeTsvFile="${FILEwithoutExt}.tsv"
	strRawFilename=`echo $FILE | rev | cut -d'/' -f 1 | rev`
	strRawName=`echo $strRawFilename | sed 's/\.mkv//g'`
	
	Col01_stream=""
	Col02_index=""
	Col08_default=""
	Col09_forced=""
	Col10_title=""

	declare -a arrMkvpropeditUnifiedArgs=()
	arrMkvpropeditUnifiedArgs+=(mkvpropedit \"${FILE}\" )
	
	if [ -f ${FILE}.mkvpropedit.txt ]
	then
		rm ${FILE}.mkvpropedit.txt
	fi
	
	# Earlier, we checked and potentially updated the movie title
	# This will be included in the generic mkvpropedit output file for completeness
	
	arrMkvpropeditUnifiedArgs+=(--edit info --set title=\"${strRawName}\")
	
	while IFS= read -r line
	do
		Col01_stream=$( echo $line | cut -f1 )
		Col02_index=$( echo $line | cut -f2 )
		Col08_default=$( echo $line | cut -f9 )
		Col09_forced=$( echo $line | cut -f10 )
		Col10_title=$( echo $line | cut -f11 )

		case $Col01_stream in
			video)
				((Col02_index++))
				arrMkvpropeditUnifiedArgs+=(--edit track:${Col02_index} --set name=\"${Col10_title}\")
				;;
			audio)
				((Col02_index++))
				arrMkvpropeditUnifiedArgs+=(--edit track:${Col02_index} --set name=\"${Col10_title}\" --set flag-default=${Col08_default} )
				;;
			subtitle)
				((Col02_index++))
				arrMkvpropeditUnifiedArgs+=(--edit track:${Col02_index} --set name=\"${Col10_title}\" --set flag-default=${Col08_default} --set flag-forced=${Col09_forced} )
				;;
		esac
	done < $strFfprobeTsvFile
	
	if [[ ! -d ${dirOutboxSummaries}/${strRawName} ]]
	then
		mkdir ${dirOutboxSummaries}/${strRawName}
	fi
		
	echo "${arrMkvpropeditUnifiedArgs[@]}" > ${dirOutboxSummaries}/${strRawName}/${strRawName}.pre-mkvpropedit.txt

}


step4_ffprobe_json_output() {

	strFfprobe_json_type=$1
	# This takes one input:   
	#							$1:	'raw' | 'transcoded'
	# For 'raw' -> ffprobe on the Bluray rip after the renaming and mkvpropedit edits
	# For 'transcoded' -> ffprobe on the transcoded version after the audio stream titling mkvpropedit edits
	
	# Check to see if the output folder exists and if not, create it
	
	if [[ ! -d ${dirOutboxSummaries}/${strRawName} ]]
	then
		mkdir ${dirOutboxSummaries}/${strRawName}
	fi

	case $strFfprobe_json_type in
		raw)
			if [ ! -f $strRawPathAndFile ]
			then
				echo "The following file ($strRawPathAndFile) does not exist. Exiting ..."
				exit
			fi
			
			echo "Generating the JSON ffprobe file for ${strRawName} ..."
			echo "   Location:  \"${dirOutboxSummaries}/${strRawName}/${strRawName}.ffprobe.raw.json\" "
			ffprobe -i $FILE -v quiet -print_format json -show_format -show_streams -hide_banner &> ${dirOutboxSummaries}/${strRawName}/${strRawName}.ffprobe.raw.json
			echo "Complete"
			;;
			
		transcoded)
			echo "Generating the JSON ffprobe file for ${strRawName} ..."
			ffprobe -i ${dirTranscoded}/${strRawName}/{strRawFilename} -v quiet -print_format json -show_format -show_streams -hide_banner | tee "${dirOutboxSummaries}/${strRawName}.ffprobe.transcoded.json"
			echo "Complete"
			;;	
		*)
			echo "something went wrong"
			;;	
	esac
			
}




step4_tsv_cleanup() {

	if [ -f ${FILEwithoutExt}.tsv ]
	then
		if [[ ! -d ${dirOutboxSummaries}/${strRawName} ]]
			then
			mkdir ${dirOutboxSummaries}/${strRawName}
		fi
		mv ${FILEwithoutExt}.tsv ${dirOutboxSummaries}/${strRawName}/
	fi

}




step4_usex264-avbr() {

	echo ""
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
	echo ""
	echo "***********************************************"
	echo "***********************************************"
	echo "*                                             *"
	echo "*    x264-avbr software transcoding ACTIVE    *"
	echo "*                                             *"
	echo "***********************************************"
	echo "***********************************************"
	echo "" 
	echo "Setting $FILE to be transcoded using the software x264-avbr option."
	echo ""
	
	echo "X264AVBRActive,true" >> $dirOutboxCommands/${str04RawName}.other-transcode.override.command.txt
	
	echo "------------------------------------------------------------------------------------------------------------------------------------------------------"

}



##########################################################################
# STEP 5 - Dynamically build the other-transcode command for each of     #
#          the mkv files in the Processing folder                        #
##########################################################################
	
other-transcode_commands() {

	echo "*******************************************************************************"
	echo "Starting Step 5 - building the other-transcode commands" 
	echo ""
	echo ""

		
	# Need to identify the files for mkvpropedit processing next
	cd $dirProcessing

	echo "-------------------------------------------------------------------------------"
	echo "Location:   $dirOutboxCommands"
	echo "-------------------------------------------------------------------------------"
	echo "Building the other-transcode command for:"
	 
	for str05FileName in `find . -type f -name "*.mkv" | sort` 
	do
		str05File=${str05FileName:2}
		FILE=${dirProcessing}/${str05File}
		str05RawFilename=`echo $FILE | rev | cut -d'/' -f 1 | rev`
		str05RawName=`echo $str05RawFilename | sed 's/\.mkv//g'`
		
		if [ "$strBatchMode" = "On" ]
		then
			# BatchMode is ACTIVE
			dirWinWorkDir="F:"
			strWinFile="${dirWinWorkDir}\\${str05File}"
			strBatchOverrideLocation="${dirMediaDir}/Transcoding/Overrides"
		else
			strWinFile="${dirWinWorkDir}\\04_ReadyForTranscoding\\${str05File}"

		fi
	

		IFS=$'\n'
				
		# Variables	
  		
  		str05FfprobeOutput=""
  		str05DefaultVideoCodec=""
  		str05DefaultAudioTrackIndex=""
  		str05DefaultAudioTrackCodec=""
  		str05DefaultAudioTrackChannelLayout=""
  		str05DefaultAudioTrackAudioCommentaryPresence=""
  		str05DefaultAudioTrackCommentaryChannelLayout=""
  		str05DefaultAudioTrackAudioADPresence=""
  		str05DefaultAudioTrackADChannelLayout=""
  		str05DefaultAudioTrackSubForcedFlagPresence=""
  		str05ProgressiveOrInterlace=""
  		str05SubtitleEnglishPresence=""
  		str05SubtitleSDHPresence=""
  		str05SubtitleCommentaryPresence=""
  		str05OverrideFile=""
  		str05EAC3SurroundAACStereoMono=""
  		str05EnableDTSPassthrough=""
  		str05KeepAC3Stereo=""
  		str05SurroundBitrateOverride=""
  		str05StereoBitrateOverride=""
  		str05MonoBitrateOverride=""
  		

  		
  		# In order to determine the channel width of AD and Commentary audio streams, there's an assumption that there'll only ever be one (1) AD track named "AD"
  		# and so the jq search below is for "AD" only, uppercase. In the very unlikely event that two audio streams are called "AD" (and not AD1, AD2), then the sort -u
  		# will determine the final channel width.
  		#
  		# A similar process exists for Commentary audio streams but this could be a little more complex because it's common to have multiple Commentary streams
  		# and while each is named with "Commentary" or "commentary", there could be a difference in channel widths. However, it's very unlikely that a BR movie
  		# with e.g. three commentary tracks would be a mixture of Surround 5.1 and stereo. If it is, it's a rarity. So the variable has a sort -u in place to 
  		# make the value unique instead of a list from jq should 2 or more exist. This uniqueness has a minor risk of getting the width wrong if there's a mix
  		# of channel widths so it's wise to check the corresponding auto-generated commands in these rate scenarios. If there is a mix, then it's probably 
  		# going to require manual intervention to have sets of --add-audio flags looking for more details text strings to uniquely identify the string and then
  		# manually assign the width (=stereo|surround) by stream.
  	
  	
  		declare -i str05DefaultAudioTrackAudioCommentaryPresence
  		
  		str05FfprobeOutput=$( step4_ffprobe_command $FILE )
  		str05DefaultVideoCodec=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="video") | .codec_name' )
  		str05DefaultAudioTrackIndex=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="audio" and .disposition.default==1) | .index' )
  		str05DefaultAudioTrackCodec=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="audio" and .disposition.default==1) | .codec_name' )
  		str05DefaultAudioTrackChannelLayout=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="audio" and .disposition.default==1) | .channel_layout' )
  		str05DefaultAudioTrackAudioCommentaryPresence=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="audio") | .tags.title' | grep -i "Commentary" | wc -l )
 		str05DefaultAudioTrackCommentaryChannelLayout=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="audio" and contains(.tags.title="ommentary")) | .channel_layout' | sort -u )

  		str05DefaultAudioTrackAudioADPresence=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="audio") | .tags.title' | grep -w "AD" | wc -l )
  		str05DefaultAudioTrackADChannelLayout=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="audio" and .tags.title=="AD") | .channel_layout' | sort -u )

  		str05DefaultAudioTrackSubForcedFlagPresence=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="subtitle") | .disposition.forced' | grep -w "1" | wc -l )
  		str05DefaultAudioTrackLanguage=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="audio" and .disposition.default==1) | .tags.language' )
  		str05ProgressiveOrInterlace=$( echo "$str05FfprobeOutput" | jq -r '.streams[0].field_order' )
		str05SubtitleEnglishPresence=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="subtitle") | .tags.title' | grep -i "English" | wc -l )
		str05SubtitleSDHPresence=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="subtitle") | .tags.title' | grep "SDH" | wc -l )
		str05SubtitleCommentaryPresence=$( echo "$str05FfprobeOutput" | jq -r '.streams[] | select(.codec_type=="subtitle") | .tags.title' | grep -i "Commentary" | wc -l )


		# Assumptions 
		#  - one video track is present -> audio track numbering for other-transcode will match the ffprobe index numbers
		#  - this script will run on a Mac to generate commands for an Nvidia-enabled PC
		#  - FFmpeg doesn’t dynamically reposition and scale the overlay like HandBrake. As a result, --crop auto cannot be used where burn-in subtitles is needed.
		#  - If a commands override file exists, then those variables will be imported and used further down.


		if [ "$strBatchMode" = "On" ]
		then
			str05OverrideFile="${strBatchOverrideLocation}/${str05RawName}.other-transcode.override.command.txt"
		else	
			str05OverrideFile="$dirOutboxCommands/${str05RawName}.other-transcode.override.command.txt"
		fi
			
		if [ -f $str05OverrideFile ]
		then
			str05SetCopyVideo=$( grep SetCopyVideo $str05OverrideFile | cut -d"," -f2 2>&1)
			str05X264AVBRActive=$( grep X264AVBRActive $str05OverrideFile | cut -d"," -f2 2>&1)
			str05SetMainAudioTrackCopy=$( grep SetMainAudioTrackCopy $str05OverrideFile | cut -d"," -f2 2>&1)
			str05CopyAllOtherAudio=$( grep CopyAllOtherAudio $str05OverrideFile | cut -d"," -f2 2>&1)
			str05EAC3SurroundAACStereoMono=$( grep EAC3SurroundAACStereoMono $str05OverrideFile | cut -d"," -f2 2>&1)
			str05DisableForcedSubtitleAutoBurnIn=$( grep DisableForcedSubtitleAutoBurnIn $str05OverrideFile | cut -d"," -f2 2>&1)
			str05EnableDTSPassthrough=$( grep EnableDTSPassthrough $str05OverrideFile | cut -d"," -f2 2>&1)
			str05KeepAC3Stereo=$( grep KeepAC3Stereo $str05OverrideFile | cut -d"," -f2 2>&1)
			str05SurroundBitrateOverride=$( grep SurroundBitrateOverride $str05OverrideFile | cut -d"," -f2 2>&1)
			str05StereoBitrateOverride=$( grep StereoBitrateOverride $str05OverrideFile | cut -d"," -f2 2>&1)
  			str05MonoBitrateOverride=$( grep MonoBitrateOverride $str05OverrideFile | cut -d"," -f2 2>&1)
		fi	


  		declare -a arrHwTranscodeCommand=()
  		
  		
  		# VIDEO SET-UP
		# ---------------------------------------------------
   		 		
  		if [[ "$str05X264AVBRActive" = "true" ]]
  			then
  			arrHwTranscodeRbCommand=(call other-transcode \"${strWinFile}\" --x264-avbr --crop auto )
  			
  		elif [[ "$str05SetCopyVideo" = "true" ]]
  		 	then
  		 	arrHwTranscodeRbCommand=(call other-transcode \"${strWinFile}\" --copy-video )

  		else
			# arrHwTranscodeRbCommand=(other-transcode \"${FILE}\" --nvenc )
			arrHwTranscodeRbCommand=(call other-transcode \"${strWinFile}\" --nvenc --hevc --nvenc-temporal-aq )
		fi			





		# AUDIO SET-UP
		# ---------------------------------------------------
		#   - check to ensure a FLAC track is being used in all cases for surround sound tracks. Ignore if there's a default stereo track
		# 	- check to see if a track called AD or Commentary (or both) is present and include extra --add-audio options
		# 	- if FLAC is the track codec, then use --eac3 otherwise if AC-3 is the main track, do no include --eac3
		#   - by default, --add-audio downsamples to stereo. I would like to retain Surround sound 5.1 if the track is in 5.1.
				
		# Set up main audio and stereo options
		
		# The channel layout can be 7.1, 5.1, stereo or mono so the addition of an additional stereo track should
		# only apply if the layout is 7.1 or 5.1 only. No stereo track should be added to an existing stereo or mono
		# source.



		# Audio format
		# ---------------------------------------------------
		# The default is --all-eac3 for certain codecs. Otherwise it's AC3 and/or AAC
		# 
		
		case $str05DefaultAudioTrackCodec in
		
			flac | ac3 | dts| truehd)
				if [ "$str05DefaultAudioTrackChannelLayout" != "stereo" ] || [ "$str05DefaultAudioTrackChannelLayout" != "mono" ] && [ "$str05EAC3SurroundAACStereoMono" = "true" ]
				then
					arrHwTranscodeRbCommand+=(--eac3)
				else
					arrHwTranscodeRbCommand+=(--all-eac3)	
				fi	
				;;
			eac3)
				if [ "$str05DefaultAudioTrackChannelLayout" != "stereo" ] || [ "$str05DefaultAudioTrackChannelLayout" != "mono" ] && [ "$str05EAC3SurroundAACStereoMono" = "true" ]
				then
					arrHwTranscodeRbCommand+=()
				else
					arrHwTranscodeRbCommand+=(--all-eac3)	
				fi	
				;;				
			pcm_s16le)
				if [ "$str05DefaultAudioTrackChannelLayout" != "stereo" ] || [ "$str05DefaultAudioTrackChannelLayout" != "mono" ] && [ "$str05EAC3SurroundAACStereoMono" = "true" ]
				then
					arrHwTranscodeRbCommand+=()
				else
					arrHwTranscodeRbCommand+=()	
				fi	
				;;	
				
			*)
				echo "*********************************************************************************"
				echo "WARNING:    "
				echo ""
				echo "$FILE"
				echo ""
				echo "The Default audio track is neither FLAC, EAC3, AC-3, DTS, TrueHD nor PSM_S16LE"
				echo ""
				echo "Please check ... exiting now"
				echo "*********************************************************************************"
				exit 1		
				;;
		esac		
		
		
		
		# Main Audio Settings
		# ---------------------------------------------------
		# 		
		
				
		if [[ "$str05SetMainAudioTrackCopy" = "true" ]]
		then
			str05MainAudioOriginalSetting="=original"			
		fi
				
		case $str05DefaultAudioTrackCodec in
		
			flac)
				arrHwTranscodeRbCommand+=(--main-audio ${str05DefaultAudioTrackIndex}${str05MainAudioOriginalSetting})	
				;;
			eac3)
				arrHwTranscodeRbCommand+=(--main-audio ${str05DefaultAudioTrackIndex}${str05MainAudioOriginalSetting})	
				;;			
			ac3)
				arrHwTranscodeRbCommand+=(--main-audio ${str05DefaultAudioTrackIndex}${str05MainAudioOriginalSetting})	
				;;
			dts)
				arrHwTranscodeRbCommand+=(--main-audio ${str05DefaultAudioTrackIndex}${str05MainAudioOriginalSetting})	
				;;
			truehd)
				arrHwTranscodeRbCommand+=(--main-audio ${str05DefaultAudioTrackIndex}${str05MainAudioOriginalSetting})	
				;;			
			pcm_s16le)
				arrHwTranscodeRbCommand+=(--main-audio ${str05DefaultAudioTrackIndex}${str05MainAudioOriginalSetting})	
				;;
			*)
				echo "*********************************************************************************"
				echo "WARNING:    "
				echo ""
				echo "$FILE"
				echo ""
				echo "The Default audio track is neither FLAC, EAC3, AC-3, DTS, TrueHD nor PSM_S16LE"
				echo ""
				echo "Please check ... exiting now"
				echo "*********************************************************************************"
				exit 1		
				;;
		esac



		# ADD Extra Stereo track from Main Audio
		# ---------------------------------------------------
		# No stereo track if all audio is being copied.		
		
		if [ "$str05CopyAllOtherAudio" != "true" ]
		then
		
		case $str05DefaultAudioTrackCodec in
		
			flac|eac3|ac3|dts|truehd|pcm_s16le)
				if [ "$str05DefaultAudioTrackChannelLayout" = "mono" ]
				then
					arrHwTranscodeRbCommand+=()					
				elif [ "$str05DefaultAudioTrackChannelLayout" = "stereo" ]
				then
					arrHwTranscodeRbCommand+=()
				elif [ "$str05DefaultAudioTrackChannelLayout" = "3.0" ]
				then
					arrHwTranscodeRbCommand+=()
				else
					arrHwTranscodeRbCommand+=(--add-audio ${str05DefaultAudioTrackIndex}=stereo)					
				fi	
				;;
				
			*)
				echo "*********************************************************************************"
				echo "WARNING:    "
				echo ""
				echo "$FILE"
				echo ""
				echo "The Default audio track is neither FLAC, EAC3, AC-3, DTS, TrueHD nor PSM_S16LE"
				echo ""
				echo "Please check ... exiting now"
				echo "*********************************************************************************"
				exit 1		
				;;
		esac
		fi
		
		
		# ADD Commentary, AD and original options
		# ---------------------------------------------------
		# 	
		
		if [ "$str05CopyAllOtherAudio" = "true" ]
		then
			arrHwTranscodeRbCommand+=(--add-audio all=original )
		else
		
			# Check for a track called "Commentary" and/or "AD" ... exact matches only
			# By default, these are set to stereo but retention of the underlying surround or stereo is important


			if [ "$str05DefaultAudioTrackAudioCommentaryPresence" -ge 1 ]
			then
				case $str05DefaultAudioTrackCommentaryChannelLayout in
			
					"4.0"|"5.0(side)"|"5.1(side)"|"6.1"|"7.1") 
						arrHwTranscodeRbCommand+=(--add-audio \"Commentary\"=surround )
						;;

					"3.0"|stereo)
						arrHwTranscodeRbCommand+=(--add-audio \"Commentary\"=stereo )
						;;

					mono)
						arrHwTranscodeRbCommand+=(--add-audio \"Commentary\" )
						;;

					*)	
						arrHwTranscodeRbCommand+=(--add-audio \"Commentary\" )
						;;	
				esac	
			fi

			if [ "$str05DefaultAudioTrackAudioADPresence" -ge 1 ]
			then
				case $str05DefaultAudioTrackADChannelLayout in
		
					"4.0"|"5.0(side)"|"5.1(side)"|"6.1"|"7.1") 
						arrHwTranscodeRbCommand+=(--add-audio \"AD\"=surround )
						;;
				
					"3.0"|stereo)
						arrHwTranscodeRbCommand+=(--add-audio \"AD\"=stereo )
						;;
				
					mono)
						arrHwTranscodeRbCommand+=(--add-audio \"AD\" )
						;;
				
					*)	
						arrHwTranscodeRbCommand+=(--add-audio \"AD\" )
						;;	
				esac	
			fi
		fi	


		
		# FORCED TRACK SUB-TITLE SET-UP
		# FFmpeg doesn’t dynamically reposition and scale the overlay like HandBrake. 
		# As a result, --crop auto cannot be used if the forced-subtitle flag is set and burn-in applied.
		# For all other cases, --crop auto is applied below instead. 
		#
		# [2019.09.25] - removed from defaults as testing has shown
		# that there's a 30% drop-off in fps when crops > 55 pixels are applied. As a result, full frame will be the DEFAULT
		# to retain max fps speed but also to prevent subtitle positional issues with ffmpeg.
		
		if [ "$str05DisableForcedSubtitleAutoBurnIn" != "true" ]
		then
			if [ "$str05DefaultAudioTrackSubForcedFlagPresence" -eq "1" ]
			then
				arrHwTranscodeRbCommand+=(--burn-subtitle auto)
			fi
		fi	


		# Addition of specific subtitles covering "English", "SDH" and "Commentary"
		# The vast majority of subtitle streams contain one or more subtitles and these are labeled in a standard/consistent way using 
		# "English" or "SDH" or some text with "Commentary" in its title.
		# This is the norm for the majority of transcodes. 
		#
		# However, when the main language is NOT English (e.g. Chinese, Japanese, French, Swedish etc.)
		# then I'll burn-in the default English or SDH subtitle track by setting it as a Forced Subtitle in the interactive section.
		# As a result, we need to check the language of the default audio track's language setting and if it's not English (eng), 
		# the following subtitle(s) are added if they are available:
		# - "Commentary"
		#		
		# But, in the case of non-English default audio streams, if there is no forced flag, then the full compliment of possible subtitles 
		# ("English", "SDH", "Commentary") can also be added so that an English PGS is present to be manually set when watching the 
		# transcoded movie.
		
				
		case $str05DefaultAudioTrackLanguage in
			eng)
				if [ "$str05SubtitleEnglishPresence" -eq "1" ]
				then
					arrHwTranscodeRbCommand+=(--add-subtitle \"English\")
				fi
				
				if [ "$str05SubtitleSDHPresence" -eq 1 ]
				then
					arrHwTranscodeRbCommand+=(--add-subtitle \"SDH\")
				fi
				
				if [ "$str05SubtitleCommentaryPresence" -ge 1 ]
				then
					arrHwTranscodeRbCommand+=(--add-subtitle \"Commentary\")
				fi
				;;
			*)
				if [ "$str05DefaultAudioTrackSubForcedFlagPresence" -eq "1" ]
				then
					if [ "$str05SubtitleCommentaryPresence" -ge 1 ]
					then
						arrHwTranscodeRbCommand+=(--add-subtitle \"Commentary\")
					fi
				else
					if [ "$str05SubtitleEnglishPresence" -eq "1" ]
					then
						arrHwTranscodeRbCommand+=(--add-subtitle \"English\")
					fi
				
					if [ "$str05SubtitleSDHPresence" -eq 1 ]
					then
						arrHwTranscodeRbCommand+=(--add-subtitle \"SDH\")
					fi
				
					if [ "$str05SubtitleCommentaryPresence" -ge 1 ]
					then
						arrHwTranscodeRbCommand+=(--add-subtitle \"Commentary\")
					fi
				fi
				;;
		esac
		

  		# CHECK FOR INTERLACED (720i or 1080i) CONTENT
  		# The expectation for field_order is "progressive" but if any of the interlaced options are found,
  		# deinterlacing will be needed. "field_order" values include 'tt', 'bb', 'tb' and 'bt' for interlaced content
  		# or "progressive"
  		  	
		if [ "$str05ProgressiveOrInterlace" != "progressive" ]
		then
			arrHwTranscodeRbCommand+=(--deinterlace)
		fi


		if [ "$str05ProgressiveOrInterlace" != "progressive" ]
		then
			echo "  - ${str05RawName}    (with deinterlace included)"
		else
			echo "  - ${str05RawName}"
		fi


		# DTS Passthrough enabled
		# ---------------------------------------------------

		if [ "$str05EnableDTSPassthrough" = "true" ]
		then
			arrHwTranscodeRbCommand+=(--pass-dts)
		fi	
		
		
		# AS-3 Stereo retention
		# ---------------------------------------------------
		
		if [ "$str05KeepAC3Stereo" = "true" ]
		then
			arrHwTranscodeRbCommand+=(--keep-ac3-stereo)
		fi	


		# Surround Bitrate Override
		# ---------------------------------------------------

		if [[ $str05SurroundBitrateOverride =~ ^[0-9]+$ ]]
		then
			arrHwTranscodeRbCommand+=(--surround-bitrate $str05SurroundBitrateOverride)
		fi	


		# Stereo Bitrate Override
		# ---------------------------------------------------

		if [[ $str05StereoBitrateOverride =~ ^[0-9]+$ ]]
		then
			arrHwTranscodeRbCommand+=(--stereo-bitrate $str05StereoBitrateOverride)
		fi	

		
		# Mono Bitrate Override
		# ---------------------------------------------------

		if [[ $str05MonoBitrateOverride =~ ^[0-9]+$ ]]
		then
			arrHwTranscodeRbCommand+=(--mono-bitrate $str05MonoBitrateOverride)
		fi	




		echo "${arrHwTranscodeRbCommand[@]}" > $dirOutboxCommands/${str05RawName}.other-transcode.command.txt

		# Unset Variables for next iteration
		unset str05SetCopyVideo
		unset str05X264AVBRActive
		unset str05SetMainAudioTrackCopy
		unset str05MainAudioOriginalSetting
		unset str05OverrideFile
		unset str05CopyAllOtherAudio
		unset strCurrentAudioDefaultIndexNumber
		unset str05EAC3SurroundAACStereoMono
		unset str05DisableForcedSubtitleAutoBurnIn
		unset str05EnableDTSPassthrough
  		unset str05KeepAC3Stereo
  		unset str05SurroundBitrateOverride
  		unset str05StereoBitrateOverride
  		unset str05MonoBitrateOverride
		
  		  		
  		if [ -f ${dirProcessing}/$str05FileName ]
		then
			mv ${dirProcessing}/$str05FileName ${dirReadyForTranscoding}/${str05File}
		fi
  		  				
	    read line </dev/null
	done

}





other-transcode_commands_concatenate () {

	echo ""
	echo "  - Building \"commands.bat\" file for Windows transcoding"

	if [ -f $dirOutboxCommands/commands.bat ]
	then
		rm $dirOutboxCommands/commands.bat
		cat $dirOutboxCommands/*.other-transcode.command.txt >> $dirOutboxCommands/commands.bat
	else
		cat $dirOutboxCommands/*.other-transcode.command.txt >> $dirOutboxCommands/commands.bat
	fi

	echo " "
	echo "Step 5 complete" 
	echo "*******************************************************************************"

}




##########################################################################
# POST-STEP01 - Set-up checks                                            #
##########################################################################

post_setup_checks() {

	# Part of the run-time options includes the '-e' argument which sets the environment
	# to either 'live' or 'test' as part of the strEnv variable from the getopt startup
	
	case $strEnv in
		live) 	post_setup_checks_live
				shift
				;;
		test)	post_setup_checks_test
				shift
				;;
		*)		usage
				exit
				;;
	esac					



	echo ""
	echo ""
	echo ""
	echo "-------------------------------------------------------------------------------"
	echo "Original RAW Content Directory:  	$dirReadyForTranscoding"
	echo "Transcoded Content Directory:  	$dirTranscodedWorkDir"
	echo "Plex Directory:  	$dirPlexDir"
	echo "NAS Media Directory:  	$dirMediaDir"
	echo "-------------------------------------------------------------------------------"
	echo ""
	echo ""
	echo ""
}


post_setup_checks_live() {

while true; do
	cat << _EOF_



*******************************************************************************
*                                                                             *
*                         LIVE PRODUCTION ENVIRONMENT                         *
*                                                                             *
*******************************************************************************



-------------------------------------------------------------------------------
Raw Original MKV Directory
-------------------------------------------------------------------------------

Please select one of the following:
===============================================================================

  1. /Volumes/E/Engine_Room/04_ReadyForTranscoding
  2. /Volumes/Media/Engine_Room/04_ReadyForTranscoding
  3. /mnt/e/Engine_Room/04_ReadyForTranscoding
  0. Quit
	
===============================================================================

_EOF_

	  read -p "Enter selection [0-3] > "

  		if [[ $REPLY =~ ^[0-3]$ ]]; then
    	case $REPLY in
     	1)
           	dirReadyForTranscoding="/Volumes/E/Engine_Room/04_ReadyForTranscoding"
          	break
          	;;
      	2)
      	  	dirReadyForTranscoding="/Volumes/Media/Engine_Room/04_ReadyForTranscoding"
          	break
          	;;
      	3)
      	  	dirReadyForTranscoding="/mnt/e/Engine_Room/04_ReadyForTranscoding"
          	break
          	;;  	
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry."
    	sleep $DELAY
  	fi
	done

	echo ""
	echo ""
	echo "Original RAW Content Directory:  	$dirReadyForTranscoding"
	echo "-------------------------------------------------------------------------------"
	echo ""
	echo ""
	echo ""


while true; do
	cat << _EOF_




-------------------------------------------------------------------------------
Transcoded Output Directory Set-up
-------------------------------------------------------------------------------

Please select one of the following:
===============================================================================

  1. /Volumes/D/05_Transcoded
  2. /Volumes/Media/Engine_Room/05_Transcoded
  3. /mnt/d/05_Transcoded
  4. /mnt/e/Transcoded
  5. /Volumes/E/Transcoded
  0. Quit
	
===============================================================================

_EOF_

	  read -p "Enter selection [0-5] > "

  		if [[ $REPLY =~ ^[0-5]$ ]]; then
    	case $REPLY in
     	1)
           	dirTranscodedWorkDir="/Volumes/D/05_Transcoded"
          	break
          	;;
      	2)
      	  	dirTranscodedWorkDir="/Volumes/Media/Engine_Room/05_Transcoded"
          	break
          	;;
      	3)
      	  	dirTranscodedWorkDir="/mnt/d/05_Transcoded"
          	break
          	;;
        4)
        	dirTranscodedWorkDir="/mnt/e/Transcoded"
          	break
          	;; 
        5)
        	dirTranscodedWorkDir="/Volumes/E/Transcoded"
          	break
          	;;  	
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry."
    	sleep $DELAY
  	fi
	done

	echo ""
	echo ""
	echo "Transcoded Content Directory:  	$dirTranscodedWorkDir"
	echo "-------------------------------------------------------------------------------"
	echo ""
	echo ""
	echo ""



	# WSL NAS mounts for Plex and Media
	# sudo mkdir /mnt/x
	# sudo mkdir /mnt/z
	#
	# sudo mount -t drvfs X: /mnt/x
	# sudo mount -t drvfs Z: /mnt/z

while true; do
	cat << _EOF_




-------------------------------------------------------------------------------
Plex Location Set-up
-------------------------------------------------------------------------------

Please select one of the following:
===============================================================================

  1. /Volumes/Plex
  2. /mnt/x
  0. Quit
	
===============================================================================

_EOF_

	  read -p "Enter selection [0-2] > "

  		if [[ $REPLY =~ ^[0-2]$ ]]; then
    	case $REPLY in
     	1)
           	dirPlexDir="/Volumes/Plex"
          	break
          	;;
      	2)
      	  	dirPlexDir="/mnt/x"
          	break
          	;;
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry."
    	sleep $DELAY
  	fi
	done

	echo ""
	echo ""
	echo "Plex Directory:  	$dirPlexDir"
	echo "-------------------------------------------------------------------------------"
	echo ""
	echo ""
	echo ""



while true; do
	cat << _EOF_




-------------------------------------------------------------------------------
NAS Media Set-up
-------------------------------------------------------------------------------

Please select one of the following:
===============================================================================

  1. /Volumes/Media
  2. /mnt/z
  0. Quit
	
===============================================================================

_EOF_

	  read -p "Enter selection [0-2] > "

  		if [[ $REPLY =~ ^[0-2]$ ]]; then
    	case $REPLY in
     	1)
           	dirMediaDir="/Volumes/Media"
          	break
          	;;
      	2)
      	  	dirMediaDir="/mnt/z"
          	break
          	;;
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry."
    	sleep $DELAY
  	fi
	done

	echo ""
	echo ""
	echo "NAS Media Directory:  	$dirMediaDir"
	echo "-------------------------------------------------------------------------------"
	echo ""
	echo ""
	echo ""



}


post_setup_checks_test() {

while true; do
	cat << _EOF_



*******************************************************************************
*                                                                             *
*                              TEST ENVIRONMENT                               *
*                                                                             *
*******************************************************************************



-------------------------------------------------------------------------------
Raw Original MKV Directory
-------------------------------------------------------------------------------

Please select one of the following:
===============================================================================

  1. /Volumes/4TB/Engine_Room-TEST/04_ReadyForTranscoding
  2. /mnt/e/Engine_Room/04_ReadyForTranscoding
  0. Quit
	
===============================================================================

_EOF_

	read -p "Enter selection [0-2] > "

  	if [[ $REPLY =~ ^[0-2]$ ]]; then
    	case $REPLY in
     	1)
           	dirReadyForTranscoding="/Volumes/4TB/Engine_Room-TEST/04_ReadyForTranscoding"
          	break
          	;;
      	2)
      	  	dirReadyForTranscoding="/mnt/e/Engine_Room/04_ReadyForTranscoding"
          	break
          	;;
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry."
    	sleep $DELAY
  	fi
	done

	echo ""
	echo ""
	echo "Original RAW Content Directory:  	$dirReadyForTranscoding"
	echo "-------------------------------------------------------------------------------"
	echo ""
	echo ""
	echo ""


while true; do
	cat << _EOF_




-------------------------------------------------------------------------------
Transcoded Output Directory Set-up
-------------------------------------------------------------------------------

Please select one of the following:
===============================================================================

  1. /Volumes/4TB/Engine_Room-TEST/05_Transcoded
  2. /home/parallels/Desktop/Engine_Room-TEST/05_Transcoded
  3. /mnt/d/05_Transcoded
  0. Quit
	
===============================================================================

_EOF_

	read -p "Enter selection [0-3] > "

  	if [[ $REPLY =~ ^[0-3]$ ]]; then
    	case $REPLY in
     	1)
           	dirTranscodedWorkDir="/Volumes/4TB/Engine_Room-TEST/05_Transcoded"
          	break
          	;;
      	2)
      	  	dirTranscodedWorkDir="/home/parallels/Desktop/Engine_Room-TEST/05_Transcoded"
          	break
          	;;
      	3)
      	  	dirTranscodedWorkDir="/mnt/d/05_Transcoded"
          	break
          	;;
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry."
    	sleep $DELAY
  	fi
	done

	echo ""
	echo ""
	echo "Transcoded Content Directory:  	$dirTranscodedWorkDir"
	echo "-------------------------------------------------------------------------------"
	echo ""
	echo ""
	echo ""



	# WSL NAS mounts for Plex and Media
	# sudo mkdir /mnt/x
	# sudo mkdir /mnt/z
	#
	# sudo mount -t drvfs X: /mnt/x
	# sudo mount -t drvfs Z: /mnt/z

while true; do
	cat << _EOF_




-------------------------------------------------------------------------------
Plex Location Set-up
-------------------------------------------------------------------------------

Please select one of the following:
===============================================================================

  1. /Volumes/4TB/Engine_Room-TEST/Pretend_Plex
  2. /mnt/e/Engine_Room/Pretend_Plex
  0. Quit
	
===============================================================================

_EOF_

	read -p "Enter selection [0-2] > "

  	if [[ $REPLY =~ ^[0-2]$ ]]; then
    	case $REPLY in
     	1)
           	dirPlexDir="/Volumes/4TB/Engine_Room-TEST/Pretend_Plex"
          	break
          	;;
      	2)
      	  	dirPlexDir="/mnt/e/Engine_Room/Pretend_Plex"
          	break
          	;;
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry."
    	sleep $DELAY
  	fi
	done

	echo ""
	echo ""
	echo "Plex Directory:  	$dirPlexDir"
	echo "-------------------------------------------------------------------------------"
	echo ""
	echo ""
	echo ""



while true; do
	cat << _EOF_




-------------------------------------------------------------------------------
NAS Media Set-up
-------------------------------------------------------------------------------

Please select one of the following:
===============================================================================

  1. /Volumes/4TB/Engine_Room-TEST/Pretend_Media
  2. /mnt/e/Engine_Room/Pretend_Media
  0. Quit
	
===============================================================================

_EOF_

  	read -p "Enter selection [0-2] > "

  	if [[ $REPLY =~ ^[0-2]$ ]]; then
    	case $REPLY in
     	1)
           	dirMediaDir="/Volumes/4TB/Engine_Room-TEST/Pretend_Media"
          	break
          	;;
      	2)
      	  	dirMediaDir="/mnt/e/Engine_Room/Pretend_Media"
          	break
          	;;
        0)
        	exit
        	;;	
    	esac
  	else
    	echo "Invalid entry."
    	sleep $DELAY
  	fi
	done

	echo ""
	echo ""
	echo "NAS Media Directory:  	$dirMediaDir"
	echo "-------------------------------------------------------------------------------"
	echo ""
	echo ""
	echo ""

}







##########################################################################
# POST-STEP01 - Create Folders                                           #
##########################################################################


create_folder_and_move() {

	echo "*******************************************************************************"
	echo "Starting Step 1 - creating the Plex folders for newly transcoded content" 
	echo ""
	echo ""




	IFS=$'\n'
	
	cd $dirTranscodedWorkDir
			
	for strP01FileName in `find . -type f -name "*.mkv" | sort` 
		do
		# Removes the leading ./ from the filename
		strP01FileName=${strP01FileName/\.\//}
		# Determine if it's a Movie or a TV show
		strTVRegEx="([sS]([0-9]{2,}|[X]{2,})[eE]([0-9]{2,}|[Y]{2,}))"
		
		if [[ "$strP01FileName" =~ $strTVRegEx ]]
		then
			# Determine the Show name
			strTVShowName=$( echo "$strP01FileName" | cut -d"-" -f1 | sed 's/.$//g' )

			# Determine the Season number
			#strTVShowSeasonNo=$( echo "$strP01FileName" | sed 's/.*\ -\ S//g' | cut -c1-2 | sed 's/^0*//g' )
			strTVShowSeasonNo=$( echo "$strP01FileName" | cut -d"-" -f2 | sed 's/.*\ S//g' | cut -c1-2 | sed 's/^0*//g' )

			if [ ! -d ${dirTranscodedWorkDir}/${strTVShowName} ]
			then
				mkdir ${dirTranscodedWorkDir}/${strTVShowName}
			fi
			
			strTVShowSeasonFolder="Season ${strTVShowSeasonNo}"			
			if [ ! -d ${dirTranscodedWorkDir}/${strTVShowName}/$strTVShowSeasonFolder ]
			then
				mkdir ${dirTranscodedWorkDir}/${strTVShowName}/${strTVShowSeasonFolder}

			fi
			
			mv -v -i $dirTranscodedWorkDir/$strP01FileName ${dirTranscodedWorkDir}/${strTVShowName}/${strTVShowSeasonFolder}/${strP01FileName}
			
		else	

			strP01File=$(basename $strP01FileName)		
			strRawName=$(echo $strP01File | sed 's/\.mkv//g')
			
			mkdir ${strRawName}
			mv -v -i $dirTranscodedWorkDir/$strP01FileName $dirTranscodedWorkDir/${strRawName}/${strP01FileName}
	  		
		    read line </dev/null
		fi 
		   
		done
		
	echo " "
	echo "Step 1 complete" 
	echo "*******************************************************************************"	
	echo ""
		
}



##########################################################################
# POST-STEP02 - Copy generated commands to Media                         #
##########################################################################


copy_commands_to_media() {

	echo "*******************************************************************************"
	echo "Starting Step 2 - Copy generated commands to Media" 
	echo ""
	echo ""


	IFS=$'\n'
	
	# Source Directory
	dirSourceCommands=$( echo $dirReadyForTranscoding | sed 's/\/04_ReadyForTranscoding/\/03_Outbox\/Commands/g' )

	# Destination Directories
	dirDestinationCommands="$dirMediaDir/Transcoding/Commands"
	dirDestinationOverrides="$dirMediaDir/Transcoding/Overrides"
	
	cd $dirSourceCommands

	for strP02FileName in `find . -type f -name "*.other-transcode.command.txt" | sed 's/\.\///g' | sort` 
		do
			if [ ! -f $dirDestinationCommands/$strP02FileName ]
			then
				if cp -v -i $dirSourceCommands/$strP02FileName $dirDestinationCommands/$strP02FileName
				then
					echo "Copy successful"
					rm -v $dirSourceCommands/$strP02FileName
				else
					echo "Copy failure, exit status $?"
					exit
				fi		
			else
				strTimestamp=$(date +%Y.%m.%d_%H%M%S)
				mv -v -i $dirDestinationCommands/$strP02FileName $dirDestinationCommands/${strTimestamp}-${strP02FileName}
				
				if cp -v -i $dirSourceCommands/$strP02FileName $dirDestinationCommands/$strP02FileName
				then
					echo "Copy successful"
					rm -v $dirSourceCommands/$strP02FileName
				else
					echo "Copy failure, exit status $?"
					exit
				fi
							
			fi	
	  		
		    read line </dev/null
		done


	for strP02FileName2 in `find . -type f -name "*.other-transcode.override.command.txt" | sed 's/\.\///g' | sort` 
		do
			if [ ! -f $dirDestinationOverrides/$strP02FileName2 ]
			then
				if cp -v -i $dirSourceCommands/$strP02FileName2 $dirDestinationOverrides/$strP02FileName2
				then
					echo "Copy successful"
					rm -v $dirSourceCommands/$strP02FileName2
				else
					echo "Copy failure, exit status $?"
					exit
				fi		
			else
				strTimestamp=$(date +%Y.%m.%d_%H%M%S)
				mv -v -i $dirDestinationOverrides/$strP02FileName2 $dirDestinationOverrides/${strTimestamp}-${strP02FileName2}
				
				if cp -v -i $dirSourceCommands/$strP02FileName2 $dirDestinationOverrides/$strP02FileName2
				then
					echo "Copy successful"
					rm -v $dirSourceCommands/$strP02FileName2
				else
					echo "Copy failure, exit status $?"
					exit
				fi
							
			fi	
	  		
		    read line </dev/null
		done





	if [ -f $dirSourceCommands/commands.bat ]
	then
		rm -v $dirSourceCommands/commands.bat
	fi



	echo " "
	echo "Step 2 complete" 
	echo "*******************************************************************************"	
	echo ""



}



##########################################################################
# POST-STEP03 - Copy generated summary folders to Media                  #
##########################################################################

copy_summaries_to_media() {

	echo "*******************************************************************************"
	echo "Starting Step 3 - Copy generated summary folders to Media" 
	echo ""
	echo ""

	IFS=$'\n'
	
	# Source Directory
	dirSourceSummaries=$( echo $dirReadyForTranscoding | sed 's/\/04_ReadyForTranscoding/\/03_Outbox\/Summaries/g' )
	
	# Destination Directory
	dirDestinationSummaries="$dirMediaDir/Transcoding/Summaries"
	
	cd $dirSourceSummaries
			
	for strP03DirName in `ls -d * | sort` 
#	for strP03DirName in `find . -type d -not -path '\.' | sed 's/\.\///g' | sort` 
	do
		if [ ! -d $dirDestinationSummaries/$strP03DirName ]
			then
				if cp -rv -i $dirSourceSummaries/$strP03DirName $dirDestinationSummaries/$strP03DirName
				then
					echo "Copy successful"
					rm -rv $dirSourceSummaries/$strP03DirName
				else
					echo "Copy failure, exit status $?"
					exit
				fi		
			else
				strTimestamp=$(date +%Y.%m.%d_%H%M%S)
				mv -v -i $dirDestinationSummaries/$strP03DirName $dirDestinationSummaries/${strTimestamp}-${strP03DirName}
				
				if cp -rv -i $dirSourceSummaries/$strP03DirName $dirDestinationSummaries/$strP03DirName
				then
					echo "Copy successful"
					rm -rv $dirSourceSummaries/$strP03DirName
				else
					echo "Copy failure, exit status $?"
					exit
				fi
							
			fi	
	  		
		    read line </dev/null
		done

	echo " "
	echo "Step 3 complete" 
	echo "*******************************************************************************"	


}



##########################################################################
# POST-STEP04 - Copy transcoded logs to NAS                               #
##########################################################################

copy_transcoded_log_to_media() {

	echo "*******************************************************************************"
	echo "Starting Step 4 - Copy transcoded logs to NAS" 
	echo ""
	echo ""

	IFS=$'\n'
	
	# Source Directory
	dirSourceTranscodedLog="$dirTranscodedWorkDir"
	
	# Destination Directory
	dirDestinationTranscodedLog="$dirMediaDir/Transcoding/Logs"
	
	cd $dirSourceTranscodedLog
			
	for strP04LogName in `find . -type f -name "*.mkv.log" | sort`
	do
		strP04LogName=${strP04LogName/\.\//}

		if [ ! -f $dirDestinationTranscodedLog/$strP04LogName ]
			then
				if cp -v -i $dirSourceTranscodedLog/$strP04LogName $dirDestinationTranscodedLog/$strP04LogName
				then
					echo "Copy successful"
					rm -rv $dirSourceTranscodedLog/$strP04LogName
				else
					echo "Copy failure, exit status $?"
					exit
				fi		
			else
				strTimestamp=$(date +%Y.%m.%d_%H%M%S)
				mv -v -i $dirDestinationTranscodedLog/$strP04LogName $dirDestinationTranscodedLog/${strTimestamp}-${strP04LogName}
				
				if cp -v -i $dirSourceTranscodedLog/$strP04LogName $dirDestinationTranscodedLog/$strP04LogName
				then
					echo "Copy successful"
					rm -v $dirSourceTranscodedLog/$strP04LogName
				else
					echo "Copy failure, exit status $?"
					exit
				fi
							
			fi	
	  		
		    read line </dev/null
		done

	echo " "
	echo "Step 4 complete" 
	echo "*******************************************************************************"	


}


##########################################################################
# POST-STEP05 - Copy transcoded content to Plex                          #
##########################################################################

copy_transcoded_content_to_plex() {

	echo "*******************************************************************************"
	echo "Starting Step 5 - Copy transcoded content to Plex" 
	echo ""
	echo ""

	IFS=$'\n'
	
	# Source Directory
	dirSourceTranscodedContent="$dirTranscodedWorkDir"
	
	# Destination Directory
	dirDestinationPlex="$dirPlexDir/_New"
	
	cd $dirSourceTranscodedContent

	echo "About to begin copying transcoded MKVs to the Plex folder on the NAS ..."
	echo "Command:"
	echo "cp -rv -i $dirSourceTranscodedContent/* $dirDestinationPlex"	
			
	if cp -rv -i $dirSourceTranscodedContent/* $dirDestinationPlex
	then
		echo "Copy successful"
		rm -rv $dirSourceTranscodedContent/*
		rm $dirDestinationPlex/commands.bat
	else
		echo "Copy failure, exit status $?"
		exit
	fi		


	echo " "
	echo "Step 5 complete" 
	echo "*******************************************************************************"	


}



##########################################################################
# POST-STEP06 - Copy raw MKV content to Media                            #
##########################################################################

copy_raw_content_to_media() {

	echo "*******************************************************************************"
	echo "Starting Step 6 - Copy raw MKV content to Media" 
	echo ""
	echo ""

	IFS=$'\n'
	
	# Source Directory
	dirSourceRawMKVContent="$dirReadyForTranscoding"
	
	# Destination Directory
	dirDestinationRawMKVContent="$dirMediaDir/_New"
	
	cd $dirSourceRawMKVContent
	
	echo "About to begin copying raw MKVs to the Media folder on the NAS ..."
	echo "Command:"
	echo "cp -v -i $dirSourceRawMKVContent/* $dirDestinationRawMKVContent/"	
		
	if cp -v -i $dirSourceRawMKVContent/* $dirDestinationRawMKVContent/
	then
		echo "Copy successful"
		rm -v $dirSourceRawMKVContent/*
	else
		echo "Copy failure, exit status $?"
		exit
	fi		


	echo " "
	echo "Step 6 complete" 
	echo "*******************************************************************************"	


}








##########################################################################
# POST RUN BOOK                                                          #
##########################################################################

post_runbook() {

	# -----------------------------------------------------------------
	#  Runbook
	# -----------------------------------------------------------------

	strStartDateTime=$(date "+%Y%m%d-%H%M%S")
	echo "Start time:   $strStartDateTime"
	echo ""

	# Step 1:  	Transcoded content folder creation
	create_folder_and_move

	# Step 2:  	Commands to Media
	copy_commands_to_media
	
	# Step 3:  	Summaries to Media
	copy_summaries_to_media

	# Step 4:  	Transcoded log file to Media
	copy_transcoded_log_to_media

	# Step 5:  	Transcoded content - copy to Plex
	copy_transcoded_content_to_plex

	# Step 6:  	Copy raw MKV content to Media
	copy_raw_content_to_media


	strEndDateTime=$(date "+%Y%m%d-%H%M%S")
	echo ""
	echo "End time:   $strEndDateTime"
	echo ""

	strMinutes=$(( $SECONDS / 60 ))
	strSeconds=$(( $SECONDS - ( $strMinutes*60 ) ))
	echo "Total time:   ${strMinutes} minutes, ${strSeconds} seconds."
	echo ""
}






##########################################################################
# SETUP                                                                  #
##########################################################################


IFS=$'\n'

while getopts r:e:d: option
do
        case "${option}"
        in
                r) strRunMode=${OPTARG};;
                e) strEnvMode=${OPTARG};;
                d) strDirModePath=${OPTARG};;
                \?) usage
                    exit 1;;
        esac
done


if [ "$strDirModePath" != "" ]
then
#	if [ ! -d $strDirModePath ]
#	then
#		echo "$strDirModePath"
#		echo "This path does not exist ... exiting"
#		exit
#	fi
	
	strBatchMode="On"
	echo ""
	echo ""
	echo "                    =========================================="
	echo "                    =                                        ="
	echo "                    =          BATCH MODE = ACTIVE           ="
	echo "                    =                                        ="
	echo "                    =========================================="
	echo ""

fi	
	

case $strEnvMode in
	live)	strEnv="live"
			shift
			;;
	test)	strEnv="test"
			shift
			;;
	*)		usage
			exit
			;;		
esac	

case $strRunMode in
	pre)	pre_setup_checks
			pre_runbook
			exit
			;;
	post)	post_setup_checks
			post_runbook
			exit
			;;
	batch)  pre_setup_checks
			batch_runbook
			;;		
	*)		usage
			exit
			;;		
esac					



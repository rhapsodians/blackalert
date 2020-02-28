#!/bin/bash

IFS=$'\n'
FILE=$1


echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "$FILE"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo ""

ffprobe -v error -show_entries stream=index,format,codec_name,channel_layout,channels,codec_type:stream_tags=language,title,BPS-eng,NUMBER_OF_FRAMES-eng:stream_disposition=forced,default -print_format json=compact=1 $FILE | jq -r '["TYPE","INDEX","LANGUAGE","CODEC","PROFILE","CHANNELS","CHANNEL LAYOUT","BITRATE","NO OF ELEMENTS","DEFAULT","FORCED FLAG","TITLE"], (.streams[] | select(.codec_type=="video" or .codec_type=="audio" or .codec_type=="subtitle") | [.codec_type, .index, .tags.language, .codec_name, .profile,.channels, .channel_layout, .tags."BPS-eng", .tags."NUMBER_OF_FRAMES-eng",.disposition.default, .disposition.forced, .tags.title ]) | @csv ' | sed 's/\"//g' | sed 's/,/ ,/g' | column -t -s ','


echo ""

#!/bin/bash

# Flags
createVideoFolderInRaw=1
vidFolderToRawFolder=1

# Folders
rawdir=/Volumes/GenuDrive/RY16_fix/
preVidDir=/media/ryoung/Thalamus/ry_GoalCoding_Project/RY16_experiment/videos/

if [[ -n $preVidDir ]] && [[ -d $preVidDir ]]
then
    linkDirList=()
    cnt=0;
    for file in $(ls  $preVidDir)
    do
        let cnt=$cnt+1
        file=$(basename $file)
        file=${file/.mp4/}
        vidstampFile=$(find $rawdir -name  "${file}*.videoTimeStamps")
        if [ -n $vidstampFile ]
        then
            where_to_link=$(dirname $vidstampFile) 2>/dev/null && \
            #while [ $where_to_link  = "*videoTimestamps*" ]
            #do
            #    echo recursing location
            #    where_to_link=$(dirname $where_to_link) 2>/dev/null && \
            #done
            if [  -n  $where_to_link  ];
            then
                linkDirList[$cnt]=$where_to_link
                echo ln -sf ${preVidDir}${file}.mp4 ${where_to_link}/${file}.mp4
                ln -sf ${preVidDir}${file}.mp4 ${where_to_link}/
            fi
        fi
    done
fi

if (( $((createVideoFolderInRaw)) == 1 ))
then
    rawdir=$(pwd)/..
    if [ ! -d videos ]
    then
        mkdir ${rawdir}/videos
    fi
    echo Symbolically linking videos to $rawdir/videos/
    videos=($(find . -name "*.mp4"))
    for video in $videos
    do
        ln -sf  $(realpath $video) ${rawdir}/videos/$(basename $video)
    done
fi

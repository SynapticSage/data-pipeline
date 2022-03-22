#!/bin/bash
#flags='-vf scale=646:482'
flags=''
curdir=$(pwd)
dir=${1:-$(pwd)}
shift
search_term=${@:-""}
echo $dir w/ $search_term

#echo dir = $dir, curdir = $curdir

pushd $dir  
#echo entered $dir

ffmpeg_files=$(ls *.h264 2> /dev/null) 
if [ ! -z $ffmpeg_files ]
then
    #echo Found ffmpeg files in $dir
    for file in $ffmpeg_files
    do
        if [ -e ${file/h264/mp4} ] # Is file already processed?
        then
            echo $file already processed
        else
            if [ -z $search_term ] # Standard, no filter terms
            then
                echo converting $file
                ffmpeg -i $file $flags ${file/h264/mp4}
            else # Filter terms!
                if [ ! -z $(echo $file | grep -e $search_term) ]
                then
                    echo converting $file
                    ffmpeg -i $file $flags ${file/h264/mp4}
                fi
            fi
        fi
    done
fi

for file in $(ls)
do
	if [ -d $file ] 
    then 
        #echo about to enter $file
        recurse_ffmpeg.sh $file $search_term;
    fi 
done

#echo exited $dir
popd

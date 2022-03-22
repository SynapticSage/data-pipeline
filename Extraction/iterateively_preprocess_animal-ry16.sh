#!/bin/zsh
# This  code  automates the process of loading data from a drive, to a faster
# drive, preprocessing it, and then sending results to a server and output
# drive
# 
# I wrote this out of necessity  because my jumbo data doesn't fit on a drive
# :(

# Flags
processDirCheck=1 # Check whether a day has been processed by whether the
                  # dayDir is in the processDir
moveResults=0     # Whethere to move results  to resultsDir

# Raw data
#=================================
rawDir=/Volumes/Calyx/RY16_fix/
daydirs=($(find $rawDir -maxdepth 1 -mindepth 1 -type d )) # Get list of all day directories
daydirs=(${daydirs[@]##*/}) # Grab the terminal folder names
echo dayDirs: 
echo "<==========================================================>"
echo "<==========================================================>"
let cnt=0
for daydir in $daydirs[@]
do
    let cnt=cnt+1
    echo "$((cnt)) --> $daydir"
done
echo "<==========================================================>"
echo "<==========================================================>"

# Fast File System (SSD) for proessing
#=================================
processDir=/Volumes/FastData/ry_GoalCoding_Project/RY16_experiment/RY16_fix/

# Where to place resultant data
#=================================
resultDir=/Volumes/GenuDrive/RY16_fix/
# Where to place resultant data
#=================================
serverDir=citadel:/volume1/data/Projects/ry_GoalCoding_Project/RY16_experiment/RY16_fix/

echo 
echo

#  _____ _                  _                                   
# |_   _(_)_ __ ___   ___  | |_ ___    _ __ ___   _____   _____ 
#   | | | | '_ ` _ \ / _ \ | __/ _ \  | '_ ` _ \ / _ \ \ / / _ \
#   | | | | | | | | |  __/ | || (_) | | | | | | | (_) \ V /  __/
#   |_| |_|_| |_| |_|\___|  \__\___/  |_| |_| |_|\___/ \_/ \___|

for index in {$((${#daydirs[@]}))..1}
do
    if (( $((index)) < 33 ))
    then
        echo Stopping result movement into GENU
        moveResults = 0;
    fi

    if (( $processDirCheck ==  1 ))
    then
        if [ ! -d  ${processDir}${daydirs[$(($index))]} ]
        then
            echo ${daydirs[$(($index))]} does not  exist in processDir .. assuming finished
            continue
        else
            echo  Proceeding to process ${daydirs[$((index))]}
            echo  "============================================"
            echo
        fi
    fi
    
    echo INDEX = $index

    # MEAT AND POTATOES
    # =================
    sessionId=${daydirs[$((index))]%%_*}
    substr='s/???/'"${sessionId}"'_/'
    echo $substr > ./substr.txt
    echo Substr = $substr
    echo STARTING TO SHIFT ${daydirs[$((index))]} to processDir=${processDir}
    echo --------------------------------------------------------------------
    rsync --prune-empty-dirs -avuL --exclude "*.h264" $rawDir${daydirs[$((index))]} ${processDir} && \ 
    echo SUCCESS: ${daydirs[$((index))]} in $rawDir && \
    cp ~/Code/pipeline/extraction/extraction_RY16 ~/Code/pipeline/extraction/extraction_RY16_single.m && \
    sed --in-place $(cat substr.txt) ~/Code/pipeline/extraction/extraction_RY16_single.m  &&\
    echo SUCCESS: extraction file created && \
    sleep 10 && \
    matlab -nodesktop -nodisplay -r "addpath('~/Code/pipeline/extraction'); extraction_RY16_single; exit" -logfile "currentExtraction.log"

    echo "...Finished moving and matlab extraction"
    echo ""
    echo "MOVING EXTRACTION OUTPUTS TO SERVER (and then removing extracts)"
    echo "-----------------------------------------------------------------"

    # Move etracted data to server
    rsync -avu --exclude "*.rec" --exclude "*.mp4" --exclude "*.h264" ${rawDir}${daydirs[$((index))]} ${serverdir} && \
    rsync -avu --exclude "*.rec" --exclude "*.mp4" --exclude "*.h264" ${processDir}${daydirs[$((index))]} ${serverDir} && \
    rm -rf ${processDir}${daydirs[$((index))]}
    echo ""

    if [ -d ${processDir}${daydirs[$((index))]} ]
    then
        echo ERROR: process data folder not removed after extraction ... exiting
        return 1
    fi

    if (( $moveResults ==  1  ))
    then
        # Move data in background from server to result directory
        echo MOVING EXTRACTION OUTPUTS from sever to resultDir in background!
        echo -----------------------------------------------------------------
        rsync -avu --exclude "*.rec" --exclude "*.mp4" --exclude "*.h264" ${serverDir}${daydirs[$((index))]} ${resultDir} & # BACKGROUND PROCESS
    fi
done

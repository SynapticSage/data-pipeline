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
moveResults=1     # Whethere to move results  to resultsDir

# Where to place resultant data
#=================================
resultDir=/Volumes/Cerebellum/RY9/
# Raw data
#=================================
rawDir=citadel:/volume1/data/Projects/ry_GoalCoding_Project/RY9_experiment/RY9/
daydirs=($(find $resultDir -maxdepth 1 -mindepth 1 -type d | grep _ | sort)) # Get list of all day directories
daydirs=(${daydirs[@]##*/}) # Grab the terminal folder namese
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
processDir=/Volumes/FastData/ry_GoalCoding_Project/RY9_experiment/RY9/

# Where to place resultant data
#=================================
serverDir=citadel:/volume1/data/Projects/ry_GoalCoding_Project/RY9_experiment/RY9/

if (( ${#daydirs} < 1 ));
then
    echo  No directories found!
    return 2
else
    echo proceeding
fi
sleep 2

echo 
echo
#  _____ _                  _                                   
# |_   _(_)_ __ ___   ___  | |_ ___    _ __ ___   _____   _____ 
#   | | | | '_ ` _ \ / _ \ | __/ _ \  | '_ ` _ \ / _ \ \ / / _ \
#   | | | | | | | | |  __/ | || (_) | | | | | | | (_) \ V /  __/
#   |_| |_|_| |_| |_|\___|  \__\___/  |_| |_| |_|\___/ \_/ \___|

#for index in {$((${#daydirs[@]}-2))..1}
for index in {$((${#daydirs[@]}))..1}
do

    if (( $processDirCheck ==  1 ))
    then
        if [ ! -d  ${processDir}/${daydirs[$(($index))]} ]
        then
            echo ${daydirs[$(($index))]} does not  exist in processDir=$processDir .. assuming finished
            continue
        else
            echo  Proceeding to process ${daydirs[$((index))]}
            echo  "============================================"
            echo
        fi
    fi
    
    echo INDEX = $index, DAYDIR = ${daydirs[$((index))]}

    # MEAT AND POTATOES
    # =================
    sessionId=${daydirs[$((index))]%%_*}
    substr='s/???/'"${sessionId}"'_/'
    echo $substr > ./substr.txt
    echo Substr = $substr
    echo STARTING TO SHIFT ${daydirs[$((index))]} to processDir=${processDir}
    echo "--------------------------------------------------------------------"
    rsync --exclude "*.dat" --exclude "*.mda" --prune-empty-dirs -avuL $rawDir${daydirs[$((index))]} ${processDir} && \ 
    echo "SUCCESS: ${daydirs[$((index))]} in $rawDir" && \
    cp ~/Code/pipeline/extraction/extraction_RY9 ~/Code/pipeline/extraction/extraction_RY9.m && \
    sed --in-place $(cat substr.txt) ~/Code/pipeline/extraction/extraction_RY9.m  &&\
    echo "SUCCESS: extraction file created" && \
    sleep 10 && \
    matlab -nodesktop -nodisplay -r "addpath('~/Code/pipeline/extraction'); extraction_RY9; exit" -logfile "currentExtraction.log"

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
        echo "MOVING EXTRACTION OUTPUTS from sever to resultDir in background!"
        echo "-----------------------------------------------------------------"
        rsync -avu --prune-empty-dirs --exclude "*.rec" --exclude "*.mp4" --exclude "*.h264" ${serverDir}${daydirs[$((index))]} ${resultDir} & # BACKGROUND PROCESS
    fi
done

#!/usr/bin/env bash

dir=${1:-$(pwd)}
mode=${2:-"all"} # options {all|complete|incomplete}


# Array of all logfiles
echo Starting log search
logfiles=($(find $dir -name "*.log" | grep -e mda -e raw -e dio -e spikes | sort)
echo ${logfiles[@]}

# Okay, so now we need to actually do something with that

# Print every files status
for $file in #{logfiles[@]}
do
    # Get last line  of the log  file
    lastLine=$(cat $file | tail -n 1)

    # Determine if the proceesing is finisedh
    if [ $lastLine ~= '*DONE*' ]
    then
        case $mode in
            all) 
                echo "DONE => $file" 
                ;;
            complete) 
                echo $file 
                ;;
            incomlete") 
                ;;
            *) echo mode is not recognized;;
        esac
    else
        case $mode in
            "all") echo X => $file;;
            "complete") ;;
            "incomlete") echo $file ;;
            *) echo mode is not recognized;;
        esac
    fi
done

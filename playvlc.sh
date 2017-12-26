#!/usr/bin/env bash

LOGFILE=/tmp/playvlc.log

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-h] [-v] [-m] [-r - | REPEAT_COUNT] VIDEOFILE [ - | START_TIME ] [END_TIME]

Plays video by single VLC with specified timeframe in seconds. By default this script closes all other VLC instances.
Time format: SS or MM:SS or HH:MM:SS. Where SS - number of seconds, MM - number of minutes, HH - number of hours.

    -h               Display this help and exit
    -v               Verbose mode. Prints log to ${LOGFILE} file.
    -m               Allow multiple VLC instances and do not close other ones before playing video.
    -r REPEAT_COUNT  Repeat selected video for REPEAT_COUNT times. For infinite repeat use "-" as REPEAT_COUNT.
    VIDEOFILE        Required. Video to be played.
    START_TIME       See time format above to specify playback start. Use "-" if you want to omit this parameter and specify end_time only.
    END_TIME         Optional. If Empty, video will be played to the end.

EXAMPLES:
To play the whole video, use the VIDEOFILE parameter only:
   playvlc video.mp4

To play video.mp4 from the 2nd minute and 12th second to the end if file. Just omit END_TIME parameter:
   playvlc video.mp4 2:12

To play video.mp4 from the beginning to 1st hour, 20th minute and 15th second, you can use "-" as START_TIME parameter:
   playvlc video.mp4 - 1:20:15

To play video.mp4 from 25th to 120th second and repeat it 3 times:
   playvlc -r 3 video.mp4 25 120

To see log file updates:
   tail -f ${LOGFILE}
EOF
}

YES="yes"
NO="no"

verbose_mode=$NO
allow_multiple_instances=$NO
repeat_count=""
OPTIND=1

while getopts "hvmr:" opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        v)
            verbose_mode=$YES
            ;;
        m)
            allow_multiple_instances=$YES
            ;;
        r)
            repeat_count=$OPTARG
            ;;
        *)
            show_help >&2
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

VIDEOFILE=$1
start_time=$2
end_time=$3


if [[ ! $repeat_count =~ ^[1-9][0-9]*$ ]] && [[ ! $repeat_count == "-" ]] && [[ -n "$repeat_count" ]]; then
    printf "REPEAT_COUNT not recognized. Use either a positive number or '-' for endless repeat. But entered: ${repeat_count}\n\n"
    show_help >&2
    exit 1
fi

if [ ! -f $VIDEOFILE ]; then
    printf "Video file not found here: ${VIDEOFILE} \n\n"
    show_help >&2
    exit 1
fi

if [[ ! $start_time =~ ^[0-9]+$ ]] && [[ ! $start_time =~ ^[0-9]+\:[0-9]+$ ]] && [[ ! $start_time =~ ^[0-9]+\:[0-9]+\:[0-9]+$ ]] && [[ ! "$start_time" == "-" ]] && [[ -n "$start_time" ]]; then
    printf "START_TIME should be either empty or '-' or SS or MM:SS or HH:MM:SS format. But entered: ${start_time}\n\n"
    show_help >&2
    exit 1
fi

if [[ ! $end_time =~ ^[0-9]+$ ]] && [[ ! $end_time =~ ^[0-9]+\:[0-9]+$ ]] && [[ ! $end_time =~ ^[0-9]+\:[0-9]+\:[0-9]+$ ]] && [[ -n "$end_time" ]]; then
    printf "END_TIME should be either empty or SS or MM:SS or HH:MM:SS format. But entered: ${end_time} \n\n"
    show_help >&2
    exit 1
fi

tolog() {
    if [[ $verbose_mode == $YES ]]; then
        echo ${1}
        echo "$(date +%D%t%T) | start=${start_time} stop=${end_time} | ${1}" >> $LOGFILE
    fi
}

calc_seconds ()
{
    input=$1
    if [ -z "$input" ]; then
        input=0
    fi
    colons=0
    echo "$input" | grep '^[0-9]*\:[0-9]*$' > /dev/null
    if [ $? == 0 ]; then
        colons=1
    fi
    echo "$input" | grep '^[0-9]*\:[0-9]*\:[0-9]*$' > /dev/null
    if [ $? == 0 ]; then
        colons=2
    fi
    hours=0
    minutes=0
    seconds=0
    if [ $colons == 0 ]; then
        seconds=`echo -n "$input" | sed 's/^0*//'`
    else
        awk_string=`echo -n "$input" | sed 's/:/ /g'`
    fi
    if [ $colons == 1 ]; then
        minutes=`echo -n "$awk_string" | awk '{print $1}' | sed 's/^0*//'`
        seconds=`echo -n "$awk_string" | awk '{print $2}' | sed 's/^0*//'`
        seconds=$((seconds + minutes*60))
    fi
    if [ $colons == 2 ]; then
        hours=`echo -n "$awk_string" | awk '{print $1}' | sed 's/^0*//'`
        minutes=`echo -n "$awk_string" | awk '{print $2}' | sed 's/^0*//'`
        seconds=`echo -n "$awk_string" | awk '{print $3}' | sed 's/^0*//'`
        seconds=$((seconds + minutes*60 + hours*3600))
    fi
    echo $seconds
}

setup_play_timeframe ()
{
    if [[ "$start_time" == "-" ]] || [[ -z "$start_time" ]]; then
        start_seconds=0
    else
        start_seconds=`calc_seconds $start_time`
    fi

    if [[ -n "$end_time" ]]; then
        end_seconds=`calc_seconds $end_time`
    else
        end_seconds=""
    fi
}

stop_all_vlc() {
    if [[ ! $allow_multiple_instances == $YES ]]; then
        for pid in $(ps -ef | grep "vlc\|VLC" | grep -v $$ | grep -v "playvlc.log" | grep -v "vim" | awk '{print $2}'); do kill -9 $pid 2>/dev/null; done
    fi
}

get_vlc_command() {
    if [ "$(uname)" == "Darwin" ]; then
        # Do something under Mac OS X platform
        echo "/Applications/VLC.app/Contents/MacOS/VLC"
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        # Do something under GNU/Linux platform
        echo "vlc"
    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
        # Do something under 32 bits Windows NT platform
        echo "vlc"
    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
        # Do something under 64 bits Windows NT platform
        echo "vlc"
    fi
}

set_vlc_params() {
    if [[ -z "${start_seconds}" ]] && [[ -z "${end_seconds}" ]]; then
        logstring="play all ${VIDEOFILE}"

    elif [[ "$start_seconds" == "-" ]] && [[ -n "$end_seconds" ]]; then
        logstring="play from beginning to ${end_seconds} seconds. File: ${VIDEOFILE}"
        VLC_PARAMS="--stop-time ${end_seconds}"

    elif [[ -n "${start_seconds}" ]] && [[ -z "${end_seconds}" ]]; then
        logstring="play from ${start_seconds} seconds. File: ${VIDEOFILE}"
        VLC_PARAMS="--start-time=${start_seconds}"

    elif [[ -n "${start_seconds}" ]] && [[ -n "${end_seconds}" ]]; then
        logstring="play from ${start_seconds} to ${end_seconds} seconds. File: ${VIDEOFILE}"
        VLC_PARAMS="--start-time=${start_seconds} --stop-time=${end_seconds}"
    else
        tolog "Matched nothing.. start seconds:${start_seconds} stop seconds:${end_seconds}"
        exit 1;
    fi

    if [[ "$repeat_count" == "-" ]]; then
        logstring="$logstring | infinite play loop"
        VLC_PARAMS="$VLC_PARAMS --repeat"

    elif [[ -n "$repeat_count" ]]; then
        logstring="$logstring | repeat $repeat_count times"
        VLC_PARAMS="$VLC_PARAMS --input-repeat $((repeat_count - 1))"

    else
        logstring="$logstring | no repeat"
        VLC_PARAMS="$VLC_PARAMS --no-repeat"
    fi
}

setup_play_timeframe
set_vlc_params
stop_all_vlc
tolog "${logstring}"

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

`get_vlc_command` --fullscreen --playlist-autostart --play-and-exit --no-loop $VLC_PARAMS $VIDEOFILE &

IFS=$SAVEIFS


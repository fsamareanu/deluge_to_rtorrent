#!/bin/bash

#See where we are on disk since we want to source functions and settings relatively to the actual file location
#We also set confdir here

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
	DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
	SOURCE="$(readlink "$SOURCE")"
	[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

#Import functions and settings and make sure they're exported to subshells
set -a
source "$DIR"/conf/settings.sh
source "$DIR"/functions/functions.sh
confdir="$DIR"/conf
set +a

parent="$(cat /proc/$PPID/comm)"

if [ -z "$1" ]
	then
		logfile=generic.log
	else
		logfile="${1}".log
fi

#Run the actual script
run_deluge_to_rtorrent_script() {
	"$DIR"/bin/deluge_to_rtorrent.sh "${@}"
}

run_deluge_to_rtorrent_script_verb() {
	"$DIR"/bin/deluge_to_rtorrent.sh "${@}"
}

if [[ "${parent}" == deluged ]]; then
	run_deluge_to_rtorrent_script "${@}" >>"${logdir}"/"${logfile}" 2>&1
else
	echo "We seem to be running from a terminal so mandatory waits are being bypassed"
	echo "Debug information can be found in ${logdir}/${logfile}"
	export SKIP_SLEEP=1
	export from_shell=1
	run_deluge_to_rtorrent_script "${@}" 2> "${logdir}"/"${logfile}"
fi

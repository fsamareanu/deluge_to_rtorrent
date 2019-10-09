#!/bin/bash

if [ "${BASH_SOURCE[0]}" -ef "$0" ]
then
    echo "Hey, you should source this script, not execute it!"
    return 10
fi

#Error handling here
set -e
#Define a "trap" function that prettifies and shows any possible typos
err() {
	echo "An error has occured at $LINENO:"
	awk 'NR>L-2 && NR<L+2 { printf "%-5d%7s%s\n",NR,(NR==L?"HERE>>>":""),$0 }' L="$1" "$0"
}

check_config_variables() {
always_mandatory_array=(
home
bindir
chtor_bin
dc_local_bin
dc_local_host
dc_local_username
dc_local_password
dc_remote_enable
deluge_state_dir
enable_external_command_timeout
label_not_found_string
logdir
deluge_queue_num_torrents_max
deluge_queue_step_sleep
r_step_sleep
step_sleep
rtxmlrpc_bin
rtxmlrpc_socket
min_ratio_move_local
run_count
run_count_max
repair_run_count
repair_run_count_max
torrentid
)

when_remote_enabled_mandatory_array=(
dc_remote_bin
dc_remote_host
dc_remote_username
dc_remote_password
min_ratio_move_remote
)

not_mandatory_array=(

deluge_queue_run_count
deluge_queue_run_count_max
long_term_seed_label_suffix
short_term_seed_label_suffix
torrentname_in
torrentpath_in
)

for i in "${always_mandatory_array[@]}";
        do
                check_null_parameter "$i";
        done

if [[ "$dc_remote_enable" = "1" ]]; then
        for j in "${when_remote_enabled_mandatory_array[@]}";
                do
                        check_null_parameter "$j";
                done
fi

validate_file_folder "$home"
validate_file_folder "$bindir"
validate_file_folder "$chtor_bin"
validate_file_folder "$dc_local_bin"
validate_file_folder "$deluge_state_dir"
validate_file_folder "$rtxmlrpc_bin"
}

#Create a sleep function to use further
sleep_func() {
	if [[ -z "${SKIP_SLEEP+x}" ]];then
		echo "Sleeping for $step_sleep seconds"
		sleep "$step_sleep"
		run_count=$(( run_count + 1 ))
	else
		echo "SKIP_SLEEP bypass detected, not sleeping"
	fi
}

sleep_func_p() {
	if [[ -z "${SKIP_SLEEP+x}" ]];then
		echo "Sleeping for ${!1} seconds"
		sleep "${!1}"
		eval "$2"=$(( "${!2}" + 1 ))
	else
		echo "SKIP_SLEEP bypass detected, not sleeping"
	fi
}

#Check if remote operations are enabled. If not, set variables to known ones
check_remote_enabled() {
	if [[ "$dc_remote_enable" = "0" ]]; then
		dc_remote_bin=$dc_local_bin
		dc_remote_host=$dc_local_host
		dc_remote_username=$dc_local_username
		dc_remote_password=$dc_local_password
	else
		echo "Remote operations enabled"
	fi
}

check_timeout_enabled() {
	substitute_if_null "$enable_external_command_timeout" 0
	enable_external_command_timeout="$substvar"
	substitute_if_null "$external_command_timeout" 60
	external_command_timeout="$substvar"
	if [[ ("${enable_external_command_timeout}" = "1") ]];then
		echo "Command timeout enabled"
		dc_local_bin="timeout --signal=KILL $external_command_timeout ${dc_local_bin}"
		dc_remote_bin="timeout --signal=KILL $external_command_timeout ${dc_remote_bin}"
		rtxmlrpc_bin="timeout --signal=KILL $external_command_timeout ${rtxmlrpc_bin}"
	else
		echo "Command timeout not set or not enabled"
	fi
}

#This function gets the deluge version and sets variables based on it
get_deluge_version() {
	if [ -z "$1" ];then
		substitute_if_null "$deluge_ver" 1
		deluge_ver="${substvar}"
	else
		deluge_ver=$($1 -v|grep console|awk -F'[^0-9]*' '$0=$2')
	fi
}

#Validating input/getting the additional required values from deluge#

#Check input parameters are correct#
check_null_parameter() {
        if [ -z "${!1}" ];then
                echo "Variable $1 is null, exiting"
                return 10
        else
		true
        fi
}

#Define a helper function to subtitute a value with another if first argument is null
substitute_if_null() {
        unset substvar
        if [ -z "$1" ]; then
                substvar=$2
        else
                substvar=$1
        fi
}

substitute_if_null_p() {
	if [ -z "${!1}" ]; then
		eval "$1"="${!2}"
	else
		true
	fi
}

#Do a sanity check on the input, make sure only alphanumeric input was provided#
check_torrentid_correct() {
	if [[ "$torrentid" =~ [^a-zA-Z0-9] ]];then
		echo "Torrent id ${1} contains invalid characters. Make sure torrent ID only contains letters and numbers."
		return 10
	else
		true
	fi
}

#Do a basic check on the URLs so they match a specific pattern
check_url() {
	url_regex="^(http:\/\/www\.|https:\/\/www\.|http:\/\/|https:\/\/)?[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$"
	if [[ ("${1}" =~ ${url_regex} || -z "${1}") ]];then
		true
	else
		echo "$1" is invalid. Enter a valid URL or leave blank.
		return 10
	fi
}

#Retrieve torrent name and check that torrent name is not blank#
get_torrent_name() {
	torrentname=$($dc_local_bin "connect $dc_local_host $dc_local_username $dc_local_password; info -v $torrentid"| grep "^Name: " | awk -F':[[:blank:]]*' '{print $2}')
	substitute_if_null_p torrentname torrentname_in
	check_null_parameter torrentname
}

#Retrieve torrent path and make sure it is not blank#
get_torrent_path() {
	torrentpath="$($dc_local_bin "connect $dc_local_host $dc_local_username $dc_local_password; info -v $torrentid"| grep "^Download Folder: " | awk -F':[[:blank:]]*' '{print $2}')"
	substitute_if_null_p torrentpath torrentpath_in
	check_null_parameter torrentpath
	validate_file_folder "$torrentpath/$torrentname"
}

#Check if file or folder exists#
validate_file_folder() {
	if [ -d "$1" ];then
		true
	elif [ -f "$1" ];then
		true
	else
		echo "File or folder $1 doesn't exist, bailing out"
		return 10
	fi
}

#Generate random string for further use
generate_random() {
	unset randomstring
	randomstring=$(tr -dc A-Za-z0-9 < /dev/urandom | dd bs=20 count=1 2>/dev/null)
}

#Define function to calculate different ratios that are used further in the script#
calculate_ratio() {
	localratio_raw=$($dc_local_bin "connect $dc_local_host $dc_local_username $dc_local_password; info -v $torrentid" | grep Ratio: | awk -F "Ratio: " '{print $2}')
	check_null_parameter localratio_raw
	remoteratio_raw=$($dc_remote_bin "connect $dc_remote_host $dc_remote_username $dc_remote_password; info -v $torrentid" | grep Ratio: | awk -F "Ratio: " '{print $2}')
	substitute_if_null "$remoteratio_raw" 0
	remoteratio_raw=$substvar
	localratio=$(echo "$localratio_raw" | awk '{print int($0)}')
	remoteratio=$(echo "$remoteratio_raw" | awk '{print int($0)}')
	averageratio_raw=$(echo "$localratio_raw" "$remoteratio_raw" | awk '{ for(i=1; i<=NF;i++) j+=$i; print j / 2; j=0 }')
	if [[ ("$dc_remote_enable" == "1") ]];then
		sumratio_raw=$(echo "$localratio_raw" "$remoteratio_raw" | awk '{ for(i=1; i<=NF;i++) j+=$i; print j ; j=0 }')
	else
		sumratio_raw=$(echo "$localratio_raw" "$remoteratio_raw" | awk '{ for(i=1; i<=NF;i++) j+=$i; print j /2; j=0 }')
	fi
}

deluge_ratio_to_send() {
	per_tracker_deluge_ratio=$(grep "^$configured_tracker_url_prefix"_deluge_ratio= "$confdir"/settings.sh|grep -v "#"|awk -F"=" '{print $2}')
	substitute_if_null "$per_tracker_deluge_ratio" localratio
	per_tracker_deluge_ratio=$substvar
	case "$per_tracker_deluge_ratio" in
		localratio)
			deluge_ratio="$localratio_raw"
			;;
		remoteratio)
			deluge_ratio="$remoteratio_raw"
			;;
		avgratio)
			deluge_ratio="$averageratio_raw"
			;;
		sumratio)
			deluge_ratio="$sumratio_raw"
			;;
		*)
			echo "Invalid config parameter for \$trackerX_deluge_ratio, asuming localratio"
			deluge_ratio="$localratio_raw"
			;;
	esac
}

#Checking the number of active torrents in deluge that are Active, Downloading or Seeding
check_num_torrents_active() {
	num_torrents_active=$($dc_local_bin "connect $dc_local_host $dc_local_username $dc_local_password;info"|egrep "\[C\]|\[S\]"|wc -l)
	if [ -z "$num_torrents_active" ];then
		num_torrents_active=0
	else
		true
fi
}

#Define the function that cleans up the temporary directory#
remove_tmpdir() {
	sleep 20
	/bin/rmdir "${tmpdir}"
}

#Mapping tracker to a code for further use. Mapping the tracker variable to an internal code#
set_tracker() {
	tracker_line=$($dc_local_bin "connect $dc_local_host $dc_local_username $dc_local_password; info -v $torrentid" | grep "^Tracker"| awk -F: '{print $2}' | tr -d " "| egrep -iv 'announce|unregis|error'| awk 'FNR <= 1')
	substitute_if_null "$tracker_line" default
	tracker_line="$substvar"
	configured_tracker_url_prefix=$(grep "^tracker[0-99]_url_contains=" "$confdir"/settings.sh|grep "$tracker_line"|grep -v "#"|awk -F_ '{print $1}')
	substitute_if_null "$configured_tracker_url_prefix" default
	configured_tracker_url_prefix="$substvar"
	configured_tracker_url_label=$(grep "^$configured_tracker_url_prefix"_code= "$confdir"/settings.sh|grep -v "#"|awk -F"=" '{print $2}')
	substitute_if_null "$configured_tracker_url_label" default
	tracker="$substvar"
}

#Setting chtor options depending on whether reannounce is defined or not#
set_chtor_opts() {
	chtor_reannounce_url=$(grep "$configured_tracker_url_prefix"_reannounce_url= "$confdir"/settings.sh |awk -F= '{print $2}'|grep -v "#")
        check_url "${chtor_reannounce_url}"
	if [ -z "$chtor_reannounce_url" ];then
		chtor_opts="--bump-date --quiet --fast-resume=${torrentpath}/{} -o ${tmpdir}/ ${deluge_state_dir}/${torrentid}.torrent"
	else
		chtor_opts="-a ${chtor_reannounce_url} --bump-date --quiet --fast-resume=${torrentpath}/{} -o ${tmpdir}/ ${deluge_state_dir}/${torrentid}.torrent"
	fi
}

#Run chtor and create a backup
run_chtor() {
	$chtor_bin ${chtor_opts}
	/bin/mv -f "${tmpdir}"/"${torrentid}"-no-resume.torrent "${logdir}"/orig-torrents/"${torrentid}"-orig.torrent
}

#Creating required directories#
create_directories() {
	mkdir -p "${logdir}"/orig-torrents
	tmpdir=$(mktemp -d -t deluge-to-rt-XXXXXXXXXX)
}

#Map folder to a label#
set_label() {
	while IFS= read -r line
		do
			t_configured_path=$(echo "$line"|awk -F'|' '{print $1}')
			validate_file_folder "$t_configured_path"
			t_configured_label=$(echo "$line"|awk -F'|' '{print $2}')
			if [[ ($(realpath -s "$torrentpath") == $(realpath -s "$t_configured_path")) ]];then
				t_folder_label="$t_configured_label"
				break
			fi
		done < <(grep "^path[1-99]" "$confdir"/settings.sh | awk -F'"' '{print $2}')

	substitute_if_null_p t_folder_label label_not_found_string
	t_folder_label="$tracker""_""$t_folder_label"
}

#We define a queue less or equal to $deluge_queue_num_torrents_max in deluge
maintain_deluge_queue() {
	substitute_if_null_p deluge_queue_skip_tracker_codes randomstring
	substitute_if_null "$deluge_queue_run_count" "1"
	deluge_queue_run_count="$substvar"
	substitute_if_null "$deluge_queue_run_count_max" "48"
	deluge_queue_run_count_max="$substvar"
        while [[ ("$num_torrents_active" -le "$deluge_queue_num_torrents_max" && "${deluge_queue_run_count}" -le "${deluge_queue_run_count_max}" && -z "${SKIP_SLEEP+x}" && ! "$deluge_queue_skip_tracker_codes" =~ $tracker ) ]]
		do
			echo "Number of torrents active ($num_torrents_active) in deluge is less than or equal to $deluge_queue_num_torrents_max"
			echo "Iteration sequence is $deluge_queue_run_count/$deluge_queue_run_count_max"
			sleep_func_p deluge_queue_step_sleep deluge_queue_run_count
	        	check_num_torrents_active
		done
}

#Define the function that removes the torrent from deluge. Options for remove are different between deluge 1.x and deluge 2.x so we deal with it here
remove_from_deluge() {
	get_deluge_version "$dc_local_bin"
	if [[ "$deluge_ver" == "1" ]];then
		dc_local_bin_rm_opts="rm $torrentid"
	else
		dc_local_bin_rm_opts="rm -c $torrentid"
	fi
	get_deluge_version "$dc_remote_bin"
	if [[ ("$deluge_ver" == "1" && "$dc_remote_enable" == "1") ]];then
		dc_remote_bin_rm_opts="rm --remove_data $torrentid"
	elif [[ ("$deluge_ver" == "2" && "$dc_remote_enable" == "1") ]];then
		dc_remote_bin_rm_opts="rm -c --remove_data $torrentid"
	else
		dc_remote_bin_rm_opts="exit"
	fi
	$dc_remote_bin "connect $dc_remote_host $dc_remote_username $dc_remote_password; $dc_remote_bin_rm_opts"
	$dc_local_bin "connect $dc_local_host $dc_local_username $dc_local_password; $dc_local_bin_rm_opts"
}

#Define the function that adds the torrent to rtorrent
add_to_rtorrent() {
	$rtxmlrpc_bin -Dscgi_url="$rtxmlrpc_socket" -q load.start '' "${tmpdir}/${torrentid}.torrent" "d.directory.set=\"$torrentpath\"" "d.custom1.set=\"$rlabel\"" "d.delete_tied="
	sleep 20
	$rtxmlrpc_bin -Dscgi_url="$rtxmlrpc_socket" -q d.custom.set "${torrentid}" deluge_ratio "${deluge_ratio}"
}

#Define the function that checks the status in rtorrent and tries to stop and hash check it
check_rtorrent_details() {
	rtorrent_torrentdir=$($rtxmlrpc_bin -Dscgi_url="$rtxmlrpc_socket" d.get_base_path "$torrentid")
	rtorrent_state=$($rtxmlrpc_bin -Dscgi_url="$rtxmlrpc_socket" d.state "$torrentid")
	substitute_if_null "$rtorrent_state" 0
	rtorrent_state="$substvar"
	substitute_if_null_p rtorrent_torrentdir tmpdir
		if [[ $(realpath -s "$rtorrent_torrentdir") = $(realpath -s "$torrentpath/$torrentname") && "$rtorrent_state" = "1" ]];then
			$rtxmlrpc_bin -Dscgi_url="$rtxmlrpc_socket" -q d.save_full_session "$torrentid"
		        echo "Torrent moved successfully"
		else
			echo "An error has occured"
			echo "\$rtorrent_torrentdir is $rtorrent_torrentdir"
			echo "Actual torrent dir is $torrentpath/$torrentname"
			echo "Torrent state is $rtorrent_state"
			echo "Attempting to repair, sequence is $repair_run_count/$repair_run_count_max"
				if [[ ("${repair_run_count}" -ge "${repair_run_count_max}") ]];then
					echo "repair_run_count=$repair_run_count is above threshold $repair_run_count_max , bailing out"
					return 10
				else
					echo "Repair iteration sequence is $repair_run_count/$repair_run_count_max"
					$rtxmlrpc_bin -Dscgi_url="$rtxmlrpc_socket" -q d.stop "${torrentid}"
					sleep 2
					$rtxmlrpc_bin -Dscgi_url="$rtxmlrpc_socket" -q d.directory.set "${torrentid}" "${torrentpath}"
					sleep 2
					$rtxmlrpc_bin -Dscgi_url="$rtxmlrpc_socket" -q d.check_hash "$torrentid"
					sleep 2
					$rtxmlrpc_bin -Dscgi_url="$rtxmlrpc_socket" -q d.save_full_session "$torrentid"
					sleep 2
					$rtxmlrpc_bin -Dscgi_url="$rtxmlrpc_socket" -q d.custom1.set "${torrentid}" "$rlabel"
					sleep 2
					$rtxmlrpc_bin -Dscgi_url="$rtxmlrpc_socket" -q d.start "${torrentid}"
					sleep 2
					repair_run_count=$(( repair_run_count + 1 ))
					sleep "$r_step_sleep"
					check_rtorrent_details
				fi
		fi
}

#Define the short term seeding function that gets called from main loop if criteria matches
seed_shortterm() {
	substitute_if_null "$short_term_seed_label_suffix" "_short"
	short_term_seed_label_suffix="$substvar"
	rlabel=$(echo "$t_folder_label$short_term_seed_label_suffix" | awk '{ print toupper($0) }')
	run_chtor
	deluge_ratio_to_send
	remove_from_deluge
	add_to_rtorrent
	check_rtorrent_details
}

#Define the long term seeding function that gets called from main loop if criteria matches
seed_longterm() {
	substitute_if_null "$long_term_seed_label_suffix" "_long"
	long_term_seed_label_suffix="$substvar"
	rlabel=$(echo "$t_folder_label$long_term_seed_label_suffix" | awk '{ print toupper($0) }')
	run_chtor
	deluge_ratio_to_send
	remove_from_deluge
	add_to_rtorrent
	check_rtorrent_details
}

#We evaluate the ratios and call one of the above functions based on outcome#
eval_tracker_ratio() {
	if [[ ("${localratio}" -ge "${min_ratio_move_local}"  && "${remoteratio}" -ge "${min_ratio_move_remote}") ]];then
		echo "Tracker is $tracker , local ratio $localratio_raw is greater than ${min_ratio_move_local} and remote ratio $remoteratio_raw is greater than ${min_ratio_move_remote}."
		echo "Moving torrent to short term seeding."
		seed_shortterm
		return

	elif [[ ("$localratio" -ge "${min_ratio_move_local}" && "$remoteratio" -lt "${min_ratio_move_remote}") ]];then
		echo "Tracker is $tracker , local ratio $localratio_raw is greater than ${min_ratio_move_local} and remote ratio $remoteratio_raw is less than ${min_ratio_move_remote}."
		echo "Moving torrent to long term seeding."
		seed_longterm
		return

	elif [[ ("$localratio" -lt "${min_ratio_move_local}" && "$remoteratio" -ge "${min_ratio_move_remote}") ]];then
		echo "Tracker is $tracker , local ratio $localratio_raw is less than ${min_ratio_move_local} and remote ratio $remoteratio_raw is greater than than ${min_ratio_move_remote}."
		if [[ ("${run_count}" -ge "${run_count_max}" || -n "${SKIP_SLEEP+x}") ]];then
			echo "run_count=$run_count is above threshold $run_count_max or SKIP_SLEEP bypass detected, force-moving to long term"
			seed_longterm
			return
		else
			echo "Iteration sequence is $run_count/$run_count_max"
			sleep_func_p step_sleep run_count
#			sleep_func
			calculate_ratio
			eval_tracker_ratio
		fi

	elif [[ ("$localratio" -lt "${min_ratio_move_local}" && "$remoteratio" -lt "${min_ratio_move_remote}") ]];then
		echo "Tracker is $tracker , local ratio $localratio_raw is less than ${min_ratio_move_local} or remote ratio $remoteratio_raw is less than ${min_ratio_move_remote}."
		if [[ ("${run_count}" -ge "${run_count_max}" || -n "${SKIP_SLEEP+x}") ]];then
			echo "run_count=$run_count is above threshold $run_count_max or SKIP_SLEEP bypass detected, force-moving to long term"
			seed_longterm
			return
		else
			echo "Iteration sequence is $run_count/$run_count_max"
			sleep_func_p step_sleep run_count
#			sleep_func
			calculate_ratio
			eval_tracker_ratio
		fi
	else
		echo "Tracker is $tracker , local ratio is $localratio_raw."
		echo "Moving torrent to long term seeding."
		seed_longterm
		return
	fi
}

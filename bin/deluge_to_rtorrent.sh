#Enable/disable debug based on switch#
if [[ -z "${from_shell}" ]];then
	[[ "$always_debug" = 1 ]] && set -x
	set -e
	alias exit_on_function_fail="exit 10"
else
	set -e -x
fi

trap 'err $LINENO' ERR

#Initialize remote support#
check_remote_enabled || exit_on_function_fail
generate_random || exit_on_function_fail

#Validating input/getting the additional required values from deluge#

#Check input parameters are correct#
check_config_variables || exit_on_function_fail

#If timeout is enabled, rewrite the commands#
check_timeout_enabled || exit_on_function_fail

#Do a sanity check on the input, make sure only alphanumeric input was provided#
check_torrentid_correct || exit_on_function_fail

#Retrieve torrent name and check that torrent name is not blank#
get_torrent_name || exit_on_function_fail

#Retrieve torrent path and check that torrent path is not blank#
get_torrent_path || exit_on_function_fail

#Calculate ratio#
calculate_ratio || exit_on_function_fail

#Checking the number of active torrents in deluge that are Active, Downloading or Seeding#
check_num_torrents_active || exit_on_function_fail

#Mapping tracker to a code for further use. Mapping the tracker variable to an internal code#
set_tracker || exit_on_function_fail

echo "##########################################"
echo "Torrentid is $torrentid"
echo "Torrent name is $torrentname"
echo "Torrent path is $torrentpath/$torrentname"
echo "##########################################"

#We maintain the deluge queue. Change this to better describe what it means#
maintain_deluge_queue || exit_on_function_fail

#Set label#
set_label || exit_on_function_fail

#Setting chtor opts#
set_chtor_opts || exit_on_function_fail

#Run main loop#
eval_tracker_ratio || exit_on_function_fail

#Cleanup#
remove_tmpdir || exit_on_function_fail

#Clean exit#
exit 0

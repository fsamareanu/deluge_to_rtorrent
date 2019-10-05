#Enable/disable debug based on switch#
if [[ -z "${from_shell}" ]];then
        true
else
        set -x
fi

trap 'err $LINENO' ERR

#Validating input/getting the additional required values from deluge#

#Check input parameters are correct#

echo Checking if \$home is null
check_null_parameter "$home"
validate_file_folder "$home"
echo Checking if \$bindir is null
check_null_parameter "$bindir"
validate_file_folder "$bindir"
echo Checking if \$chtor_bin is null
check_null_parameter "$chtor_bin"
validate_file_folder "$chtor_bin"
echo Checking if \$dc_local_bin is null
check_null_parameter "$dc_local_bin"
validate_file_folder "$dc_local_bin"
echo Checking if \$dc_local_host is null
check_null_parameter "$dc_local_host"
echo Checking if \$dc_local_username is null
check_null_parameter "$dc_local_username"
echo Checking if \$dc_local_password is null
check_null_parameter "$dc_local_password"
echo Checking if \$deluge_state_dir is null
check_null_parameter "$deluge_state_dir"
validate_file_folder "$deluge_state_dir"
echo Checking if \$logdir is null
check_null_parameter "$logdir"
echo Checking if \$num_torrents_queue_max is null
check_null_parameter "$num_torrents_queue_max"
echo Checking if \$rtxmlrpc_bin is null
check_null_parameter "$rtxmlrpc_bin"
validate_file_folder "$rtxmlrpc_bin"
echo Checking if \$step_sleep is null
check_null_parameter "$step_sleep"
echo Checking if \$torrentid is null
check_null_parameter "$torrentid"

#Initialize remote support#
check_remote_enabled

#If timeout is enabled, rewrite the commands#
check_timeout_enabled

#Do a sanity check on the input, make sure only alphanumeric input was provided#
echo Checking if \$torrentid contains invalid characters
check_torrentid_correct

#Retrieve torrent name and check that torrent name is not blank#
echo Checking if \$torrentname is valid
get_torrent_name
check_null_parameter "$torrentname"

#Retrieve torrent path and check that torrent path is not blank#
echo Checking if \$torrentpath is null
get_torrent_path
check_null_parameter "$torrentpath"

#Check if the destination folder still exists#
echo Checking if \$torrentpath/\$torrentname still exists
validate_file_folder "$torrentpath/$torrentname"

#Calculate ratio#
echo Calculating ratio
calculate_ratio
echo Done

echo Checking if \$localratio_raw is null
check_null_parameter "$localratio_raw"

#Checking the number of active torrents in deluge that are Active, Downloading or Seeding#
check_num_torrents_active

#Mapping tracker to a code for further use. Mapping the tracker variable to an internal code#
set_tracker

#We create directories (if needed)#
create_directories

echo "##########################################"
echo "Torrentid is $torrentid"
echo "Torrent name is $torrentname"
echo "Torrent path is $torrentpath/$torrentname"
echo "##########################################"

#We maintain the deluge queue. Change this to better describe what it means#
maintain_deluge_queue

#Set label#
set_label

#Setting chtor opts#
set_chtor_opts

#Run main loop#
eval_tracker_ratio

#Cleanup#
remove_tmpdir

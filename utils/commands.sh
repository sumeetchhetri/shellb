# Removes any non-alphabetical and non numeric characters from a possible
# shell variable name, allows only underscore
function sanitize_var() {
	echo $(echo ${1} | sed -e "s|[^a-zA-Z0-9_]||g")
}

# Removes any non-alphabetical and non numeric characters from a possible
# shell variable name, allows only underscore
function sanitize_var1() {
	echo $(echo ${1} | sed -e "s|[^a-zA-Z0-9_]|_|g")
}

# Maintains a list of process ids of background processes
BG_PIDS=

# Execute a background process
# if LOG_MODE=1, then echo the message passed and then execute the command
# if LOG_MODE=2, then echo the command itself before executing the command
function bexe() {
	if [ "$LOG_MODE" = "1" ]; then
		echo -e "$1" >> $cmds_log_file
		shift
		"$@" >> $cmds_log_file 2>&1 &
	else
		shift
		echo "\$ $@" >> $cmds_log_file
		"$@" >> $cmds_log_file 2>&1 &
	fi
	BG_PIDS+=" $!"
}

function wait_bexe() {
	# Wait for all processes to finish, will take max 14s
	# as it waits in order of launch, not order of finishing
	for p in $BG_PIDS; do
		BG_PIDS=$(echo ${BG_PIDS/$p /})
		if wait $p; then
			:
		else
			: #exit 1
		fi
	done
}

# Execute a foreground process
# if LOG_MODE=1, then echo the message passed and then execute the command
# if LOG_MODE=2, then echo the command itself before executing the command
function exe() {
	if [ "$LOG_MODE" = "1" ]; then
		#echo -e "$1"
		shift
		"$@" >> $cmds_log_file 2>&1
	else
		shift
		echo "\$ $@" >> $cmds_log_file 2>&1
		"$@" >> $cmds_log_file 2>&1
	fi
	return $?
}

# Remove any relative path identifiers from a path variable
function remove_relative_path() {
	tem_=$1
	if [[ "$1" =~ ^../ ]]; then
		tem_=$(echo "${tem_#../}")
		remove_relative_path "$tem_"
	elif [[ "$1" =~ ^./ ]]; then
		tem_=$(echo "${tem_#./}")
		remove_relative_path "$tem_"
	elif [[ "$1" =~ ^/ ]]; then
		tem_=$(echo "${tem_#/}")
		remove_relative_path "$tem_"
	else
		echo $tem_
	fi
}

# Check if a command exists in the PATH
function exists() {
  command -v "$1" >/dev/null 2>&1
}

# Get an md5sum value of a string value
function get_key() {
	t_=`echo -n $1 | md5sum | xargs`
	t_=${t_% *}
	echo $t_
}

# Get the value from key-value map -- kv-bash
function get_cmd() {
	kvget "SH_$(get_key ${1})"
}

# Find an executable among the various options provided if it exists on PATH
function find_cmd() {
	cmd_=
	for ((i = 3; i <= $#; i++ ))
	do
		if exists ${!i}
		then
			cmd_=${!i}
			break
		fi
	done
	if [ "$cmd_" = "" ]
	then
		echo "no $1 command found"
		if [ "$2" != "" ]
		then
			exit 1
		fi
	else
		#echo "$1 command found... $cmd_"
		echo "$cmd_"
	fi
}

function showprogress() {
	if [ "$BUILD_SYS" = "emb" ]; then
		percent_numer=$((percent_numer+$1))
		ProgressBar "$percent_numer" "$percent_denom" "$2"
	fi
}

function completeprogress() {
	ProgressBar "$percent_denom" "$percent_denom" "$1"
}

_maxlen=0
#https://github.com/fearside/ProgressBar/blob/master/progressbar.sh
# 1. Create ProgressBar function
# 1.1 Input is currentState($1) and totalState($2)
function ProgressBar {
# Process data
	let _progress=(${1}*100/${2}*100)/100
	let _done=(${_progress}*4)/10
	let _left=40-$_done
# Build progressbar string lengths
	_done=$(printf "%${_done}s")
	_left=$(printf "%${_left}s")
	_msg="Progress"
	if [ "$1" != "" ]; then
		_msg="$3"
	fi
	mlen=${#_msg}
	if [ "$mlen" -lt 8 ]
	then
		rem_=$((8-mlen))
		for i in $(seq 1 $rem_)
		do 
			_msg+=' '
		done
	fi
	if [ $mlen -gt $_maxlen ]
	then
		_maxlen=$mlen
	fi
	#echo $_maxlen
	rmsg=""
	rem_=$((_maxlen-8))
	for i in $(seq 1 $_maxlen)
	do 
		rmsg+=' '
	done
# 1.2 Build progressbar strings and print the ProgressBar line
# 1.2.1 Output example:
# 1.2.1.1 Progress : [########################################] 100%
printf "\r${_msg} : [${_done// /#}${_left// /-}] ${_progress}%%${rmsg}"

}

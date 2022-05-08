# Removes any non-alphabetical and non numeric characters from a possible
# shell variable name, allows only underscore
function sanitize_var() {
	echo $(echo ${1} | sed -e "s|[^a-zA-Z0-9_]||g")
}

# Maintains a list of process ids of background processes
BG_PIDS=

# Execute a background process
# if LOG_MODE=1, then echo the message passed and then execute the command
# if LOG_MODE=2, then echo the command itself before executing the command
function bexe() {
	if [ "$LOG_MODE" = "1" ]; then
		echo -e "$1"
		shift
		"$@" > /dev/null &
	else
		shift
		echo "\$ $@"
		"$@" &
	fi
	BG_PIDS+="$! "
	
}

# Execute a foreground process
# if LOG_MODE=1, then echo the message passed and then execute the command
# if LOG_MODE=2, then echo the command itself before executing the command
function exe() {
	if [ "$LOG_MODE" = "1" ]; then
		echo "$1"
		shift
		"$@"
	else
		shift
		echo "\$ $@"
		"$@"
	fi
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
function sanitize_var() {
	echo $(echo ${1} | sed -e "s|[^a-zA-Z0-9_]||g")
}

BG_PIDS=
function exefl() {
	echo "\$ $@"
	"$@" > /dev/null 2>&1 &
	BG_PIDS+="$! "
}

function exeml() {
	echo "$1"
	shift
	"$@" > /dev/null 2>&1 &
	BG_PIDS+="$! "
}

function remove_relative_path() {
	tem_=$1
	if [[ "$1" =~ ^../ ]]; then
		tem_=$(echo "${tem_#../}")
		remove_relative_path "$tem_"
	elif [[ "$1" =~ ^./ ]]; then
		tem_=$(echo "${tem_#./}")
		remove_relative_path "$tem_"
	else
		echo $tem_
	fi
}

function exists()
{
  command -v "$1" >/dev/null 2>&1
}

function get_key() {
	t_=`echo -n $1 | md5sum | xargs`
	t_=${t_% *}
	echo $t_
}

function get_cmd() {
	kvget "SH_$(get_key ${1})"
}

function find_cmd() {
	C_=
	for ((i = 3; i <= $#; i++ ))
	do
		if exists ${!i}
		then
			C_=${!i}
			break
		fi
	done
	if [ "$C_" = "" ]
	then
		echo "no $1 command found"
		if [ "$2" != "" ]
		then
			exit 1
		fi
	else
		echo "$1 command found... $C_"
		kvset "SH_$(get_key ${1})" "$C_"
	fi
}
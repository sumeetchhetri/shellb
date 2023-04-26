#!/usr/bin/env bash


# First find out the current directory  -- from a stackoverflow thread
myreadlink() { [ ! -h "$1" ] && echo "$1" || (local link="$(expr "$(command ls -ld -- "$1")" : '.*-> \(.*\)$')"; cd $(dirname $1); myreadlink "$link" | sed "s|^\([^/].*\)\$|$(dirname $1)/\1|"); }
whereis() { echo $1 | sed "s|^\([^/].*/.*\)|$(pwd)/\1|;s|^\([^/]*\)$|$(which -- $1)|;s|^$|$1|"; } 
whereis_realpath() { local SCRIPT_PATH=$(whereis $1); myreadlink ${SCRIPT_PATH} | sed "s|^\([^/].*\)\$|$(dirname ${SCRIPT_PATH})/\1|"; } 
DIR=$(dirname $(whereis_realpath "$0"))
if [[ "$(type -t kv_echo_err)" == 'function' ]]; then
	DIR=$(pwd)
fi
echo "Home directory is... $DIR"

#Project name for bazel builds
BUILD_PROJ_NAME=
# Variable to define/control the target build system (embedded being the default)
BUILD_SYS=emb

if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

if [[ "$(type -t kv_echo_err)" == 'function' ]]; then
	:
else
	. "$DIR/utils/kv-bash"
fi
if [[ "$(type -t sanitize_var)" == 'function' ]]; then
	:
else
	. "$DIR/utils/commands.sh"
fi

if [ "$BUILD_SYS" = "bazel" ]; then
	if [[ "$(type -t bzl_gen_build_file)" == 'function' ]]; then
		:
	else
		. "$DIR/tools/bazel/bazel-util.sh"
	fi
fi

if [ "$BUILD_SYS" = "buck2" ]; then
	if [[ "$(type -t bck2_gen_build_file)" == 'function' ]]; then
		:
	else
		. "$DIR/tools/buck2/buck2-util.sh"
	fi
fi

# Trap SIGKILL signal -- execute stop function
trap "stop" 2

# Variable to define/control the target platform/language c_cpp being the default
BUILD_PLATFORM=c_cpp

# The list of source directories to exclude from the build
EXC_SRC=

# The list of source files to exclude from the build
EXC_FLS=

# The list of allowed configuration paramaters for the build
ALLOWED_PARAMS=

# The actual parameters passed to the build at runtime
PARAMS=

# The output build directory path
SB_OUTDIR=

# The output install directory path
SB_INSDIR=

# The OS type
OS="$OSTYPE"

# What level of logging do we need
LOG_MODE=2

# The number of identified #cpu's found in the machine
NUM_CPU=1

# The target platform or OS name (linux|darwin|bsd|cygwin|mingw|android..), aliases follow
OS_NAME=
OS_LINUX=
OS_DARWIN=
OS_BSD=
OS_CYGWIN=
OS_MINGW=

# Do we continue execution or stop in case of a signal received
IS_RUN=1

percent_denom=0
percent_numer=0
percent_checks=0

configs_log_file="$DIR/.shellb/checks.log"
cmds_log_file="$DIR/.shellb/commands.log"

# Update PATH and LD_LIBRARY_PATH to include /usr/local as well
export PATH=/usr/local/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Directory to store kv-hash files -- key-value pairs
KV_USER_DIR="$DIR/.shellb/.kv-bash"

# Set the build output directory, if not found create it
function set_out() {
	if [ "$1" = "" ]
	then
		echo "Build output directory is mandatory..."
		exit 1;
	fi
	if [ "$SB_OUTDIR" = "" ]; then
		SB_OUTDIR=$1
	fi
	if [ ! -d "$SB_OUTDIR" ]
	then
		mkdir -p $SB_OUTDIR
	fi
	SB_INSDIR=".bin"
	if [ ! -d "$SB_OUTDIR/.bin" ]
	then
		mkdir -p $SB_OUTDIR/.bin
	fi
}

# Set the build install directory name, if it does not exist create it
function set_install() {
	if [ "$SB_OUTDIR" = "" ]; then echo "Please set output directory first..." && exit 1; fi
	if [ "$1" = "" ]
	then
		echo "Blank install dir specified, any install commands won't work.."
		#exit 1;
	else
		kv_validate_key "$1" || {
			echo "Invalid install dir $1, should be a valid directory name"
			exit 1;
		}
		SB_INSDIR="$1"
		if [ -d "$SB_OUTDIR/$SB_INSDIR" ]; then rm -rf $SB_OUTDIR/$SB_INSDIR; fi
		mkdir $SB_OUTDIR/$SB_INSDIR || true
	fi
}

# Build the provided source files and generate requested artifacts
function set_src_files() {
	if [ "$SB_OUTDIR" = "" ]; then echo "Please set output directory first..." && exit 1; fi
	
	srces_="$1"
	src_out_="$2"
	src_deps_="$3"
	src_incs_="$4"
	shift
	set_src "" "$src_out_" "$src_deps_" "$src_incs_" "$srces_"
}

# Build the provided source directories and generate requested artifacts
function set_src() {
	if [[ "$(type -t do_start)" == 'function' ]]; then
		do_set_src "$@"
	fi
}

# Exclude some source directories from build
function set_exclude_src() {
	for ((i = 1; i <= $#; i++ ))
	do
		if [ "${!i}" = "/*" ]
		then
			echo "Invalid exclude source directory ${!i}"
			continue
		fi
		if [ "${!i}" != "" ] && [ -d "${!i}" ]
		then
			if [[ $EXC_SRC != *";${!i};"* ]]; 
			then
				srces_=`find "${!i}" -type d \( -name '.*' -prune -o -print \)`
				while IFS= read -r idir
				do
					EXC_SRC+=";$idir;"
				done <<< "$srces_"
			else
				:
			fi
		else
			echo "Skipping invalid exclude source directory ${!i}"
		fi
	done
}

# Exclude some source files from build
function set_exclude_files() {
	for ((i = 1; i <= $#; i++ ))
	do
		if [ "${!i}" = "/*" ]
		then
			echo "Invalid exclude source file ${!i}"
			continue
		fi
		if [ "${!i}" != "" ] && [ -f "${!i}" ]
		then
			if [[ $EXC_FLS != *";$1;"* ]]; then EXC_FLS+=";$1;"; fi
		else
			echo "skipping invalid exclude src file ${!i}"
		fi
	done
}

# Template a given file using the list of variables defined
# #1 - template file path (file should contain variables to be replaced withs syntax --- @VAR@)
# #2 - resultant file path -- assuming the directory path for the file is present, does not create parent directories
# #3 - list of comma separated variables to be replaced
function templatize() {
	if [ "$1" != "" ] && [ -f "$1" ] && [ "$2" != "" ] && [ "$3" != "" ]
	then
		rm -f "$2" || true
		cp -f "$1" "$2"
		if [ "$2" != "" ]; then
			for tv_ in ${3//,/ }
			do
				sed -i'' -e "s|@$tv_@|${!tv_}|g" "$2"
			done
		else
			:
		fi
	else
		echo "Skipping invalid template file $1"
	fi
}

# If the configuration parameter passed allowed and is set to true
function is_config() {
	if [[ $PARAMS = *";$1=1;"* ]]; then
		return
	else
		if [[ $ALLOWED_PARAMS = *";$1=1;"* ]]; then
			return
		else
			false
		fi
	fi
}

# Handle the configuration information provided, parse it and update allowed parameter list
# 'SOME_CONFIG|Some description for the config|1\n' 1|0 for true|false
function handle_configs() {
	if [ "$1" != "" ]; then
		while IFS='\n' read -r con_
		do
			con_=(${con_// /_})
			cp_=(${con_//|/ })
			val_=0
			if [ "${cp_[2]}" = "1" ] || [ "${cp_[2]}" = "yes" ] || [ "${cp_[2]}" = "true" ] || [ "${cp_[2]}" = "on" ]; then
				val_=1
			fi
			if [[ $ALLOWED_PARAMS != *";${cp_[0]}=${val_};"* ]]; then ALLOWED_PARAMS+=";${cp_[0]}=${val_};"; fi
		done <<< "$1"
	fi
}

# Install the said files/directories to the install directory
# #1 - Target subdirectory within the install directory
# following arguments specify either,
#    files to be installed
#    directories to be installed
#    "../path/to/source@*.sh,*.key,*.pem,*.crt" -- pattern after @ character for installing multiple files
function install_here() {
	if [ "$SB_INSDIR" = "" ]; then echo "Please set install directory first...using [set_install]" && exit 1; fi
	if [[ "$1" != "." ]]; then
		kv_validate_key "$1" || {
			if ! [[ "$1" =~ "^." ]]; then
				if [ -d "$SB_OUTDIR/$SB_INSDIR/$1" ]; then
					echo "WARNING>> Install path $SB_OUTDIR/$SB_INSDIR/$1 may be outside the project tree, exercise caution...."
				else
					echo "Invalid install subdirectory $1, should be a valid directory name or ."
					exit 1;
				fi
			fi
		}
		ldir="$SB_OUTDIR/$SB_INSDIR/$1"
	else
		ldir="$SB_OUTDIR/$SB_INSDIR"
	fi
	
	if [ ! -d "$ldir" ]; then
		mkdir -p "$ldir"
	fi
	shift
	for ((i = 1; i <= $#; i++ ))
	do
		if [[ "${!i}" = *"@"* ]]; then
			var_="${!i}"
			pth_="${var_%%@*}"
			wld_="${var_#*@}"
			if [ -d "$DIR/$pth_" ]; then
				pth_="$DIR/$pth_"
			elif [ -d "${!i}" ]; then
				:
			fi
			(set -f
				for ex in ${wld_//,/ } ; do
					exe "" find $pth_ -type f -name "$ex" -exec cp "{}" "$ldir" \;
				done
			)
		else
			#fck_=$(remove_relative_path ${!i})
			(set -f
				if [ -f "$SB_OUTDIR/.bin/${!i}" ]; then
					exe "" cp -f "$SB_OUTDIR/.bin/${!i}" "$ldir"
				elif [ -d "$DIR/${!i}" ]; then
					exe "" cp -rf "$DIR/${!i}" "$ldir"
				elif [ -d "${!i}" ]; then
					exe "" cp -rf "${!i}" "$ldir"
				elif [ -f "$DIR/${!i}" ]; then
					exe "" cp -f "$DIR/${!i}" "$ldir"
				elif [ -f "${!i}" ]; then
					exe "" cp -f "${!i}" "$ldir"
				else
					exe "" find $SB_OUTDIR/.bin/ -name "${!i}" -type f -exec cp "{}" "$ldir" \;
				fi
			)
		fi
	done
	showprogress 3 "Installing..."
}

# Install the said files/directories to the install directory
# #1 - Target subdirectory within the install directory
# following arguments specify either,
#    files to be installed
#    directories to be installed
#    "../path/to/source@*.sh,*.key,*.pem,*.crt" -- pattern after @ character for installing multiple files
function install_mkdir() {
	if [ "$SB_INSDIR" = "" ]; then echo "Please set install directory first...using [set_install]" && exit 1; fi
	if [[ "$1" != "." ]]; then
		kv_validate_key "$1" || {
			if ! [[ "$1" =~ "^." ]]; then
				echo "Invalid install subdirectory $1, should be a valid directory name or ."
				exit 1;
			fi
		}
		ldir="$SB_OUTDIR/$SB_INSDIR/$1"
	else
		ldir="$SB_OUTDIR/$SB_INSDIR"
	fi
	
	if [ ! -d "$ldir" ]; then
		mkdir -p "$ldir"
	fi
	showprogress 3 "Installing..."
}

# Display help for the configuration parameters
function show_help() {
	if [ "$1" != "" ]; then
		echo $'Allowed configuration paramaters are,'
		while IFS='\n' read -r con_
		do
			con_=(${con_// /_})
			cp_=(${con_//|/ })
			cd_=${cp_[1]//_/ }
			val_="${cp_[0]} - [$cd_] [Default: "
			if [ "${cp_[2]}" = "1" ] || [ "${cp_[2]}" = "yes" ] || [ "${cp_[2]}" = "true" ] || [ "${cp_[2]}" = "on" ]; then
				val_+="enabled]"
			else
				val_+="disabled]"
			fi
			echo -e "  $val_"
		done <<< "$1"
		echo $'\n\n'
	fi
}

# Trap SIGKILL handler function
function stop() {
	IS_RUN=0
	#echo $BG_PIDS
	for i in $BG_PIDS ; do
		while kill -0 $i > /dev/null 2>&1
		do
			wait $i
			BG_PIDS=$(echo ${BG_PIDS/$i /})
		done
	done
}

# Perform certain platform specific actions based on platform/build tool
function trigger_build() {
	if [ "$BUILD_SYS" = "bazel" ]; then
		do_bazel_build "$@"
	elif [ "$BUILD_SYS" = "buck2" ]; then
		do_buck2_build "$@"
	fi
}

# Perform certain platform specific actions based on platform/build tool
function do_prebuild() {
	if [ "$BUILD_SYS" = "bazel" ]; then
		do_bazel_pre_build "$@"
	elif [ "$BUILD_SYS" = "buck2" ]; then
		do_buck2_pre_build "$@"
	fi
}

# Start shellb build process
# Requirements - bash, sed, printf, awk, find, grep, ls
# A valid shellb script should contain following functions,
#     do_setup - define/set build options 
#     do_start - kick off the actual configuration checks and build process
# Following functions are optional
#     do_config - define the configuration parameters
#     do_install - define the installation steps to create a resulting artifact
function start() {
	if [ "$BUILD_PLATFORM" = "c_cpp" ]; then
		if [[ "$(type -t add_def)" == 'function' ]]; then
			:
		else
			. "$DIR/platform/c_cpp/checks.sh"
		fi
		if [[ "$(type -t b_init)" == 'function' ]]; then
			:
		else
			. "$DIR/platform/c_cpp/build.sh"
		fi
	fi

	if [ "$1" != "" ]; then
		bfile=
		if [ -f "$1" ]; then 
			bfile=$(remove_relative_path ${1})
		elif [ -f "${1}.sh" ]; then 
			bfile=$(remove_relative_path ${1}.sh)
		fi
		
		if [ -f "$bfile" ]; then
			if [[ "$OSTYPE" == "linux-gnu"* ]]; then
				OS_NAME="LINUX"
				OS_LINUX=1
				NUM_CPU=$(getconf _NPROCESSORS_ONLN)
			elif [[ "$OSTYPE" == "darwin"* ]]; then
				OS_NAME="DARWIN"
				OS_DARWIN=1
				NUM_CPU=$(getconf _NPROCESSORS_ONLN)
			elif [[ "$OSTYPE" == "cygwin" ]]; then
				OS_NAME="CYGWIN"
				OS_CYGWIN=1
				NUM_CPU=$(getconf _NPROCESSORS_ONLN)
			elif [[ "$OSTYPE" == "msys" ]]; then
				OS_NAME="MINGW"
				OS_MINGW=1
				NUM_CPU=$(getconf _NPROCESSORS_ONLN)
			elif [[ "$OSTYPE" == "freebsd"* ]]; then
				OS_NAME="BSD"
				OS_BSD=1
				NUM_CPU=$(getconf NPROCESSORS_ONLN)
			else
				OS_NAME="UNKNOWN"
				NUM_CPU=$(getconf NPROCESSORS_ONLN)
			fi

			. "$bfile"

			if [[ "$(type -t do_config)" == 'function' ]]; then
				configs=$(do_config)
				handle_configs "$configs"
				percent_denom=$((percent_denom+5))
			fi

			if [[ "$(type -t do_start)" == 'function' ]]; then
				code_chdr_=$(type -a do_start|grep "c_hdr"|wc -l)
				code_clib_=$(type -a do_start|grep "c_lib"|wc -l)
				code_cfunc_=$(type -a do_start|grep "c_func"|wc -l)
				code_ccode_=$(type -a do_start|grep "c_code"|wc -l)
				code_cpphdr_=$(type -a do_start|grep "cpp_hdr"|wc -l)
				code_cpplib_=$(type -a do_start|grep "cpp_lib"|wc -l)
				code_cppcode_=$(type -a do_start|grep "cpp_code"|wc -l)
				percent_checks=$((code_chdr_+code_clib_+code_cfunc_+code_ccode_+code_cpphdr_+code_cpplib_+code_cppcode_))
				percent_checks=$((percent_checks+percent_checks+percent_checks))
				percent_denom=$((percent_denom+percent_checks))
				#echo "$percent_checks"
			fi

			if [[ "$(type -t do_install)" == 'function' ]]; then
				code_install_here_=$(type -a do_install|grep "install_here"|wc -l)
				code_install_here_=$((code_install_here_+code_install_here_+code_install_here_))
				percent_denom=$((percent_denom+code_install_here_))
				#echo "$code_install_here_"
			fi

			if [ "$2" = "help" ]; then
				show_help "$configs"
				exit 0
			fi

			for ((i = 2; i <= $#; i++ ))
			do
				if [[ $PARAMS != *";${!i};"* ]]; then PARAMS+=";${!i};"; fi
			done

			rm -rf .shellb || true
			mkdir .shellb

			touch $configs_log_file
			touch $cmds_log_file

			do_setup
			DEFS_FILE="$DIR/$DEFS_FILE"
			if [ -f "$DEFS_FILE" ]; then
				rm -f "$DEFS_FILE"
			fi
			touch "$DEFS_FILE"

			if [ "$BUILD_SYS" = "bazel" ] || [ "$BUILD_SYS" = "buck2" ]; then
				do_prebuild
			fi

			if [[ "$(type -t do_start)" == 'function' ]]; then
				do_start
				if [ "$BUILD_SYS" = "emb" ]; then
					err_cnt_=$(cat $cmds_log_file|grep " error: "|wc -l)
					if [ ! -z "$err_cnt_" ] && [ "$err_cnt_" -ne 0 ]; then
						echo "Build failed, please check the log file for details .... $cmds_log_file"
					fi
				fi
			else
				echo "Please provide a valid shellb script with a do_start function implementation"
			fi
			if [[ "$(type -t do_install)" == 'function' ]]; then
				do_install
			fi

			#rm -rf .shellb
			completeprogress "Finishing..."
		fi
	fi
}

start "$@"

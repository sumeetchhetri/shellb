#!/bin/bash

myreadlink() { [ ! -h "$1" ] && echo "$1" || (local link="$(expr "$(command ls -ld -- "$1")" : '.*-> \(.*\)$')"; cd $(dirname $1); myreadlink "$link" | sed "s|^\([^/].*\)\$|$(dirname $1)/\1|"); }
whereis() { echo $1 | sed "s|^\([^/].*/.*\)|$(pwd)/\1|;s|^\([^/]*\)$|$(which -- $1)|;s|^$|$1|"; } 
whereis_realpath() { local SCRIPT_PATH=$(whereis $1); myreadlink ${SCRIPT_PATH} | sed "s|^\([^/].*\)\$|$(dirname ${SCRIPT_PATH})/\1|"; } 
DIR=$(dirname $(whereis_realpath "$0"))
echo "home dir is... $DIR"

if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/utils/kv-bash"
. "$DIR/commands/_.sh"
. "$DIR/builds/_.sh"
. "$DIR/checks/_.sh"

trap "stop" 2

BUILD_SYS=emb

LPATHS=
LPATHSQ=
LIBS=
INCS=
EXC_SRC=
CFLAGS=
LFLAGS=
SHLIB_EXT=".so"

DEFS_FILE=$DIR/.shellb/.AppDefs.h

SB_OUTDIR=

OS="$OSTYPE"
LOG_MODE=2
NUM_CPU=1

OS_LINUX=
OS_DARWIN=
OS_BSD=
OS_CYGWIN=
OS_MINGW=
IS_RUN=1

function set_out() {
	if [ "$1" = "" ]
	then
		echo "invalid output dir $1"
		exit 1;
	fi
	if [ -d "$1" ]
	then
		mkdir -p $1
	fi
	if [ "$SB_OUTDIR" = "" ]; then
		SB_OUTDIR=$1
	#	mkdir -p $1
	fi
}

function set_src() {
	if [ "$1" = "" ]
	then
		echo "invalid src dir $1"
		exit 1;
	fi

	src_=
	src_out_=
	src_deps_=

	for ((i = 1; i <= $#; i++ ))
	do
		if [ "$src_" = "" ]; then
			src_=${!i}
		elif [ "$src_out_" = "" ]; then
			src_out_=${!i}
		elif [ "$src_deps_" = "" ]; then
			src_deps_=${!i}
		fi
	done

	if [ ! -d "$src_" ]; then
		echo "invalid src dir $1"
		exit 1;
	fi
	if [ "$src_" = "/*" ]; then
		echo "invalid src dir $1"
		exit 1;
	fi
	
	if [ "$IS_RUN" = "0" ]; then echo "got kill signal...shutting down..."; exit 1; fi
	b_cpp_build "$src_" "$src_out_" "$src_deps_"
}

function set_exclude_src() {
	if [ "$1" = "" ] || [ ! -d "$1" ]
	then
		echo "invalid exclude src dir $1"
		exit 1;
	fi
	if [ "$0" = "/*" ]
	then
		echo "invalid exclude src dir $1"
		exit 1;
	fi
	EXC_SRC+=";$SB_OUTDIR/$1;"
}

function add_def() {
	if [ "$1" = "" ]
	then
		echo "Invalid defines"
	fi
	for ((i = 1; i <= $#; i++ ))
	do
		if [ "${!i}" != "" ]
		then
			echo "#define ${!i} 1" >> $DEFS_FILE
		fi
	done
}

function add_lib_path() {
	for ((i = 1; i <= $#; i++ ))
	do
		if [ "${!i}" != "" ] && [ -d "${!i}" ]
		then
			LPATHS+="-L${!i} "
			LPATHSQ+="\"-L${!i}\","
		else
			echo "skipping invalid library path ${!i}"
		fi
	done
}

function add_lib() {
	for ((i = 1; i <= $#; i++ ))
	do
		if [ "${!i}" != "" ]
		then
			LIBS+="-l${!i} "
			LPATHSQ+="\"-l${!i}\","
		else
			echo "skipping invalid library name ${!i}"
		fi
	done
}

function add_inc_path() {
	for ((i = 1; i <= $#; i++ ))
	do
		if [ "${!i}" != "" ] && [ -d "${!i}" ]
		then
			INCS+="-I${!i} "
		else
			echo "skipping invalid include path ${!i}"
		fi
	done
}

function c_flags() {
	if [ "$1" = "" ]
	then
		echo "skipping invalid compiler flags"
	fi
	CFLAGS+="$1"
}

function l_flags() {
	if [ "$1" = "" ]
	then
		echo "skipping invalid linker flags"
	fi
	LFLAGS+="$1"
}

export PATH=/usr/local/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
KV_USER_DIR=".shellb/.kv-bash"

function stop() {
	IS_RUN=0
	#echo $BG_PIDS
	for i in $BG_PIDS ; do
		while kill -0 $i > /dev/null 2>&1
		do
			wait $i
		done
	done
}

function start() {
	if [ "$1" != "" ] && [ -f "$1" ]; then
		. "$1"

		rm -rf .shellb
		mkdir .shellb

		do_config
		DEFS_FILE="$DIR/$DEFS_FILE"
		rm -f "$DEFS_FILE"

		if [[ "$OSTYPE" == "linux-gnu"* ]]; then
			OS_LINUX=1
			echo "#define OS_LINUX 1" >> $DEFS_FILE
			NUM_CPU=$(getconf _NPROCESSORS_ONLN)
		elif [[ "$OSTYPE" == "darwin"* ]]; then
			OS_DARWIN=1
			echo "#define OS_DARWIN 1" >> $DEFS_FILE
			NUM_CPU=$(getconf _NPROCESSORS_ONLN)
			SHLIB_EXT=".dylib"
		elif [[ "$OSTYPE" == "cygwin" ]]; then
			OS_CYGWIN=1
			echo "#define OS_CYGWIN 1" >> $DEFS_FILE
			NUM_CPU=$(getconf _NPROCESSORS_ONLN)
		elif [[ "$OSTYPE" == "msys" ]]; then
			OS_MINGW=1
			echo "#define OS_MINGW 1" >> $DEFS_FILE
			NUM_CPU=$(getconf _NPROCESSORS_ONLN)
		elif [[ "$OSTYPE" == "freebsd"* ]]; then
			OS_BSD=1
			echo "#define OS_BSD 1" >> $DEFS_FILE
			NUM_CPU=$(getconf NPROCESSORS_ONLN)
		fi

		do_start

		rm -rf .shellb
	fi
}

start "$@"

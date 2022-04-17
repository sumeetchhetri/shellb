DEFINE=
ERROR=
COUNT=0
is_direct_=1

TEST_C_CODE=$(<snippets/.test.c)
TEST_FUNC_CODE=$(<snippets/.testfunc.c)
TEST_LIB_CODE=$(<snippets/.testlib.c)

MY_CC=
MY_CPP=
EX_DIR=

function c_compiler() {
	if [ "$MY_CC" = "" ]; then MY_CC=$(get_cmd c); fi
	if [ "$MY_CPP" = "" ]; then MY_CPP=$(get_cmd c++); fi
}

function c_init() {
	c_compiler
	#echo ${MY_CC}
	#echo ${MY_CPP}
	b_init
	DEFINE=$2
	ERROR=$3
	EX_DIR1=$4
	EX_DIR2=$5
	pushd .shellb > /dev/null
}

function c_finalize() {
	if [ "$COUNT" -eq 0 ]
	then
		echo "#define $DEFINE 1" >> $DEFS_FILE
		eval "$(sanitize_var ${DEFINE})"='1'
	else
		if [ "$ERROR" != "" ]
		then
			echo "error: $ERROR"
			exit 1
		fi
	fi
	popd > /dev/null
}

function c_hdr() {
	if [ "$is_direct_" = "1" ]; then c_init "$@"; fi
	echo "$TEST_C_CODE" > ./.test.c
	sed -i'' -e "s|INC_FILE|$1|g" .test.c
	b_test cc .test.c
	if [ "$is_direct_" = "1" ]; then c_finalize; fi
}

function c_lib() {
	if [ "$is_direct_" = "1" ]; then c_init "$@"; fi
	echo "$TEST_LIB_CODE" > ./.testlib.c
	b_test cccl .testlib.c "$1"
	if [ "$is_direct_" = "1" ]; then c_finalize; fi
}

function c_hdr_lib() {
	if [ "$is_direct_" = "1" ]; then c_init "$@"; fi
	DEFINE=$3
	ERROR=$4
	EX_DIR1=$5
	EX_DIR2=$6
	echo "$TEST_C_CODE" > ./.testlibhdr.c
	sed -i'' -e "s|INC_FILE|$1|g" .testlibhdr.c
	b_test cccl .testlibhdr.c "$2"
	if [ "$is_direct_" = "1" ]; then c_finalize; fi
}

function c_code() {
	if [ "$is_direct_" = "1" ]; then c_init "$@"; fi
	echo $1 > ./.testcode.c
	b_test cc .testcode.c
	if [ "$is_direct_" = "1" ]; then c_finalize; fi
}

function c_func() {
	if [ "$is_direct_" = "1" ]; then c_init "$@"; fi
	echo "$TEST_FUNC_CODE" > ./.testfunc.c
	sed -i'' -e "s|FUNC_NAME|$1|g" .testfunc.c
	b_test cccl .testfunc.c
	if [ "$is_direct_" = "1" ]; then c_finalize; fi
}

function cpp_hdr() {
	if [ "$is_direct_" = "1" ]; then c_init "$@"; fi
	echo "$TEST_C_CODE" > ./.test.cpp
	sed -i'' -e "s|INC_FILE|$1|g" .test.cpp
	b_test cppc .test.cpp
	if [ "$is_direct_" = "1" ]; then c_finalize; fi
}

function cpp_lib() {
	if [ "$is_direct_" = "1" ]; then c_init "$@"; fi
	echo "$TEST_LIB_CODE" > ./.testlib.cpp
	b_test cppccppl .testlib.cpp "$1"
	if [ "$is_direct_" = "1" ]; then c_finalize; fi
}

function cpp_hdr_lib() {
	if [ "$is_direct_" = "1" ]; then c_init "$@"; fi
	DEFINE=$3
	ERROR=$4
	EX_DIR1=$5
	EX_DIR2=$6
	echo "$TEST_C_CODE" > ./.testlibhdr.cpp
	sed -i'' -e "s|INC_FILE|$1|g" .testlibhdr.cpp
	b_test cppccppl .testlibhdr.cpp "$2"
	if [ "$is_direct_" = "1" ]; then c_finalize; fi
}

function cpp_code() {
	if [ "$is_direct_" = "1" ]; then c_init "$@"; fi
	echo $1 > ./.testcode.cpp
	b_test cppc .testcode.cpp
	if [ "$is_direct_" = "1" ]; then c_finalize; fi
}

function check_existence() {
	#echo "--$DIR"
	cmd_=$1
	shift
	c_init "$@"
	is_direct_=0

	if [ "$cmd_" = "c_hdr" ]
	then
		c_hdr "$@"
	elif [ "$cmd_" = "c_hdr_lib" ]
	then
		c_hdr_lib "$@"
	elif [ "$cmd_" = "c_lib" ]
	then
		c_lib "$@"
	elif [ "$cmd_" = "c_code" ]
	then
		c_code "$@"
	elif [ "$cmd_" = "c_func" ]
	then
		c_func "$@"
	elif [ "$cmd_" = "cpp_hdr" ]
	then
		cpp_hdr "$@"
	elif [ "$cmd_" = "cpp_hdr_lib" ]
	then
		cpp_hdr_lib "$@"
	elif [ "$cmd_" = "cpp_lib" ]
	then
		cpp_lib "$@"
	elif [ "$cmd_" = "cpp_code" ]
	then
		cpp_code "$@"
	fi
	
	c_finalize
}
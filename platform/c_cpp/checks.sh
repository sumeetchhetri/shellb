# The c compiler
MY_CC=
# The c++ compiler
MY_CPP=
# The static library archiver
MY_AR=

# The list of #define(s) to be declared post a configuration check succeeds
define_=
# The error message to be displayed in case of a configuration check failure
error_=

COUNT=0
# The platform setup variable identifying the #defines include header file
DEFS_FILE=$DIR/.shellb/.AppDefs.h
# All the #define preprocessor macros defined 
ALL_DEFS=
# The list of all library paths to be used during shared library builds
LPATHS=
# Unused
LPATHSQ=
# The list of all libraries to be used during shared library builds
LIBS=
# The list of all include directories to be used during compilation
INCS=
INCSQ=
PINCSQ=
PINCSD=
# The c compiler flags for build
CFLAGS=
# The c++ compiler flags for build
CPPFLAGS=
# The linker flags for build
LFLAGS=
# The standard shared library extension
SHLIB_EXT="so"
# The standard static library extension
STLIB_EXT="a"

if [[ "$OSTYPE" == "darwin"* ]]; then
	SHLIB_EXT="dylib"
fi

test_c_code_=$(cat <<-END
#include "INC_FILE"
int main() {return 0;}
END
)
test_func_code_=$(cat <<-END
#include <assert.h>

#ifdef __cplusplus
extern "C"
#endif
char FUNC_NAME();

#if _MSC_VER && !__INTEL_COMPILER
    #pragma function(accept4)
#endif

int main(void) {
#if defined (__stub_accept4) || defined (__stub___accept4)
  fail fail fail
#else
  FUNC_NAME();
#endif

  return 0;
}
END
)
test_lib_code_=$(cat <<-END
int main() {return 0;}
END
)

# The additional set of directores to be considered as include/library paths
EX_DIR=
# Are we building c or c++ files
BUILD_TYPE=c

# Add #define macros, will be passed to the $DEFS_FILE or passed as a compiler flag (-D)
function add_def() {
	if [ "$1" = "" ]
	then
		echo "Invalid defines"
	fi
	for ((i = 1; i <= $#; i++ ))
	do
		s_def=$(sanitize_var ${!i})
		if [ "${!i}" = "$s_def" ]
		then
			if [[ $ALL_DEFS != *";${!i};"* ]]; then
				ALL_DEFS+=";${!i};"
				eval "$(sanitize_var ${!i})"='1'
				if [ -f "$DEFS_FILE" ]; then
					echo "#define ${!i} 1" >> $DEFS_FILE
				else
					CFLAGS+="-D$1=1 "
					CPPFLAGS+="-D$1=1 "
				fi
			fi
		else
			echo "Invalid defines ${!i}"
			exit 1
		fi
	done
}

# Specify library path to be used during linking
function add_lib_path() {
	for ((i = 1; i <= $#; i++ ))
	do
		if [ "${!i}" != "" ] && [ -d "${!i}" ]
		then
			if [[ $LPATHS != *"-L${!i} "* ]]; then
				LPATHS+="-L${!i} "
				LPATHSQ+="\"-L${!i}\","
			fi
		else
			echo "Skipping invalid library path ${!i}"
		fi
	done
}

# Specify library to be used during linking
function add_lib() {
	for ((i = 1; i <= $#; i++ ))
	do
		if [ "${!i}" != "" ]
		then
			if [[ $LIBS != *"-l${!i} "* ]]; then
				if [[ "${!i}" =~ ^-l ]]; then
					LIBS+="${!i} "
					LPATHSQ+="\"${!i}\","
				else
					LIBS+="-l${!i} "
					LPATHSQ+="\"-l${!i}\","
				fi
			fi
		else
			: #echo "Skipping invalid library name ${!i}"
		fi
	done
}

# Specify include path to be used during compilation
function add_inc_path() {
	for ((i = 1; i <= $#; i++ ))
	do
		if [ "${!i}" != "" ] && [ -d "${!i}" ]
		then
			if [[ $INCS != *"-I${!i} "* ]]; then 
				INCS+="-I${!i} "
				INCSQ+="${!i},"
				if [[ ${!i} != "/"* ]]; then
					PINCSD="\"-I${!i}\","
				fi
			fi
		else
			echo "skipping invalid include path ${!i}"
		fi
	done
}

# Specify c flags for compilation
function c_flags() {
	if [ "$1" = "" ]
	then
		: #echo "Skipping invalid c compiler flags"
	fi
	CFLAGS+="$1 "
}

# Specify c++ flags for compilation
function cpp_flags() {
	if [ "$1" = "" ]
	then
		: #echo "skipping invalid c++ compiler flags"
	else
		CPPFLAGS+="$1 "
		if [ "$BUILD_SYS" != "buck2" ]; then
			PINCSQ+="\"$1\","
		fi
	fi
}

function l_flags() {
	if [ "$1" = "" ]
	then
		: #echo "skipping invalid linker flags"
	else
		LFLAGS+="$1"
		LPATHS+="$1 "
		LPATHSQ+="\"$1\","
	fi
}

# Check whether a macro is defined
function defined() {
	if [ "$1" != "" ] && [[ $ALL_DEFS == *";$1;"* ]]; then return; fi
	false
}

# Find a valid c++ compiler, c compiler and archiver and set the required variable
function finc_cpp_compiler() {
	BUILD_TYPE=cpp
	err_=
	if [ "$1" = "" ]; then err_="$1"; fi
	MY_CC=$(find_cmd c "$err [c compiler not found]" clang gcc c)
	if [ "$MY_CC" != "" ]; then echo "c compiler found $MY_CC"; fi
	MY_CPP=$(find_cmd c++ "$err [c++ compiler not found]" clang++ g++ c++)
	if [ "$MY_CPP" != "" ]; then echo "c++ compiler found $MY_CPP"; fi
	MY_AR=$(find_cmd ar "$err [ar not found]" ar)
	if [ "$MY_AR" != "" ]; then echo "static library archiver found $MY_AR"; fi
}

# Find a valid c compiler and archiver and set the required variable
function finc_c_compiler() {
	MY_CC=$(find_cmd c "$err [c compiler not foun]" clang gcc c)
	if [ "$MY_CC" != "" ]; then echo "c compiler found $MY_CC"; fi
	MY_AR=$(find_cmd ar "$err [ar not found]" ar)
	if [ "$MY_AR" != "" ]; then echo "static library archiver found $MY_AR"; fi
}

function c_init() {
	b_init
	define_=$2
	error_=$3
	EX_DIR1=$4
	EX_DIR2=$5
	pushd .shellb > /dev/null
}

function c_finalize() {
	if [ "$COUNT" -eq 0 ]
	then
		for i in ${define_//,/ }
		do
			add_def "$i"
		done
		echo "success " >> $configs_log_file
		popd > /dev/null
		return
	else
		if [ "$error_" != "" ]
		then
			echo "error: $error_" >> $configs_log_file
		else
			echo "error " >> $configs_log_file
		fi
		popd > /dev/null
		false
	fi
	#showprogress 3
}

# Check whether a c include file exists and can be compiled
function c_hdr() {
	c_init "$@"
	echo "\$ c_init $@" >> $configs_log_file
	printf "$test_c_code_\n" > ./.test.c
	sed -i'' -e "s|INC_FILE|$1|g" .test.c
	b_test cc .test.c
	if c_finalize; then return; fi
	false
}

# Check whether a c library file exists and can be used for linking
function c_lib() {
	c_init "$@"
	echo "\$ c_lib $@" >> $configs_log_file
	printf "$test_lib_code_\n" > ./.testlib.c
	b_test cccl .testlib.c "$1"
	if c_finalize; then return; fi
	false
}

# Check whether a c include file exists and can be compiled &
# Check whether a c library file exists and can be used for linking
function c_hdr_lib() {
	c_init "$@"
	define_=$3
	error_=$4
	EX_DIR1=$5
	EX_DIR2=$6
	echo "\$ c_hdr_lib $@" >> $configs_log_file
	printf "$test_c_code_\n" > ./.testlibhdr.c
	sed -i'' -e "s|INC_FILE|$1|g" .testlibhdr.c
	b_test cccl .testlibhdr.c "$2"
	if c_finalize; then return; fi
	false
}

# Check whether the c code can be compiled
function c_code() {
	c_init "$@"
	echo "\$ c_code $@" >> $configs_log_file
	printf "$1\n" > ./.testcode.c
	b_test cc .testcode.c
	if c_finalize; then return; fi
	false
}

# Check whether the c function is availabe
function c_func() {
	c_init "$@"
	echo "\$ c_func $@" >> $configs_log_file
	printf "$test_func_code_\n" > ./.testfunc.c
	sed -i'' -e "s|FUNC_NAME|$1|g" .testfunc.c
	b_test cccl .testfunc.c
	if c_finalize; then return; fi
	false
}

# Check whether a c++ include file exists and can be compiled
function cpp_hdr() {
	c_init "$@"
	echo "\$ cpp_hdr $@" >> $configs_log_file
	printf "$test_c_code_\n" > ./.test.cpp
	sed -i'' -e "s|INC_FILE|$1|g" .test.cpp
	b_test cppc .test.cpp
	if c_finalize; then return; fi
	false
}

# Check whether a c++ library file exists and can be used for linking
function cpp_lib() {
	c_init "$@"
	echo "\$ cpp_lib $@" >> $configs_log_file
	printf "$test_lib_code_\n" > ./.testlib.cpp
	b_test cppccppl .testlib.cpp "$1"
	if c_finalize; then return; fi
	false
}

# Check whether a c++ include file exists and can be compiled &
# Check whether a c++ library file exists and can be used for linking
function cpp_hdr_lib() {
	c_init "$@"
	define_=$3
	error_=$4
	EX_DIR1=$5
	EX_DIR2=$6
	echo "\$ cpp_hdr_lib $@" >> $configs_log_file
	printf "$test_c_code_\n" > ./.testlibhdr.cpp
	sed -i'' -e "s|INC_FILE|$1|g" .testlibhdr.cpp
	b_test cppccppl .testlibhdr.cpp "$2"
	if c_finalize; then return; fi
	false
}

# Check whether the c++ code can be compiled
function cpp_code() {
	c_init "$@"
	echo "\$ cpp_code $@" >> $configs_log_file
	printf "$1\n" > ./.testcode.cpp
	b_test cppc .testcode.cpp
	if c_finalize; then return; fi
	false
}

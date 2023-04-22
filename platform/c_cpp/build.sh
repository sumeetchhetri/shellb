all_objs_=
all_absobjs_=
src_=
l_paths=

function b_init() {
	#echo $MY_CC
	:
}

function b_test() {
	incs_=$INCS
	incsq_=$INCSQ
	libs_=$LPATHS
	if [ "$EX_DIR1" != "" ] && [ -d "$EX_DIR1" ] && [ "$EX_DIR2" != "" ] && [ -d "$EX_DIR2" ]; then
		if [ "$1" = "cccl" ] || [ "$1" = "cppccppl" ]; then
			incs_+="-I$EX_DIR1 "
			incsq_+="$EX_DIR1,"
			libs_+="-L$EX_DIR2 "
		elif [ "$1" = "cc" ] || [ "$1" = "cppc" ]; then
			incs_+="-I$EX_DIR1 "
			incsq_+="$EX_DIR1,"
		elif [ "$1" = "cl" ] || [ "$1" = "cppl" ]; then
			libs_+="-L$EX_DIR2 "
		fi
	elif [ "$EX_DIR1" != "" ] && [ -d "$EX_DIR1" ]; then
		if [ "$1" = "cc" ] || [ "$1" = "cppc" ]; then
			incs_+="-I$EX_DIR1 "
			incsq_+="$EX_DIR1,"
		elif [ "$1" = "cl" ] || [ "$1" = "cppl" ]; then
			libs_+="-L$EX_DIR1 "
		fi
	elif [ "$EX_DIR2" != "" ] && [ -d "$EX_DIR2" ]; then
		if [ "$1" = "cc" ] || [ "$1" = "cppc" ]; then
			incs_+="-I$EX_DIR2 "
			incsq_+="$EX_DIR2,"
		elif [ "$1" = "cl" ] || [ "$1" = "cppl" ]; then
			libs_+="-L$EX_DIR2 "
		fi
	fi
	out_=$(echo ${2} | sed -e "s|[^a-zA-Z0-9]||g")
	lib_=
	if [ "$3" != "" ]; then lib_="-l$3"; fi
	if [ "$1" = "cc" ]; then
		COUNT=$(${MY_CC} -o $out_.o -c ${CFLAGS} $incs_ $2 2>&1|grep "error"|wc -l)
	elif [ "$1" = "cl" ]; then
		COUNT=$(${MY_CC} -o ${out_}.inter ${out_}.o $libs_ ${lib_} 2>&1|grep "error"|wc -l)
	elif [ "$1" = "cccl" ]; then
		COUNT=$(${MY_CC} -o ${out_}.o -c ${CFLAGS} $incs_ $2 2>&1|grep "error"|wc -l)
		COUNT=$(${MY_CC} -o ${out_}.inter ${out_}.o $libs_ ${lib_} 2>&1|grep "error"|wc -l)
	elif [ "$1" = "cppc" ]; then
		COUNT=$(${MY_CPP} -o ${out_}.o -c ${CPPFLAGS} $incs_ $2 2>&1|grep "error"|wc -l)
	elif [ "$1" = "cppl" ]; then
		COUNT=$(${MY_CPP} -o ${out_}.inter ${out_}.o $libs_ ${lib_} 2>&1|grep "error"|wc -l)
	elif [ "$1" = "cppccppl" ]; then
		COUNT=$(${MY_CPP} -o ${out_}.o -c ${CPPFLAGS} $incs_ $2 2>&1|grep "error"|wc -l)
		COUNT=$(${MY_CPP} -o ${out_}.inter ${out_}.o $libs_ ${lib_} 2>&1|grep "error"|wc -l) 
	fi

	if [ "$COUNT" -eq 0 ]; then
		if [[ $INCS != *"$incs_"* ]]; then 
			INCS=$incs_
			INCSQ=$incsq_
		fi
		if [[ $LPATHS != *"$libs_"* ]]; then LPATHS=$libs_; fi
		if [ "$3" != "" ]; then add_lib "$3"; fi
	fi
}

# Generate a static library artifact
function b_static_lib() {
	prog="$1"
	out_file="$2"
	pushd "$SB_OUTDIR" > /dev/null
	#echo `pwd`
	exe "" ${prog} rcs .bin/${out_file} ${all_objs_}
	popd > /dev/null
}

# Generate a shared library artifact
function b_shared_lib() {
	prog="$1"
	out_file="$2"
	deps="$3"
	pushd "$SB_OUTDIR" > /dev/null
	#echo `pwd`
	if defined "OS_DARWIN"; then
		exe "" ${prog} -dynamiclib -L.bin/ $LPATHS ${all_objs_} -o .bin/${out_file} $deps
	else
		exe "" ${prog} -shared -L.bin/ $LPATHS ${all_objs_} -o .bin/${out_file} $deps
	fi
	popd > /dev/null
}

# Generate a binary artifact
function b_binary() {
	prog="$1"
	out_file="$2"
	deps="$3"
	pushd "$SB_OUTDIR" > /dev/null
	exe ""  ${prog} -L.bin/ $LPATHS ${all_objs_} -o .bin/${out_file} $deps
	popd > /dev/null
}

bg_pids=""
# Compile a single file usign the said flags and skip andy exclude directories/files
function _b_compile_single() {
	file="$1"
	if [ "$file" = "" ]; then
		return
	fi
	tincs="$2"
	if [ "$IS_RUN" -eq 0 ]; then
		echo "Got kill signal...shutting down...";
		exit 1
	fi
	fdir="$(dirname "${file}")"
	ffil="$(basename "${file}")"
	ofln=$ffil
	if [[ ${EXC_SRC} == *";$fdir;"* ]]; then
		#echo "Skipping file ${file}..."
		return
	fi
	if [[ ${EXC_FLS} == *";$fdir/$ffil;"* ]]; then
		#echo "Skipping file ${file}..."
		return
	fi

	if [ "$BUILD_SYS" = "bazel" ]; then
		BZL_SRCES+="\"$file\","
		if [[ $file == *".h" ]] || [[ $file == *".hh" ]] || [[ $file == *".hpp" ]]; then
			BZL_HDRS+="\"$file\","
		fi
		return
	elif [ "$BUILD_SYS" = "buck2" ]; then
		if [[ $file == *".h" ]] || [[ $file == *".hh" ]] || [[ $file == *".hpp" ]]; then
			BCK2_HDRS+="\"$file\","
		else
			BCK2_SRCES+="\"$file\","
		fi
		return
	fi

	count=$((count+1))
	fdir=$(remove_relative_path ${fdir})
	if [ ! -d "$SB_OUTDIR/${fdir}" ];then
		mkdir -p "$SB_OUTDIR/${fdir}"
	fi
	ffil="$fdir/$ffil"
	#mkdir -p -- "$(dirname -- "$file")"
	
	cflags_=
	if [ "$BUILD_TYPE" = "cpp" ]; then
		cflags_="${CPPFLAGS}";
	else
		cflags_="${CFLAGS}";
	fi
	if [[ "$ffil" =~ ^./ ]]; then
		ffil=$(echo "${ffil#./}")
	fi

	sbdir_="$SB_OUTDIR/"
	if [[ "$sbdir_" = "./" ]]; then
		sbdir_=""
	fi
	add_fpic=
	chkfil=
	if [ "$isshared" = 1 ]; then 
		add_fpic="-fPIC"
		all_objs_+="${ffil}.fo "
		all_absobjs_+="${sbdir_}${ffil}.fo "
		chkfil="${sbdir_}${ffil}.fo"
	else
		all_objs_+="${ffil}.o "
		all_absobjs_+="${sbdir_}${ffil}.o "
		chkfil="${sbdir_}${ffil}.o"
	fi	
	if [ ! -f "$chkfil" ]; then
		bexe "Compiling ${file}..." ${compiler} -MD -MP -MF "${sbdir_}${ffil}.d" ${add_fpic} -c ${cflags_} ${tincs} -o ${chkfil} ${file}
		showprogress 1 "${ofln}"
	else
		showprogress 1 "${ofln}"
	fi
	if [ "$count" = "$NUM_CPU" ]; then
		wait_bexe
		count=0
	fi
}

count=0
isshared=1
srces_=
files=
total_srces_=
# The compilation function, also creates dependency files and tracks whether to compile the file 
# or not based on the file modified datetime
function b_prepare_sources() {
	compiler="$1"
	src_="$2"
	ext="$3"
	includes=
	sources="$5"
	exe_key="$6"
	tincs="$INCS"
	tincsq="$PINCSQ"

	srces_=
	files=
	if [ "$sources" = "" ]; then
		for ex_ in ${ext//,/ }
		do
			if [ "$ex_" != "" ]; then
				srces_+=$(find ${src_} -type f -name "$ex_" -print|xargs ls -ltr|awk '{print $9"|"$6$7$8}')
				srces_+=$'\n'
				files+=$(find ${src_} -type f -name "$ex_")
				files+=$'\n'
			fi
		done
	else
		sources_=(${sources//,/ })
		srces_=$(find ${sources_} -type f -print|xargs ls -ltr|awk '{print $9"|"$6$7$8}')
	fi

	if [ "$BUILD_SYS" = "bazel" ] || [ "$BUILD_SYS" = "buck2" ]; then
		for idir in ${4//,/ }
		do
			for ex_ in ${ext//,/ }
			do
				if [ "$ex_" != "" ]; then
					srces_+=$(find ${idir} -type f -name "$ex_" -print|xargs ls -ltr|awk '{print $9"|"$6$7$8}')
					srces_+=$'\n'
					files+=$(find ${idir} -type f -name "$ex_")
					files+=$'\n'
				fi
			done
		done
	fi

	kvset "SH_$(get_key $exe_key)" "$srces_"
	total_srces_=$(cat $KV_USER_DIR/SH_$(get_key $exe_key)|wc -l)
}
function b_compile() {
	compiler="$1"
	src_="$2"
	ext="$3"
	includes=
	sources="$5"
	exe_key="$6"
	tincs="$INCS"
	tincsq="$PINCSQ"
	
	if [ "$sources" != "" ]; then
		sources_=(${sources//,/ })
	fi
	if [ "$4" = "" ] && [ "$src_" != "" ]; then
		includes=$(find ${src_} -type f \( -name '*.h' -o -name '*.hh' -o -name '*.hpp' \) | sed -r 's|/[^/]+$||' |sort |uniq); 
	elif [ "$4" != "" ]; then
		for idir in ${4//,/ }
		do
			if [ "$IS_RUN" -eq 0 ]; then echo "got kill signal...shutting down..."; wait; exit 1; fi
			if [[ ${EXC_SRC} == *";$idir;"* ]]; then
				continue
			fi
			tincs+="-I$idir "
			tincsq+="\"-I$idir\","
		done
	fi
	
	#src_=$(remove_relative_path ${src_})
	#if [ ! -d "$SB_OUTDIR/${src_}" ];then
	#	mkdir -p $SB_OUTDIR/${src_}
	#fi
	#echo "${EXC_SRC}"
	if [ "$includes" != "" ]; then
		while IFS= read -r idir
		do
			if [ "$IS_RUN" -eq 0 ]; then echo "got kill signal...shutting down..."; wait; exit 1; fi
			if [[ ${EXC_SRC} == *";$idir;"* ]]; then
				continue
			fi
			tincs+="-I$idir "
			tincsq+="\"-I$idir\","
		done <<< "$includes"
	fi
	if [ "$4" = "" ]; then 
		INCS=$tincs 
		PINCSQ=$tincsq
	fi
	#echo "$tincs"
	#echo "Count: $(echo -n "$1" | wc -l)"
	all_objs_=
	all_absobjs_=
	count=0
	
	if [ "$sources" = "" ]; then
		while IFS= read -r file
		do
			if [ "$file" != "" ]; then
				_b_compile_single "$file" "$tincs"
			fi
		done <<< "$files"
	else
		for file in ${sources//,/ }
		do
			if [ "$file" != "" ]; then
				_b_compile_single "$file" "$tincs"
			fi
		done
	fi
	if [ "$count" -gt 0 ]; then
		wait_bexe
	fi
	#if [ "$BUILD_SYS" = "bazel" ]; then
	#	BZL_SRCES="$BZL_SRCES"
	#elif [ "$BUILD_SYS" = "buck2" ]; then
	#	BCK2_SRCES="$BCK2_SRCES"
	#fi
	#echo $all_objs_
}

# Build the provided include directories & source files and generate requested artifacts (c_cpp specific only)
function set_inc_src_files() {
	if [ "$SB_OUTDIR" = "" ]; then echo "Please set output directory first..." && exit 1; fi

	inc_="$1"
	srces_="$2"
	src_out_="$3"
	src_deps_="$4"
	shift
	shift
	set_src "" "$src_out_" "$src_deps_" "$inc_" "$srces_"
}

# Build the provided include directories & source directories and generate requested artifacts (c_cpp specific only)
function set_inc_src() {
	if [ "$SB_OUTDIR" = "" ]; then echo "Please set output directory first..." && exit 1; fi
	
	inc_="$1"
	src_="$2"
	src_out_="$3"
	src_deps_="$4"
	shift
	set_src "$src_" "$src_out_" "$src_deps_" "$inc_"
}

function do_set_src() {
	if [ "$SB_OUTDIR" = "" ]; then echo "Please set output directory first..." && exit 1; fi
	
	src_="$1"
	src_out_="$2"
	src_deps_="$3"
	src_incs_="$4"
	src_files_="$5"
	
	if [ "$1" = "" ] && [ "$src_files_" = "" ]
	then
		echo "Blank source directory provided ----"
		exit 1;
	fi

	if [ ! -d "$src_" ]; then
		if [ "$src_files_" = "" ]; then
			echo "Invalid source directory $src_"
			exit 1;
		fi
	fi
	
	if [ "$src_out_" = "" ]; then
		echo "Build artifact name cannot be empty"
		exit 1;
	fi
	src_type="${src_out_:0:7}"
	if [[ "$src_type" != "binary:" ]] && [[ "$src_type" != "shared:" ]] && [[ "$src_type" != "static:" ]] && [[ "$src_type" != "stared:" ]]; then
		echo "Invalid Build output format [$src_out_], should be of format (binary|static|shared|stared):<name>"
		exit 1;
	fi

	if [ "$src_files_" != "" ]; then
		for sf_ in ${src_files_//,/ }
		do
			if [ ! -f "$sf_" ]; then
				echo "Non-existant source file specified...$sf_"
			fi
		done
	fi

	if [ "$IS_RUN" -eq 0 ]; then echo "Got kill signal...shutting down shellb..."; exit 1; fi
	do_build "$src_" "$src_out_" "$src_deps_" "$src_incs_" "$src_files_"
}

function do_build() {
	if [ "$BUILD_TYPE" = "cpp" ]; then 
		b_cpp_build "$@"
	else 
		b_c_build "$@"
	fi
}

# Trigger a c build, first compilation and then followed by static library/shared library/binary creation
function b_c_build() {
	type_=${2%:*}
	if [ "$type_" = "static" ] || [ "$type_" = "stared" ] || [ "$type_" = "binary" ]; then
		isshared=0
	else
		isshared=1
	fi

	percent_denom=$((percent_denom+5))
	if [ "$type_" = "stared" ]; then
		percent_denom=$((percent_denom+5))
	fi

	ext__="*.c"
	if [ "$BUILD_SYS" = "bazel" ]; then
		BZL_SRCES=""
		BZL_HDRS=""
		#PINCSQ="$PINCSD"
		ext__="*.c,*.h,*.hpp,*.hh"
	elif [ "$BUILD_SYS" = "buck2" ]; then
		BCK2_SRCES=""
		BCK2_HDRS=""
		#PINCSQ="$PINCSD"
		ext__="*.c,*.h,*.hpp,*.hh"
	fi

	b_prepare_sources "${MY_CC}" "$1" "$ext__" "$4" "$5" "$2"
	percent_denom=$((percent_denom+total_srces_))

	if [ "$type_" = "stared" ]; then
		percent_denom=$((percent_denom+total_srces_))
	fi

	#echo "$total_srces_ - $percent_numer of $percent_denom"

	if [ "$is_init_progress_done" = 0 ]; then
		#for do_config
		showprogress 5 "Config Setup..."

		#for do_config
		showprogress "$percent_checks" "Config Checks..."

		is_init_progress_done=1
	fi

	b_compile "${MY_CC}" "$1" "$ext__" "$4" "$5" "$2"
	
	if [ "$type_" = "" ]; then
		echo "Please specify Build output type, static, shared, stared or binary)"
		exit 1
	fi
	deps=
	elibs=
	for ilib in ${3//,/ }
	do
		if [ "$ilib" != "" ]; then 
			if [ "$BUILD_SYS" = "emb" ]; then
				deps+="-l$ilib "
			else
				elibs+="\"-l$ilib\","
				tmp=$(get_key $ilib)
				tmp=$(kvget "BN_$tmp")
				if [ "$tmp" = "" ]; then
					deps+="\"$ilib\","
				else
					deps+="\"$tmp\","
					if [ "$BUILD_SYS" = "bazel" ]; then
						tmp=$(get_key $ilib-inc)
						tmp=$(kvget "BN_$tmp")
						deps+="\"$tmp\","
					fi
				fi
			fi
		fi
		: #echo "dependency -- $ilib"
	done

	out_file_="${2#*:}"
	l_paths+="-L$bld_src "

	if [ "$BUILD_SYS" = "bazel" ]; then
		BZL_SRC_NAME="$out_file_"
		bzl_gen_build_file "$1" "$type_" "$deps" "$elibs" "$4"
		return
	elif [ "$BUILD_SYS" = "buck2" ]; then
		BCK2_SRC_NAME="$out_file_"
		bck2_gen_build_file "$1" "$type_" "$deps" "" "$4"
		return
	fi
	#Use the below key/value pair to add exact lib file path to the dependent lpaths
	#kvset "SH_$(get_key $out_file_)" "$bld_src"
	if [ "$type_" != "binary" ]; then 
		out_file_="lib${out_file_}"; 
	fi

	if [ "$type_" = "static" ]; then
		b_static_lib "${MY_AR}" "${out_file_}.${STLIB_EXT}" "$LIBS$deps"
		showprogress 5 "${out_file_}.${STLIB_EXT}.."
	elif [ "$type_" = "binary" ]; then
		b_binary "${MY_CC}" "${out_file_}" "$LIBS$deps"
		showprogress 5 "${out_file_}.."
	elif [ "$type_" = "shared" ]; then
		b_shared_lib "${MY_CC}" "${out_file_}.${SHLIB_EXT}" "$LIBS$deps"
		showprogress 5 "${out_file_}.${SHLIB_EXT}.."
	elif [ "$type_" = "stared" ]; then
		b_static_lib "${MY_AR}" "${out_file_}.${STLIB_EXT}" "$LIBS$deps"
		showprogress 5 "${out_file_}.${STLIB_EXT}.."
		rm -f ${all_absobjs_}
		isshared=1
		b_compile "${MY_CC}" "$1" "$ext__" "$4" "$5" "$2"
		b_shared_lib "${MY_CC}" "${out_file_}.${SHLIB_EXT}" "$LIBS$deps"
		showprogress 5 "${out_file_}.${SHLIB_EXT}.."
	fi
}

is_init_progress_done=0
# Trigger a c++ build, first compilation and then followed by static library/shared library/binary creation
function b_cpp_build() {
	type_=${2%:*}
	if [ "$type_" = "static" ] || [ "$type_" = "stared" ] || [ "$type_" = "binary" ]; then
		isshared=0
	else
		isshared=1
	fi

	percent_denom=$((percent_denom+5))
	if [ "$type_" = "stared" ]; then
		percent_denom=$((percent_denom+5))
	fi

	ext__="*.cpp"
	if [ "$BUILD_SYS" = "bazel" ]; then
		BZL_SRCES=""
		BZL_HDRS=""
		#PINCSQ="$PINCSD"
		ext__="*.cpp,*.h,*.hpp,*.hh,*.cc,*.cxx"
	elif [ "$BUILD_SYS" = "buck2" ]; then
		BCK2_SRCES=""
		BCK2_HDRS=""
		#PINCSQ="$PINCSD"
		ext__="*.cpp,*.h,*.hpp,*.hh,*.cc,*.cxx"
	fi

	b_prepare_sources "${MY_CPP}" "$1" "$ext__" "$4" "$5" "$2"
	percent_denom=$((percent_denom+total_srces_))

	if [ "$type_" = "stared" ]; then
		percent_denom=$((percent_denom+total_srces_))
	fi

	#echo "$total_srces_ - $percent_numer of $percent_denom"

	if [ "$is_init_progress_done" = 0 ]; then
		#for do_config
		showprogress 5 "Config Setup..."

		#for do_config
		showprogress "$percent_checks" "Config Checks..."

		is_init_progress_done=1
	fi
	
	b_compile "${MY_CPP}" "$1" "$ext__" "$4" "$5" "$2"

	if [ "$type_" = "" ]; then
		echo "Please specify Build output type, static, shared, stared or binary)"
		exit 1
	fi
	deps=
	elibs=
	for ilib in ${3//,/ }
	do
		if [ "$ilib" != "" ]; then 
			if [ "$BUILD_SYS" = "emb" ]; then
				deps+="-l$ilib "
			else
				elibs+="\"-l$ilib\","
				tmp=$(get_key $ilib)
				tmp=$(kvget "BN_$tmp")
				if [ "$tmp" = "" ]; then
					deps+="\"$ilib\","
				else
					deps+="\"$tmp\","
					if [ "$BUILD_SYS" = "bazel" ]; then
						tmp=$(get_key $ilib-inc)
						tmp=$(kvget "BN_$tmp")
						deps+="\"$tmp\","
					fi
				fi
			fi
		fi
		: #echo "dependency -- $ilib"
	done

	out_file_="${2#*:}"
	l_paths+="-L$bld_src "

	if [ "$BUILD_SYS" = "bazel" ]; then
		BZL_SRC_NAME="$out_file_"
		bzl_gen_build_file "$1" "$type_" "$deps" "$elibs" "$4"
		return
	elif [ "$BUILD_SYS" = "buck2" ]; then
		BCK2_SRC_NAME="$out_file_"
		bck2_gen_build_file "$1" "$type_" "$deps" "" "$4"
		return
	fi

	#Use the below key/value pair to add exact lib file path to the dependent lpaths
	#kvset "SH_$(get_key $out_file_)" "$bld_src"
	if [ "$type_" != "binary" ]; then 
		out_file_="lib${out_file_}"; 
	fi

	if [ "$type_" = "static" ]; then
		#delete existing object files and compile without fpic 
		b_static_lib "${MY_AR}" "${out_file_}.${STLIB_EXT}" "$LIBS$deps"
		showprogress 5 "${out_file_}.${STLIB_EXT}.."
	elif [ "$type_" = "binary" ]; then
		b_binary "${MY_CPP}" "${out_file_}" "$LIBS$deps"
		showprogress 5 "${out_file_}.."
	elif [ "$type_" = "shared" ]; then
		b_shared_lib "${MY_CPP}" "${out_file_}.${SHLIB_EXT}" "$LIBS$deps"
		showprogress 5 "${out_file_}.${SHLIB_EXT}.."
	elif [ "$type_" = "stared" ]; then
		b_static_lib "${MY_AR}" "${out_file_}.${STLIB_EXT}" "$LIBS$deps"
		showprogress 5 "${out_file_}.${STLIB_EXT}.."
		#echo -e "rm -f ${all_absobjs_}"
		#rm -f ${all_absobjs_}
		isshared=1
		b_compile "${MY_CPP}" "$1" "$ext__" "$4" "$5" "$2"
		b_shared_lib "${MY_CPP}" "${out_file_}.${SHLIB_EXT}" "$LIBS$deps"
		showprogress 5 "${out_file_}.${SHLIB_EXT}.."
	fi
}

all_objs_=
src_=
l_paths=

function b_init() {
	#echo $MY_CC
	if [ "$BUILD_SYS" = "emb" ]; then
		:
	elif [ "$BUILD_SYS" = "bazel" ]; then
		cp snippets/c_cpp/bazel/BUILD.bazel.tem .shellb/BUILD.bazel
		cp snippets/c_cpp/bazel/*.bzl snippets/c_cpp/bazel/BUILD.macssl snippets/c_cpp/bazel/BUILD.usrlocal snippets/c_cpp/bazel/WORKSPACE.bazel .shellb/
	fi
}

function b_test() {
	incs_=$INCS
	libs_=$LPATHS
	if [ "$EX_DIR1" != "" ] && [ -d "$EX_DIR1" ] && [ "$EX_DIR2" != "" ] && [ -d "$EX_DIR2" ]; then
		if [ "$1" = "cccl" ] || [ "$1" = "cppccppl" ]; then
			incs_+="-I$EX_DIR1 "
			libs_+="-L$EX_DIR2 "
		elif [ "$1" = "cc" ] || [ "$1" = "cppc" ]; then
			incs_+="-I$EX_DIR1 "
		elif [ "$1" = "cl" ] || [ "$1" = "cppl" ]; then
			libs_+="-L$EX_DIR2 "
		fi
	elif [ "$EX_DIR1" != "" ] && [ -d "$EX_DIR1" ]; then
		if [ "$1" = "cc" ] || [ "$1" = "cppc" ]; then
			incs_+="-I$EX_DIR1 "
		elif [ "$1" = "cl" ] || [ "$1" = "cppl" ]; then
			libs_+="-L$EX_DIR1 "
		fi
	elif [ "$EX_DIR2" != "" ] && [ -d "$EX_DIR2" ]; then
		if [ "$1" = "cc" ] || [ "$1" = "cppc" ]; then
			incs_+="-I$EX_DIR2 "
		elif [ "$1" = "cl" ] || [ "$1" = "cppl" ]; then
			libs_+="-L$EX_DIR2 "
		fi
	fi
	out_=$(echo ${2} | sed -e "s|[^a-zA-Z0-9]||g")
	lib_=
	if [ "$3" != "" ]; then lib_="-l$3"; fi
	if [ "$BUILD_SYS" = "emb" ]; then
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
	elif [ "$BUILD_SYS" = "bazel" ]; then
		if [ "$1" = "cl" ] || [ "$1" = "cccl" ] || [ "$1" = "cppl" ] || [ "$1" = "cppccppl" ]; then
			if [ "$3" != "" ]; then sed -i'' -e "s|__LIB__NAME__|$3|g" BUILD.bazel; fi
		fi
		COUNT=$(bazel build :${out_} 2>&1|grep "FAILED: "|wc -l)
		if [ "$1" = "cl" ] || [ "$1" = "cccl" ]; then
			COUNT=$(${MY_CC} -o .inter bazel-bin/lib${out_}.a $libs_ ${lib_} 2>&1|grep "error"|wc -l)
		elif [ "$1" = "cppl" ] || [ "$1" = "cppccppl" ]; then
			COUNT=$(${MY_CPP} -o .inter bazel-bin/lib${out_}.a $libs_ ${lib_} 2>&1|grep "error"|wc -l)
		fi
	fi

	if [ "$COUNT" -eq 0 ]; then
		if [[ $INCS != *"$incs_"* ]]; then INCS=$incs_; fi
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
	exe "" ${prog} -shared -L.bin/ $LPATHS ${all_objs_} -o .bin/${out_file} $deps
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

# Compile a single file usign the said flags and skip andy exclude directories/files
function _b_compile_single() {
	file="$1"
	tincs="$2"
	if [ "$IS_RUN" -eq 0 ]; then
		echo "Got kill signal...shutting down...";
		exit 1
	fi
	fdir="$(dirname "${file}")"
	ffil="$(basename "${file}")"
	if [[ ${EXC_SRC} == *";$fdir;"* ]]; then
		echo "Skipping file ${file}..."
		return
	fi
	if [[ ${EXC_FLS} == *";$fdir/$ffil;"* ]]; then
		echo "Skipping file ${file}..."
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
	all_objs_+="${ffil}.o "
	sbdir_="$SB_OUTDIR/"
	if [[ "$sbdir_" = "./" ]]; then
		sbdir_=""
	fi
	if [ ! -f "${sbdir_}${ffil}.o" ]; then
		bexe "Compiling ${file}..." ${compiler} -MD -MP -MF "${sbdir_}${ffil}.d" -c ${cflags_} ${tincs} -o ${sbdir_}${ffil}.o ${file}
	fi
	if [ "$count" = "$NUM_CPU" ]; then
		wait
		count=0
	fi
}

count=0
# The compilation function, also creates dependency files and tracks whether to compile the file 
# or not based on the file modified datetime
function b_compile() {
	compiler="$1"
	src_="$2"
	ext="$3"
	includes=
	sources="$5"
	exe_key="$6"
	tincs="$INCS"

	srces_=
	files=
	if [ "$sources" = "" ]; then
		for ex_ in ${ext//,/ }
		do
			if [ "$ex_" != "" ]; then
				srces_+=$(find ${src_} -type f -name "$ex_" -print|xargs ls -ltr|awk '{print $9"|"$6$7$8}')
				files+=$(find ${src_} -type f -name "$ex_")
			fi
		done
	else
		sources_=(${sources//,/ })
		srces_=$(find ${sources_} -type f -print|xargs ls -ltr|awk '{print $9"|"$6$7$8}')
	fi
	if [ "$4" = "" ] && [ "$src_" != "" ]; then
		includes=$(find ${src_} -type f \( -name '*.h' -o -name '*.hh' \) | sed -r 's|/[^/]+$||' |sort |uniq); 
	elif [ "$4" != "" ]; then
		for idir in ${4//,/ }
		do
			if [ "$IS_RUN" -eq 0 ]; then echo "got kill signal...shutting down..."; wait; exit 1; fi
			if [[ ${EXC_SRC} == *";$idir;"* ]]; then
				continue
			fi
			tincs+="-I$idir "
		done
	fi
	kvset "SH_$(get_key $exe_key)" "$srces_"
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
		done <<< "$includes"
	fi
	if [ "$4" = "" ]; then INCS=$tincs; fi
	#echo "$tincs"
	#echo "Count: $(echo -n "$1" | wc -l)"
	all_objs_=
	count=0
	if [ "$sources" = "" ]; then
		while IFS= read -r file
		do
			_b_compile_single "$file" "$tincs"
		done <<< "$files"
	else
		for file in ${sources//,/ }
		do
			_b_compile_single "$file" "$tincs"
		done
	fi
	if [ "$count" -gt 0 ]; then
		wait
	fi
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
		echo "Invalid source directory ----"
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
	b_compile "${MY_CC}" "$1" "*.c" "$4" "$5" "$2"
	type_=${2%:*}
	if [ "$type_" = "" ]; then
		echo "Please specify Build output type, static, shared, stared or binary)"
		exit 1
	fi
	deps=
	for ilib in ${3//,/ }
	do
		if [ "$ilib" != "" ]; then deps+="-l$ilib "; fi
		echo "dependency -- $ilib"
	done

	out_file_="${2#*:}"
	l_paths+="-L$bld_src "
	#Use the below key/value pair to add exact lib file path to the dependent lpaths
	#kvset "SH_$(get_key $out_file_)" "$bld_src"
	if [ "$type_" != "binary" ]; then out_file_="lib${out_file_}"; fi

	if [ "$type_" = "static" ]; then
		b_static_lib "${MY_AR}" "${out_file_}.${STLIB_EXT}" "$LIBS$deps"
	elif [ "$type_" = "shared" ]; then
		b_shared_lib "${MY_CC}" "${out_file_}.${SHLIB_EXT}" "$LIBS$deps"
	elif [ "$type_" = "stared" ]; then
		b_static_lib "${MY_AR}" "${out_file_}.${STLIB_EXT}" "$LIBS$deps"
		b_shared_lib "${MY_CC}" "${out_file_}.${SHLIB_EXT}" "$LIBS$deps"
	elif [ "$type_" = "binary" ]; then
		b_binary "${MY_CC}" "${out_file_}" "$deps"
	fi
}

# Trigger a c++ build, first compilation and then followed by static library/shared library/binary creation
function b_cpp_build() {
	b_compile "${MY_CPP}" "$1" "*.cpp" "$4" "$5" "$2"
	type_=${2%:*}
	if [ "$type_" = "" ]; then
		echo "Please specify Build output type, static, shared, stared or binary)"
		exit 1
	fi
	deps=
	for ilib in ${3//,/ }
	do
		if [ "$ilib" != "" ]; then deps+="-l$ilib "; fi
		echo "dependency -- $ilib"
	done

	out_file_="${2#*:}"
	l_paths+="-L$bld_src "
	#Use the below key/value pair to add exact lib file path to the dependent lpaths
	#kvset "SH_$(get_key $out_file_)" "$bld_src"
	if [ "$type_" != "binary" ]; then out_file_="lib${out_file_}"; fi

	if [ "$type_" = "static" ]; then
		b_static_lib "${MY_AR}" "${out_file_}.${STLIB_EXT}" "$LIBS$deps"
	elif [ "$type_" = "shared" ]; then
		b_shared_lib "${MY_CPP}" "${out_file_}.${SHLIB_EXT}" "$LIBS$deps"
	elif [ "$type_" = "stared" ]; then
		b_static_lib "${MY_AR}" "${out_file_}.${STLIB_EXT}" "$LIBS$deps"
		b_shared_lib "${MY_CPP}" "${out_file_}.${SHLIB_EXT}" "$LIBS$deps"
	elif [ "$type_" = "binary" ]; then
		b_binary "${MY_CPP}" "${out_file_}" "$LIBS$deps"
	fi
}

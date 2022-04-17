
function b_init() {
	#echo $MY_CC
	if [ "$BUILD_SYS" = "emb" ]; then
		:
	elif [ "$BUILD_SYS" = "bazel" ]; then
		cp snippets/BUILD.bazel.tem .shellb/BUILD.bazel
		cp snippets/*.bzl snippets/BUILD.macssl snippets/BUILD.usrlocal snippets/WORKSPACE.bazel .shellb/
	fi
}

#$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@ -MM -MF $@.d -- for generating dependencies
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
			COUNT=$(${MY_CC} -o $out_.o -c $2 $incs_ 2>&1|grep "error"|wc -l)
		elif [ "$1" = "cl" ]; then
			COUNT=$(${MY_CC} -o ${out_}.inter ${out_}.o $libs_ ${lib_} 2>&1|grep "error"|wc -l)
		elif [ "$1" = "cccl" ]; then
			COUNT=$(${MY_CC} -o ${out_}.o -c $2 $incs_ 2>&1|grep "error"|wc -l)
			COUNT=$(${MY_CC} -o ${out_}.inter ${out_}.o $libs_ ${lib_} 2>&1|grep "error"|wc -l)
		elif [ "$1" = "cppc" ]; then
			COUNT=$(${MY_CPP} -o ${out_}.o -c $2 $incs_ 2>&1|grep "error"|wc -l)
		elif [ "$1" = "cppl" ]; then
			COUNT=$(${MY_CPP} -o ${out_}.inter ${out_}.o $libs_ ${lib_} 2>&1|grep "error"|wc -l)
		elif [ "$1" = "cppccppl" ]; then
			COUNT=$(${MY_CPP} -o ${out_}.o -c $2 $incs_ 2>&1|grep "error"|wc -l)
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

	if [ "$COUNT" = "0" ]; then
		INCS=$incs_
		LPATHS+=$libs_
		if [ "$3" != "" ]; then add_lib "$3"; fi
	fi
}

function b_link() {
	compiler="$1"
	all_objs="$2"
	out_file="$3"
	deps="$LIBS $4"

	if [ "$LOG_MODE" = "1" ]; then
		exeml "Linking ${out_file}..." ${compiler} -o ${out_file} ${all_objs} $LPATHS $deps
	else
		exe ${compiler} -o ${out_file} ${all_objs} $LPATHS $deps
	fi
}

function b_compile() {
	compiler="$1"
	src_="$2"
	ext="$3"
	srces_=$(find ${src_} -type f -name "${ext}" -print|xargs ls -ltr|awk '{print $9"|"$6$7$8}')
	files="$(find ${src_} -type f -name "${ext}")"
	includes=$(find ${src_} -type f -name '*.h' | sed -r 's|/[^/]+$||' |sort |uniq)
	kvset "SH_$(get_key $src_)" "$srces_"
	src_=$(remove_relative_path ${src_})
	if [ ! -d "$SB_OUTDIR/${src_}" ];then
		mkdir -p $SB_OUTDIR/${src_}
	fi

	tincs="$INCS"
	while IFS= read -r idir
	do
		if [ "$IS_RUN" = "0" ]; then echo "got kill signal...shutting down..."; wait; exit 1; fi
		if [[ ${EXC_SRC} == *";$SB_OUTDIR/$idir;"* ]]; then
			continue
		fi
		tincs+="-I$idir "
	done <<< "$includes"
	INCS=$tincs
	#echo -e "$tincs"
	#echo "Count: $(echo -n "$1" | wc -l)"
	all_objs=
	count=0
	while IFS= read -r file
	do
		if [ "$IS_RUN" = "0" ]; then
			echo "got kill signal...shutting down...";
			break
		fi
		fdir="$(dirname "${file}")"
		ffil="$(basename "${file}")"
		if [[ ${EXC_SRC} == *";$SB_OUTDIR/$fdir;"* ]]; then
			continue
		fi
		count=$((count+1))
		fdir=$(remove_relative_path ${fdir})
		fdir="$SB_OUTDIR/${fdir}"
		if [ ! -d "$fdir" ];then
			mkdir -p $fdir
		fi
		ffil="$fdir/$ffil"
		mkdir -p -- "$(dirname -- "$file")"
		all_objs+="${ffil}.o "
		if [ "$LOG_MODE" = "1" ]; then
			exeml "Compiling ${file}..." ${compiler} -MD -MP -MF "${ffil}.d" -c ${CFLAGS} ${tincs} -o ${ffil}.o ${file}
		else
			exe ${compiler} -MD -MP -MF "${ffil}.d" -c ${CFLAGS} ${tincs} -o ${ffil}.o ${file}
		fi
		if [ "$count" = "$NUM_CPU" ]; then
			wait
			count=0
		fi
	done <<< "$files"
	echo $all_objs
}

function b_c_build() {
	c_compiler
	all_objs=$(b_compile "${MY_CC}" "$1" "*.c")
	if [ "$2" != "" ]; then
		:
	fi
	deps=
	while IFS=',' read -r ilib
	do
		deps+="-l$ilib "
		echo "dependency -- $ilib"
	done <<< "$3"
	b_link "${MY_CC}" "$all_objs" "lib$2.${SHLIB_EXT}" "$deps"
}

function b_cpp_build() {
	c_compiler
	all_objs=$(b_compile "${MY_CPP}" "$1" "*.cpp")
	if [ "$2" != "" ]; then
		:
	fi
	while IFS=',' read -r ilib
	do
		echo "dependency -- $ilib"
	done <<< "$3"
	b_link "${MY_CPP}" "$all_objs" "lib$2.${SHLIB_EXT}" "$deps"
}

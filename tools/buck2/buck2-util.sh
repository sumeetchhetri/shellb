
BCK2_SRCES=
BCK2_DEFINES=
BCK2_LINKOPTS=
BCK2_COPTS=
BCK2_DEPS=
BCK2_HDRS=
BCK2_REPO_PATH=
BCK2_REPO_BUILD_FILE=
BCK2_REPO_HDRS=
BCK2_SRC_PATH=
BCK2_SRC_NAME=
BCK2_SRC_NAME_R=
BCK2_EXT_INCS=
BCK2_EX_FLAGS="\"-I/usr/local/include\","
count=0

bck2_bin_build_=$(cat <<-END

cxx_binary(
    name = "@BCK2_SRC_NAME@",
    srcs = [@BCK2_SRCES@],
    linker_flags = [@BCK2_LINKOPTS@],
    include_directories = [@BCK2_COPTS@],
    compiler_flags = [@BCK2_EX_FLAGS@],
    deps = [@BCK2_DEPS@],
    visibility = ["PUBLIC"]
)

END
)

bck2_libst_build_=$(cat <<-END

cxx_library(
    name = "@BCK2_SRC_NAME@",
    srcs = [@BCK2_SRCES@],
    linker_flags = [@BCK2_LINKOPTS@],
    link_style = "static",
    include_directories = [@BCK2_COPTS@],
    compiler_flags = [@BCK2_EX_FLAGS@],
    deps = [@BCK2_DEPS@],
    exported_headers = [@BCK2_HDRS@],
    visibility = ["PUBLIC"]
)

END
)

bck2_libso_build_=$(cat <<-END
cxx_library(
    name = "@BCK2_SRC_SO_NAME@",
    soname = "@BCK2_SRC_SO_NAME@",
    srcs = [@BCK2_SRCES@],
    linker_flags = [@BCK2_LINKOPTS@],
    link_style = "shared",
    include_directories = [@BCK2_COPTS@],
    compiler_flags = [@BCK2_EX_FLAGS@],
    deps = [@BCK2_DEPS@],
    exported_headers = [@BCK2_HDRS@],
    visibility = ["PUBLIC"]
)

END
)

bck2_libstso_build_=$(cat <<-END
cxx_library(
    name = "@BCK2_SRC_NAME@",
    srcs = [@BCK2_SRCES@],
    linker_flags = [@BCK2_LINKOPTS@],
    link_style = "static",
    include_directories = [@BCK2_COPTS@],
    compiler_flags = [@BCK2_EX_FLAGS@],
    deps = [@BCK2_DEPS@],
    exported_headers = [@BCK2_HDRS@],
    visibility = ["PUBLIC"]
)

cxx_library(
    name = "@BCK2_SRC_SO_NAME@",
    soname = "@BCK2_SRC_SO_NAME@",
    srcs = [@BCK2_SRCES@],
    linker_flags = [@BCK2_LINKOPTS@],
    link_style = "shared",
    include_directories = [@BCK2_COPTS@],
    compiler_flags = [@BCK2_EX_FLAGS@],
    deps = [@BCK2_DEPS@],
    exported_headers = [@BCK2_HDRS@],
    visibility = ["PUBLIC"]
)

END
)

bck2_bconfig_build_=$(cat <<-END
[project]
  ignore = .git

[repositories]
  root = .
  prelude = prelude
  toolchains = toolchains
  none = none

[repository_aliases]
  config = prelude
  fbcode = none
  fbsource = none
  buck = none

[parser]
  default_build_file_syntax = SKYLARK
  target_platform_detector_spec = target:root//...->prelude//platforms:default

[cxx]
  cxxflags = @CPPFLAGS@
  should_remap_host_platform = true
  ; untracked_headers = error
  untracked_headers_whitelist = /usr/include/.*, /usr/local/include/.*, /usr/lib/.*, @BCK2_EXT_INCS@
  ldflags = -L/usr/local/lib

END
)

bck2_prebuilt_dep_build_=$(cat <<-END
prebuilt_cxx_library(
  name = '@DEP@', 
  header_namespace = '', 
  header_only = True, 
  exported_linker_flags = [
    '-l@DEP@', 
  ], 
)

END
)

BCK2_DONE_REPOS=
function bck2_gen_build_file() {
	BCK2_LINKOPTS="$LPATHSQ"
	BCK2_LINKOPTS="${BCK2_LINKOPTS%?}"
	BCK2_COPTS="${PINCSQ%?}"
	BCK2_SRCES="${BCK2_SRCES%?}"
	BCK2_HDRS="${BCK2_HDRS%?}"
	BCK2_DEPS="$3"
	ex5_=
	for ex5_ in ${CPPFLAGS// / }
	do
		if [[ $BCK2_EX_FLAGS != *"\"$ex5_\""* ]]; then
			BCK2_EX_FLAGS+="\"$ex5_\","
		fi
	done
	ex6_=
	for ex6_ in ${INCSQ//,/ }
	do
		if [[ $ex6_ = "../"* ]]; then
			if [[ $BCK2_EX_FLAGS != *"\"-I$ex6_\""* ]]; then
				BCK2_EX_FLAGS+="\"-I$ex6_\","
			fi
		fi
		if [[ $ex6_ != "/"* ]]; then
			continue
		fi
		if [[ $BCK2_DONE_REPOS = *"${ex6_} "* ]]; then
			continue
		fi
		BCK2_DONE_REPOS+="${ex6_} "
		if [[ $ex6_ != "/usr/include/"* ]] && [[ $ex6_ != "/usr/local/include/"* ]]; then
			BCK2_EXT_INCS+="$ex6_/.*, "
		fi
		if [[ $BCK2_EX_FLAGS != *"\"-I$ex6_\""* ]]; then
			BCK2_EX_FLAGS+="\"-I$ex6_\","
		fi
	done

	BCK2_DEPS="${BCK2_DEPS%?}"
	if [[ $BCK2_EX_FLAGS = *"," ]]; then
		BCK2_EX_FLAGS="${BCK2_EX_FLAGS%?}"
	fi
	BCK2_SRC_PATH="$1"
	
	src="$1"
	#BCK2_SRCES=${BCK2_SRCES//$1\//}
	if [ "$5" != "" ]; then
		for idir in ${5//,/ }
		do
			src1=`printf "%s\n%s\n" "$src" "$idir" | sed -e 'N;s/^\(.*\).*\n\1.*$/\1/'`
			#echo "$src -- $idir -- $src1"
			src="$src1"
			BCK2_COPTS+=",\"-I$idir\""
		done
		#BCK2_COPTS="${BCK2_COPTS%?}"
		#BCK2_HDRS=${BCK2_HDRS//$src/}
		#BCK2_SRCES=${BCK2_SRCES//$src/}
		#BCK2_COPTS=${BCK2_COPTS//$src/}
	else
		#BCK2_HDRS=${BCK2_HDRS//$src\//}
		#BCK2_SRCES=${BCK2_SRCES//$src\//}
		#BCK2_COPTS=${BCK2_COPTS//$src\//}
		:
	fi
	#BCK2_COPTS=${BCK2_COPTS//\"$src\"/}
	BCK2_COPTS=${BCK2_COPTS//\"-I/\"}
	#echo "$src"
	if [[ $src = *"/" ]]; then
		src="${src%?}"
	fi

	#kvset "BN_$(get_key $BCK2_SRC_NAME-inc)" "//$src:$BCK2_SRC_NAME-inc"
	if [ "$2" = "binary" ]; then
		printf "$bck2_bin_build_\n" > /tmp/.bck2_bin_build_
		kvset "BN_$(get_key $BCK2_SRC_NAME)" "//:$BCK2_SRC_NAME"
	elif [ "$2" = "shared" ]; then
		BCK2_SRC_SO_NAME="lib$BCK2_SRC_NAME.$SHLIB_EXT"
		printf "$bck2_libso_build_\n" > /tmp/.bck2_bin_build_
		kvset "BN_$(get_key $BCK2_SRC_NAME)" "//:$BCK2_SRC_SO_NAME"
	elif [ "$2" = "static" ]; then
		printf "$bck2_libst_build_\n" > /tmp/.bck2_bin_build_
		kvset "BN_$(get_key $BCK2_SRC_NAME)" "//:$BCK2_SRC_NAME"
	elif [ "$2" = "stared" ]; then
		BCK2_SRC_SO_NAME="lib$BCK2_SRC_NAME.$SHLIB_EXT"
		printf "$bck2_libstso_build_\n" > /tmp/.bck2_bin_build_
		kvset "BN_$(get_key $BCK2_SRC_NAME)" "//:$BCK2_SRC_SO_NAME"
	fi

	templatize "/tmp/.bck2_bin_build_" "/tmp/.bck2_bin_build__" "BCK2_EX_FLAGS,BCK2_SRC_NAME,BCK2_SRCES,BCK2_DEFINES,BCK2_LINKOPTS,BCK2_COPTS,BCK2_DEPS,BCK2_HDRS,SHLIB_EXT,BCK2_SRC_SO_NAME"
	cat /tmp/.bck2_bin_build__ >> "$DIR/BUCK"
}

function do_buck2_build() {
	printf "$bck2_bconfig_build_\n" > /tmp/.bck2_bconfig_build_
	templatize "/tmp/.bck2_bconfig_build_" /tmp/.bck2_bconfig_build___ "BCK2_EXT_INCS,CPPFLAGS"
	cat /tmp/.bck2_bconfig_build___ >> "$DIR/.buckconfig"
	ex7_=
	for ex7_ in ${1//,/ }
	do
		if [ "$ex7_" != "" ]; then
			tmp=$(get_key $ex7_)
			tmp=$(kvget "BN_$tmp")
			if [ "$tmp" != "" ]; then
				#buck2 build $tmp --show-full-output
				out_path=`buck2 build $tmp --show-full-output | cut -d' ' -f2-`
				echo "$out_path"
				if [ "$out_path" != "" ]; then
					exe "" cp -f "$out_path" $SB_OUTDIR/.bin
				fi
			fi
		fi
	done
}

function do_buck2_pre_build() {
	rm -rf prelude || true
	wget https://github.com/facebook/buck2-prelude/archive/refs/heads/main.zip && unzip main.zip && mv buck2-prelude-main prelude
	buck2 clean
	rm -f main.zip
	echo "" > "$DIR/.buckconfig"
	echo "" > "$DIR/BUCK"
}
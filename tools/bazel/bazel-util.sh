
BZL_SRCES=
BZL_DEFINES=
BZL_LINKOPTS=
BZL_COPTS=
BZL_DEPS=
BZL_HDRS=
BZL_REPO_PATH=
BZL_REPO_BUILD_FILE=
BZL_REPO_HDRS=
BZL_SRC_PATH=
BZL_SRC_NAME=
BZL_SRC_NAME_R=
count=0

bzl_bin_build_=$(cat <<-END
load("@rules_cc//cc:defs.bzl", "cc_binary")

cc_import(
    name = "@BZL_SRC_NAME@-inc",
    hdrs = glob(["**/*.h"]),
    visibility = ["//visibility:public"]
)

cc_binary(
    name = "@BZL_SRC_NAME@",
    srcs = [@BZL_SRCES@],
    local_defines = [@BZL_DEFINES@],
    linkopts = [@BZL_LINKOPTS@],
    copts = [@BZL_COPTS@],
    deps = [@BZL_DEPS@],
    visibility = ["//visibility:public"]
)

END
)

bzl_libst_build_=$(cat <<-END
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_import(
    name = "@BZL_SRC_NAME@-inc",
    hdrs = glob(["**/*.h"]),
    visibility = ["//visibility:public"]
)

cc_library(
    name = "@BZL_SRC_NAME@",
    srcs = [@BZL_SRCES@],
    local_defines = [@BZL_DEFINES@],
    linkopts = [@BZL_LINKOPTS@],
    copts = [@BZL_COPTS@],
    deps = [@BZL_DEPS@],
    hdrs = [@BZL_HDRS@],
    visibility = ["//visibility:public"]
)

END
)

bzl_libso_build_=$(cat <<-END
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_import(
    name = "@BZL_SRC_NAME@-inc",
    hdrs = glob(["**/*.h"]),
    shared_library = "lib@BZL_SRC_NAME@.@SHLIB_EXT@",
    visibility = ["//visibility:public"]
)

cc_binary(
    linkshared = True,
    name = "@BZL_SRC_SO_NAME@",
    srcs = [@BZL_SRCES@],
    local_defines = [@BZL_DEFINES@],
    linkopts = [@BZL_LINKOPTS@],
    copts = [@BZL_COPTS@],
    deps = [@BZL_DEPS@],
    visibility = ["//visibility:public"]
)

END
)

bzl_libstso_build_=$(cat <<-END
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_import(
    name = "@BZL_SRC_NAME@-inc",
    hdrs = glob(["**/*.h"]),
    shared_library = "lib@BZL_SRC_NAME@.@SHLIB_EXT@",
    visibility = ["//visibility:public"]
)

cc_binary(
    linkshared = True,
    name = "@BZL_SRC_SO_NAME@",
    srcs = [@BZL_SRCES@],
    local_defines = [@BZL_DEFINES@],
    linkopts = [@BZL_LINKOPTS@],
    copts = [@BZL_COPTS@],
    deps = [@BZL_DEPS@],
    visibility = ["//visibility:public"]
)

cc_library(
    name = "@BZL_SRC_NAME@",
    srcs = [@BZL_SRCES@],
    local_defines = [@BZL_DEFINES@],
    linkopts = [@BZL_LINKOPTS@],
    copts = [@BZL_COPTS@],
    deps = [@BZL_DEPS@],
    hdrs = [@BZL_HDRS@],
    visibility = ["//visibility:public"]
)

END
)

bzl_ws_local_repo_build_=$(cat <<-END
local_repository(
    name = "@BZL_SRC_NAME@-repo",
    path = "@BZL_SRC_PATH@",
)

END
)

bzl_ws_new_ext_repo_build_=$(cat <<-END
new_local_repository(
    name = "@BZL_SRC_NAME_R@-r",
    path = "@BZL_REPO_PATH@",
    build_file = "@BZL_REPO_BUILD_FILE@"
)

END
)

bzl_ws_local_repodef_build_=$(cat <<-END
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "@BZL_SRC_NAME_R@-rd",
    hdrs = @BZL_REPO_HDRS@,
    includes = [
        "."
    ],
    visibility = ["//visibility:public"]
)

END
)

BZL_DONE_REPOS=
function bzl_gen_build_file() {
	BZL_LINKOPTS="$LPATHSQ$4"
	BZL_LINKOPTS="${BZL_LINKOPTS%?}"
	BZL_COPTS="${PINCSQ%?}"
	BZL_SRCES="${BZL_SRCES%?}"
	BZL_HDRS="${BZL_HDRS%?}"
	BZL_DEPS="$3"
	count=1
	for ex_ in ${INCSQ//,/ }
	do
		if [[ $ex_ != "/"* ]]; then
			continue
		fi
		BZL_SRC_NAME_R=$(sanitize_var1 ${ex_})
		if [[ $BZL_SRC_NAME_R = "_"* ]]; then
			BZL_SRC_NAME_R="${BZL_SRC_NAME_R:1}"
		fi
		BZL_DEPS+="\"@${BZL_SRC_NAME_R}-r//:${BZL_SRC_NAME_R}-rd\","
		if [[ $BZL_DONE_REPOS = *"${ex_} "* ]]; then
			continue
		fi
		BZL_DONE_REPOS+="${ex_} "
		BZL_REPO_PATH="$ex_"
		BZL_REPO_BUILD_FILE="BUILD_$count.bazel"
		printf "$bzl_ws_new_ext_repo_build_\n" > /tmp/.bzl_ws_new_ext_repo_build_
		templatize "/tmp/.bzl_ws_new_ext_repo_build_" /tmp/.bzl_ws_new_ext_repo_build__ "BZL_SRC_NAME_R,BZL_REPO_PATH,BZL_REPO_BUILD_FILE,count"
		cat /tmp/.bzl_ws_new_ext_repo_build__ >> "$DIR/WORKSPACE.bazel"
		#BZL_REPO_HDRS="glob([\"**/*.h\"]) + glob([\"**/*.hh\"]) + glob([\"**/*.hpp\"])"
		#printf "$bzl_ws_local_repodef_build_\n" > /tmp/.bzl_ws_local_repo_build_
		#templatize "/tmp/.bzl_ws_local_repo_build_" "$DIR/$BZL_REPO_BUILD_FILE" "BZL_SRC_NAME_R,BZL_REPO_HDRS,count"
		count=$((count+1))
	done

	BZL_DEPS="${BZL_DEPS%?}"
	BZL_SRC_PATH="$1"
	printf "$bzl_ws_local_repo_build_\n" > /tmp/.bzl_ws_local_repo_build_
	templatize "/tmp/.bzl_ws_local_repo_build_" /tmp/.bzl_ws_local_repo_build__ "BZL_SRC_NAME,BZL_SRC_PATH,count"
	cat /tmp/.bzl_ws_local_repo_build__ >> "$DIR/WORKSPACE.bazel"
	count=$((count+1))
	
	src="$1"
	#BZL_SRCES=${BZL_SRCES//$1\//}
	if [ "$5" != "" ]; then
		for idir in ${5//,/ }
		do
			src1=`printf "%s\n%s\n" "$src" "$idir" | sed -e 'N;s/^\(.*\).*\n\1.*$/\1/'`
			#echo "$src -- $idir -- $src1"
			src="$src1"
			BZL_COPTS+=",\"-I$idir\""
		done
		#BZL_COPTS="${BZL_COPTS%?}"
		BZL_HDRS=${BZL_HDRS//$src/}
		BZL_SRCES=${BZL_SRCES//$src/}
	else
		BZL_HDRS=${BZL_HDRS//$src\//}
		BZL_SRCES=${BZL_SRCES//$src\//}
	fi
	#echo "$src"
	if [[ $src = *"/" ]]; then
		src="${src%?}"
	fi

	kvset "BN_$(get_key $BZL_SRC_NAME-inc)" "//$src:$BZL_SRC_NAME-inc"
	if [ "$2" = "binary" ]; then
		printf "$bzl_bin_build_\n" > /tmp/.bzl_bin_build_
		kvset "BN_$(get_key $BZL_SRC_NAME)" "//$src:$BZL_SRC_NAME"
	elif [ "$2" = "shared" ]; then
		BZL_SRC_SO_NAME="lib$BZL_SRC_NAME.$SHLIB_EXT"
		printf "$bzl_libso_build_\n" > /tmp/.bzl_bin_build_
		kvset "BN_$(get_key $BZL_SRC_NAME)" "//$src:$BZL_SRC_SO_NAME"
	elif [ "$2" = "static" ]; then
		printf "$bzl_libst_build_\n" > /tmp/.bzl_bin_build_
		kvset "BN_$(get_key $BZL_SRC_NAME)" "//$src:$BZL_SRC_NAME"
	elif [ "$2" = "stared" ]; then
		BZL_SRC_SO_NAME="lib$BZL_SRC_NAME.$SHLIB_EXT"
		printf "$bzl_libstso_build_\n" > /tmp/.bzl_bin_build_
		kvset "BN_$(get_key $BZL_SRC_NAME)" "//$src:$BZL_SRC_SO_NAME"
	fi

	templatize "/tmp/.bzl_bin_build_" "$DIR/$src/BUILD.bazel" "BZL_SRC_NAME,BZL_SRCES,BZL_DEFINES,BZL_LINKOPTS,BZL_COPTS,BZL_DEPS,BZL_HDRS,SHLIB_EXT,BZL_SRC_SO_NAME"
	#cat "$DIR/$1/BUILD.bazel"
}

function do_bazel_build() {
	for ex_ in ${1//,/ }
	do
		if [ "$ex_" != "" ]; then
			tmp=$(get_key $ex_)
			tmp=$(kvget "BN_$tmp")
			if [ "$tmp" != "" ]; then
				ret=`bazel build $tmp`
				if [ "$?" -eq "0" ]; then
					tmp="${tmp:1}"
					tmp=${tmp//:/\/}
					echo "bazel-bin$tmp"
					exe "" cp -f "bazel-bin$tmp" $SB_OUTDIR/.bin
				fi
			fi
		fi
	done
}

function do_bazel_pre_build() {
	echo "" > "$DIR/WORKSPACE.bazel"
}
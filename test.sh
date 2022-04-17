function do_config() {
	LOG_MODE=1
	BUILD_SYS=emb
	DEFS_FILE="../ffead-cpp/src/modules/common/AppDefines.h"
}

function do_start() {
	find_cmd c "c compiler not found" clang gcc c
	find_cmd c++ "c++ compiler not found" clang++ g++ c++
	c_flags "-std=c++17 -Wall -g"
	l_flags ""

	add_lib_path "/usr/local/lib" "/usr/local/opt/openssl/lib"

	add_inc_path "/usr/local/include" "/usr/local/opt/openssl/include" "/usr/include/libmongoc-1.0" \
		"/usr/include/libbson-1.0" "/usr/local/include/libmongoc-1.0" "/usr/local/include/libbson-1.0"

	add_def "BUILD_SHELLB" "INC_WEBSVC" "INC_TPE" "INC_DVIEW" "INC_DCP" "INC_XMLSER"
	if [ "$OS_DARWIN" = "1" ]; then
		add_def "APPLE"
	fi

	check_existence c_hdr "regex.h" "HAVE_REGEX" "regex includes not found"
	check_existence c_hdr_lib "libpq-fe.h" "pq" "HAVE_PQHDR" "libpq devel not found"
	if [ "$HAVE_PQHDR" = "1" ]; then
		add_def "HAVE_LIBPQ"
	fi
	check_existence c_hdr_lib "sql.h" "odbc" "HAVE_SQLINC" "odbc devel not found"
	if [ "$HAVE_SQLINC" = "1" ]; then
		add_def "HAVE_ODBCLIB" "HAVE_LIBODBC"
	fi
	check_existence c_hdr_lib "mongoc.h" "mongoc-1.0" "HAVE_MONGOINC" "libmongoc devel not found"
	if [ "$HAVE_MONGOINC" = "1" ]; then
		add_def "HAVE_MONGOCLIB"
	fi
	check_existence c_hdr_lib "bson.h" "bson-1.0" "HAVE_BSONINC" "libbson devel not found"
	if [ "$HAVE_BSONINC" = "1" ]; then
		add_def "HAVE_BSONLIB"
	fi
	check_existence cpp_hdr_lib "cassandra.h" "scylla-cpp-driver" "HAVE_SCYLLAINC" "scylla not found"
	if [ "$HAVE_SCYLLAINC" = "1" ]; then
		add_def "HAVE_SCYLLALIB"
	fi
	check_existence c_func "accept4" "HAVE_ACCEPT4" ""

	set_out "shellb_out"
	set_exclude_src "../ffead-cpp/src/modules/sdorm/gtm"
	if [ "$OS_MINGW" != "1" ]; then
		set_exclude_src "../ffead-cpp/src/modules/wepoll"
	fi
	add_inc_path "../ffead-cpp/src/framework"
	set_src "../ffead-cpp/src/modules" "stared:ffead-modules"
	set_src "../ffead-cpp/src/framework" "shared:ffead-framework" "ffead-modules"
	set_src "../ffead-cpp/src/server/embedded" "binary:ffead-cpp" "ffead-framework,ffead-modules"
}

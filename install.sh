rm -rf build || true
mkdir build

printf "#!/usr/bin/env bash\n\n" > build/shellb
cat utils/kv-bash|tail -n +3 >> build/shellb
printf "\n\n\n#utils/commands.sh\n" >> build/shellb
cat utils/commands.sh >> build/shellb
printf "\n\n\n#tools/bazel/bazel-util.sh\n" >> build/shellb
cat tools/bazel/bazel-util.sh >> build/shellb
printf "\n\n\n#tools/buck2/buck2-util.sh\n" >> build/shellb
cat tools/buck2/buck2-util.sh >> build/shellb

if [ "$1" = "c_cpp" ]; then
	printf "\n\n\n#platform/c_cpp/checks.sh\n" >> build/shellb
	cat platform/c_cpp/checks.sh >> build/shellb
	printf "\n\n\n#platform/c_cpp/build.sh\n" >> build/shellb
	cat platform/c_cpp/build.sh >> build/shellb
fi

printf "\n\n\n#shellb.sh\n" >> build/shellb
cat shellb.sh|tail -n +4 >> build/shellb
chmod +x build/shellb
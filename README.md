# shellb

A simple clean minimal shell based build tool for C/C++ based projects.

There are so many build tools already available currently - autoconf, cmake, xmake, meson, scons, bazel, buck2

Why create a new one??
- the existing tools are highly advanced
- are created for handling all possible combinations of possible build scnearios
- are created to handle complex build deployments
- some of them provide sandboxing
- some are targeted towards speed
- etc etc

The only reason for creating shellb was to have a minimal, clean, simple and concise build files, having worked with all the various build tools out there for [ffead-cpp](https://github.com/sumeetchhetri/ffead-cpp), managing the build files and keeping up with so many build files for a single project led to a thought which said the process should be easy and simple for anyone and the resulting build files should be small and self explanatory.<br/>This thought led to the idea of creating a tool which uses bash as the source language, shell is available everywhere and so the deployment would require no extra installation of any dependencies except a single script and the resulting build files would acahive the target of simplicity, conciseness and clarity.

Please understand that the tool does not claim to be fast, better or ready to handle every complex permutation of build deployments possible out there.<br/> But it does live upto its motto of being simple and concise, lets have a look at the table below for a simple/only comparison of build files for the project [ffead-cpp](https://github.com/sumeetchhetri/ffead-cpp)


|Tool|Lines of Code|Build Time|
|---|---|---|
|Autoconf|~3000|~12 mins|
|Cmake|~1000|~3.5 mins|
|Meson|~700|~3 mins|
|Scons|~650|~6.5 mins|
|Xmake|~1000|~3.5 mins|
|Buck2|~300|~2 mins|
|Bazel|~450|~3 mins|
|Shellb|**~167**|~3 mins|

Installation
====
`wget -q https://github.com/sumeetchhetri/shellb/releases/download/2.0.0/shellb -P . && chmod +x shellb && mv shellb /usr/local/bin`

Documentation
====
First a build script should be created which is nothing but a simple bash script, the only requirement is that the script should contain the following functions, [example](https://github.com/sumeetchhetri/ffead-cpp/blob/master/ffead-cpp-shellb.sh) <br/>
- do_setup - Setup initial environment, platform (c/c_cpp), build system (emb/bazel/buck2), any configuration headers to be generated etc
- do_config - Setup build configuration parameters, the function should return a newline separated list of properties (pipe separated values of param name, description and initial value (0,1))
- do_start - Provide the dependencies lookup, #define generation, compile and build any libraries/binaries
- do_install - Finally install the project after successfull build

do_setup
====
**LOG_MODE** - variable to either log output to file or to console<br/>
**BUILD_PROJ_NAME** - build project name<br/>
**BUILD_SYS** - the build tool used (emb|bazel|buck2)<br/>
**BUILD_PLATFORM** - the build platform supported (c|c_cpp)<br/>
**DEFS_FILE** - the relative path to the generated header definition file

do_config
====
A newline separated list of properties (pipe separated values of param name, description and initial value (0,1) 'echoed'<br/>
Lets look at an example
```shell
function do_config() {
    configs+=$'SOME_PARAM|Some description|0\n'
    configs+=$'OTHER_PARAM|Other description|1\n'
    echo "$configs"
}
```

do_start
===
**set_out** - sets the build output directory, if it does not exist it will be created<br/>
**set_install** - name of the project output folder name which will consist the binaries/libarries generated from the build<br/>
**finc_c_compiler** - finds the c compiler and the static library archiver programs (clang gcc c & ar) if found on the system<br/>
**finc_cpp_compiler** - finds the c++, c compilers and the static library archiver (clang++ g++ c++ & clang gcc c & ar) if found on the system<br/>
**c_flags** - set the c++ compiler flags to be passed to the c++ compiler<br/>
**cpp_flags** - set the c++ compiler flags to be passed to the c++ compiler<br/>
**l_flags** - set the liinker/library flags<br/>
**is_config** - check if the said config property is enabled or not<br/>
**add_def** - add a preprocessor define to the $DEFS_FILE file<br/>
**add_lib** - provide library to be used during linking<br/>
**add_inc_path** - add an include directory path to the compiler options<br/>
**add_lib_path** - add a library path to the linker<br/>
**c_hdr** - check whether the c header file exists<br/>
**cpp_hdr** - check whether the c++ header file exists<br/>
**c_lib** - check whether a c library file exists and can be used for linking<br/>
**cpp_lib** - check whether a c++ library file exists and can be used for linking<br/>
**c_hdr_lib** - check whether a c include file exists and can be compiled & whether a c library file exists and can be used for linking<br/>
**cpp_hdr_lib** - check whether a c++ include file exists and can be compiled & whether a c++ library file exists and can be used for linking<br/>
**c_code** - check whether the c code compiles<br/>
**c_func** - check whether the c function exists<br/>
**cpp_code** - check whether the c++ code compiles<br/>
**set_src** - specify source files path to be compiled and compile for 'emb' mode, generates build files for bazel|buck2<br/>
**set_inc_src** - specify source/include files path to be compiled and compile for 'emb' mode, generates build files for bazel|buck2<br/>
**set_src_files** - sepcify the source files to be compiled and compile for 'emb' mode, generates build files for bazel|buck2<br/>
**set_exclude_src** - exclude any source file paths from the list of to be compiled sources<br/>
**trigger_build** - trigger the builds for all the targets specified for non 'emb' modes, 'bazel|buck'
**templatize** - templatize/evaluate the shellb template file consisting of any variables to be replaced with tha @VAR@ syntax [example](https://github.com/sumeetchhetri/ffead-cpp/blob/master/rtdcf/inter-shellb.sh.tem)<br/>


do_install
===
**install_here** - install the said files/directories to the install directory, copy the files relative to the 'set_out' diectory, or either from an absolute path, or with the 'RELATIVE_DIR@*.h,*.so,*.html...' syntax

Provide any install_here commands or any installation related steps in this function

And you have the entire power of shell scripting at your disposal throughout the build file, do try it out!!
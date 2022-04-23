#copied from https://github.com/bazelbuild/rules_cc/blob/main/examples/my_c_compile/my_c_compile.bzl

load("@rules_cc//cc:action_names.bzl", "CPP_COMPILE_ACTION_NAME")
load("@rules_cc//cc:toolchain_utils.bzl", "find_cpp_toolchain")

MyCCompileInfo = provider(doc = "", fields = ["object"])
DISABLED_FEATURES = [
    "module_maps",  # # copybara-comment-this-out-please
]

def _my_cpp_compile_impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    source_file = ctx.file.src
    output_file = ctx.actions.declare_file(ctx.label.name + ".o")
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = DISABLED_FEATURES + ctx.disabled_features,
    )
    cpp_compiler_path = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
    )
    cpp_compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        user_compile_flags = ctx.fragments.cpp.copts + ctx.fragments.cpp.conlyopts,
        source_file = source_file.path,
        output_file = output_file.path,
    )
    command_line = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
        variables = cpp_compile_variables,
    )
    env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
        variables = cpp_compile_variables,
    )

    ctx.actions.run(
        executable = cpp_compiler_path,
        arguments = command_line,
        env = env,
        inputs = depset(
            [source_file],
            transitive = [cc_toolchain.all_files],
        ),
        outputs = [output_file],
    )
    return [
        DefaultInfo(files = depset([output_file])),
        MyCCompileInfo(object = output_file),
    ]

my_cpp_compile = rule(
    implementation = _my_cpp_compile_impl,
    attrs = {
        "src": attr.label(mandatory = True, allow_single_file = True),
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],  # copybara-use-repo-external-label
    fragments = ["cpp"],
)
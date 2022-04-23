def _exec_bazel_build(ctx):
    #header = ctx.file.input
    #defines = ctx.file.defines
    #ctx.actions.run_shell(
    #    inputs = [header],
    #    outputs = defines,
    #    arguments = [in_file.path, out_file.path],
    #    command = "run_bazel.sh '%s'" % (in_file.path, out_file.path),
    #)
    print('sdassssss')
    return "sdas"

check_header = rule(
    implementation = _exec_bazel_build,
    attrs = {
        "header": attr.label(mandatory = True),
        "defines": attr.string_list(mandatory = False),
    }
)
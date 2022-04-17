def _print_aspect_impl(target, ctx):
    # Make sure the rule has a srcs attribute.
    if hasattr(ctx.rule.attr, 'local_defines'):
        # Iterate through the files that make up the sources and
        # print their paths.
        for src in ctx.rule.attr.local_defines:
            print(src)
            #for f in src.files.to_list():
            #    print(f.path)
    return []

print_aspect = aspect(
    implementation = _print_aspect_impl,
    attr_aspects = ['deps'],
)
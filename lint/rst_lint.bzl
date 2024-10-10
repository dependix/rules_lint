"""API for declaring a rstlint aspect that visits py_library rules.

Typical usage:

First, fetch the rst-lint package via your standard requirements file and pip calls.

Then, declare a binary target for it, typically in `tools/lint/BUILD.bazel`:

```starlark
load("@rules_python//python/entry_points:py_console_script_binary.bzl", "py_console_script_binary")
py_console_script_binary(
    name = "restructuredtext-lint",
    pkg = "@pip//restructuredtext_lint:pkg",
)
```

Finally, create the linter aspect, typically in `tools/lint/linters.bzl`:

```starlark
load("@aspect_rules_lint//lint:rst_lint.bzl", "lint_rst_aspect")

restructuredtext_lint = lint_rst_aspect(
    binary = "@@//tools/lint:restructuredtext-lint",
)
```
"""

load("//lint/private:lint_aspect.bzl", "LintOptionsInfo", "filter_srcs", "noop_lint_action", "output_files", "should_visit")

_MNEMONIC = "AspectRulesLintRestructuredText"

def rst_lint_action(ctx, executable, srcs, stdout, exit_code = None, options = []):
    """Run restructuredtext-lint as an action under Bazel.

    Based on https://github.com/twolfson/restructuredtext-lint

    Args:
        ctx: Bazel Rule or Aspect evaluation context
        executable: label of the the restructuredtext-lint program
        srcs: python files to be linted
        stdout: output file containing stdout of restructuredtext-lint
        exit_code: output file containing exit code of restructuredtext-lint
            If None, then fail the build when restructuredtext-lint exits non-zero.
        options: additional command-line options, see https://github.com/twolfson/restructuredtext-lint?tab=readme-ov-file#cli-utility
    """
    inputs = srcs
    outputs = [stdout]

    # Wire command-line options, see
    # https://github.com/twolfson/restructuredtext-lint?tab=readme-ov-file#cli-utility
    args = ctx.actions.args()
    args.add_all(options)
    args.add_all(srcs)
    if exit_code:
        command = "{rstlint} $@ >{stdout}; echo $? > " + exit_code.path
        outputs.append(exit_code)
    else:
        # Create empty stdout file on success, as Bazel expects one
        command = "{rstlint} $@ && touch {stdout}"

    ctx.actions.run_shell(
        inputs = inputs,
        outputs = outputs,
        tools = [executable],
        command = command.format(rstlint = executable.path, stdout = stdout.path),
        arguments = [args],
        mnemonic = _MNEMONIC,
        progress_message = "Linting %{label} with restructuredtext-lint",
    )

# buildifier: disable=function-docstring
def _rst_lint_aspect_impl(target, ctx):
    # for now we only support linter over filegroup
    rule_kinds = []

    if not should_visit(ctx.rule, rule_kinds, ctx.attr._filegroup_tags):
        return []

    outputs, info = output_files(_MNEMONIC, target, ctx)
    files_to_lint = filter_srcs(ctx.rule)

    if len(files_to_lint) == 0:
        noop_lint_action(ctx, outputs)
        return [info]

    rst_lint_action(ctx, ctx.executable._rst_lint, files_to_lint, outputs.human.out, outputs.human.exit_code)
    rst_lint_action(ctx, ctx.executable._rst_lint, files_to_lint, outputs.machine.out, outputs.machine.exit_code)
    return [info]

def lint_rst_aspect(binary, filegroup_tags = ["restructuredtext"]):
    """A factory function to create a linter aspect."""
    return aspect(
        implementation = _rst_lint_aspect_impl,
        attrs = {
            "_options": attr.label(
                default = "//lint:options",
                providers = [LintOptionsInfo],
            ),
            "_rst_lint": attr.label(
                default = binary,
                executable = True,
                cfg = "exec",
            ),
            "_filegroup_tags": attr.string_list(
                default = filegroup_tags,
            ),
        },
    )

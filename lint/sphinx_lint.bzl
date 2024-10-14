"""API for declaring a sphinx-lint aspect that visits RST file extentions.

Typical usage:

First, fetch the sphinx-lint package via your standard requirements file and pip calls.

Then, declare a binary target for it, typically in `tools/lint/BUILD.bazel`:

```starlark
load("@rules_python//python/entry_points:py_console_script_binary.bzl", "py_console_script_binary")
py_console_script_binary(
    name = "sphinx-lint",
    pkg = "@pip//sphinx_lint:pkg",
)
```

Finally, create the linter aspect, typically in `tools/lint/linters.bzl`:

```starlark
load("@aspect_rules_lint//lint:sphinx_lint.bzl", "lint_sphinx_aspect")
sphinx_lint = lint_sphinx_aspect(
    binary = "@@//tools/lint:sphinx-lint",
)
```
"""

load("//lint/private:lint_aspect.bzl", "LintOptionsInfo", "filter_srcs", "noop_lint_action", "output_files", "should_visit")

_MNEMONIC = "AspectRulesSphinxLint"

def sphinx_lint_action(ctx, executable, srcs, stdout, exit_code = None, options = []):
    """Run sphinx-lint as an action under Bazel.

    Based on https://github.com/sphinx-contrib/sphinx-lint

    Args:
        ctx: Bazel Rule or Aspect evaluation context
        executable: label of the the sphinx-lint program
        srcs: python files to be linted
        stdout: output file containing stdout of sphinx-lint
        exit_code: output file containing exit code of sphinx-lint
            If None, then fail the build when sphinx-lint exits non-zero.
        options: additional command-line options, see https://github.com/sphinx-contrib/sphinx-lint
    """
    inputs = srcs
    outputs = [stdout]

    args = ctx.actions.args()
    args.add_all(options)
    args.add_all(srcs)
    if exit_code:
        # In case of error, sphinx-lint throws error output on stderr.
        command = "{sphinx_lint} $@ >{stdout} 2>&1; echo $? > " + exit_code.path
        outputs.append(exit_code)
    else:
        # Create empty stdout file on success, as Bazel expects one
        command = "{sphinx_lint} $@ && touch {stdout}"

    ctx.actions.run_shell(
        inputs = inputs,
        outputs = outputs,
        tools = [executable],
        command = command.format(sphinx_lint = executable.path, stdout = stdout.path),
        arguments = [args],
        mnemonic = _MNEMONIC,
        progress_message = "Linting %{label} with sphinx-lint",
    )

# buildifier: disable=function-docstring
def _sphinx_lint_aspect_impl(target, ctx):
    """Implementation function for aspect"""
    
    # for now we only support linter over filegroup
    rule_kinds = []

    if not should_visit(ctx.rule, rule_kinds, ctx.attr._filegroup_tags):
        return []

    outputs, info = output_files(_MNEMONIC, target, ctx)
    files_to_lint = filter_srcs(ctx.rule)

    if len(files_to_lint) == 0:
        noop_lint_action(ctx, outputs)
        return [info]

    sphinx_lint_action(ctx, ctx.executable._sphinx_lint, files_to_lint, outputs.human.out, outputs.human.exit_code)
    sphinx_lint_action(ctx, ctx.executable._sphinx_lint, files_to_lint, outputs.machine.out, outputs.machine.exit_code)
    return [info]

def lint_sphinx_aspect(binary, filegroup_tags = ["sphinx_lint"]):
    """A factory function to create a linter aspect."""
    return aspect(
        implementation = _sphinx_lint_aspect_impl,
        attrs = {
            "_options": attr.label(
                default = "//lint:options",
                providers = [LintOptionsInfo],
            ),
            "_sphinx_lint": attr.label(
                default = binary,
                executable = True,
                cfg = "exec",
            ),
            "_filegroup_tags": attr.string_list(
                default = filegroup_tags,
            ),
        },
    )

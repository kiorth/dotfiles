"""Walk the espresso Click CLI and print its command tree.

Output is TSV, one command per line:

    <space-joined path>\t<short help>

with a single header line naming the package source directory, so `qmap` can
decide whether its cache is stale without paying for a Python start-up:

    #src\t/path/to/espresso

This lives in dotfiles rather than in the espresso package on purpose: it asks
the CLI only *what commands exist*, never which one relates to a topic.  If a
Click upgrade ever breaks `list_commands` traversal, that is the signal to add
a hidden `espresso --dump-commands` emitting this same TSV and to prefer it
here, falling back to this walk.
"""

import os
import sys


def walk(group, path, ctx, out):
    import click

    for name in sorted(group.list_commands(ctx)):
        try:
            sub = group.get_command(ctx, name)
        except Exception:
            continue
        if sub is None or getattr(sub, "hidden", False):
            continue
        here = path + [name]
        try:
            short = sub.get_short_help_str(140)
        except Exception:
            short = ""
        out.append(" ".join(here) + "\t" + " ".join(short.split()))
        if isinstance(sub, click.Group):
            walk(sub, here, ctx, out)


def main():
    import click

    import espresso
    from espresso.cli import cli

    src = os.path.dirname(os.path.abspath(espresso.__file__))
    ctx = click.Context(cli, info_name="espresso")
    out = ["#src\t" + src]
    walk(cli, [], ctx, out)
    sys.stdout.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()

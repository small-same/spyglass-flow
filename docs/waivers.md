# Waiver syntax notes

Collected while fighting SpyGlass waivers in anger. Nothing here is exotic —
all of it is in the manuals — but each one costs an hour the first time.

## `-rule` in a file, `-rules` in the shell

The AWL file form and the Tcl command form of `waive` take *different* option
names for the same thing:

```tcl
# waivers/lint.awl
waive -rule  { SYNTH_89 } -comment "..."

# sg_shell> prompt
waive -rules { SYNTH_89 } -comment "..."
```

Copying a line from one to the other without changing it fails silently or
errors, depending on the release.

## `-du` matches a design unit, not a hierarchy path

`-du` and `-ip` take **module / entity names**. A violation message like

```
Detected undriven input terminal TOP.WRAP0.CORE0.sub.inst.pin
```

shows an *instance* path, and no amount of pasting it into `-du` will match.

To target a hierarchy, match the message text instead:

```tcl
waive -rules { UndrivenInTerm-ML } -regexp -msg {CORE0\.sub\.inst\.} -comment "..."
```

To target an IP and everything under it, find the module name and use `-ip`
(which covers the whole hierarchy below it, unlike `-du` which covers one
level):

```bash
grep -nE "^module .*(core|sub)" netlist.v | head
```

`-ip` survives hierarchy edits; a `-msg` regex breaks as soon as the message
text changes. Prefer `-ip` when you can.

## `*` means different things with and without `-regexp`

| Form | `*` behaves as |
|---|---|
| `waive -msg {foo*bar}` | glob wildcard — "anything" |
| `waive -msg {foo.*bar} -regexp` | regex — `.` any char, `*` repeat |
| `waive -msg {foo*bar} -exact` | literal asterisk |

So this works:

```tcl
waive -msg {Detected undriven input terminal *.WRAP0.*md_csa_*}
```

and the "same" pattern with `-regexp` does **not**, because a leading `*` has
nothing to repeat:

```tcl
waive -regexp -msg {*.WRAP0.*}        # invalid
waive -regexp -msg {.*\.WRAP0\..*}    # correct
```

Pick one mode and stay in it.

## Brace the message, don't quote it

Use `{...}` for `-msg`, not `"..."`. Violation messages routinely contain bus
indices like `sig[0]`, and inside double quotes Tcl tries to execute `[0]` as a
command.

```tcl
waive -rules { W528 } -msg {Variable 'bus[3:0]' set but not read}   # good
```

## Verify the waiver actually caught something

A waiver that matches nothing looks exactly like a waiver that works. Check:

```tcl
sg_shell> run_goal
sg_shell> write_report waiver > waiver.rpt
```

The report lists how many messages each waiver absorbed. Zero means the pattern
is wrong. Iterating in the shell is far quicker than editing the AWL file and
re-running the whole flow; move the line into the file once it bites — and
remember to change `-rules` back to `-rule`.

## Editing AWL files on Windows

`SGDCSTX_031: Illegal field value specified (requires space after closing
double quote)` on a line that visibly *has* a space usually means a stray
carriage return:

```bash
cat -A waivers/lint.awl | sed -n '1,20p'   # look for ^M$ at line ends
dos2unix waivers/lint.awl                  # or: sed -i 's/\r$//' file
```

Smart quotes and full-width spaces pasted from a chat window or a web page
cause the same class of error and are just as invisible.

# Troubleshooting

## Black boxes

`ErrorAnalyzeBBox: Design Unit 'X' has no definition; black-box behavior
assumed` means SpyGlass could not find or could not elaborate `X`. It then
*infers* the port directions from how the instance is wired, which is usually
where the downstream noise comes from.

A black box does not just produce one message. It produces a family:

```
X has no definition
  └─ black box, port directions inferred (possibly wrong)
       ├─ W287a / W287b   instance inputs undriven / outputs unconnected
       └─ UndrivenInTerm-ML  undriven but loaded input terminals
```

So **waiving `ErrorAnalyzeBBox` does not silence the rest** — the module is
still a black box. Fix the cause instead:

| Black box | Fix |
|---|---|
| Standard cells (`*_X4B_*` etc.) | read the `.lib` |
| `GTECH_*` | the netlist was never mapped; read the GTECH Verilog models, or get a mapped netlist |
| Memory macros | read the memory `.lib` (see `tools/collect_libs.sh`) |
| Hard macros / analog IP | genuinely a black box — waive it, with a reason |
| Your own RTL | see "not synthesizable" below |

### GTECH models

`GTECH_*` cells are Design Compiler's technology-independent intermediate
cells. Their presence means the netlist was written out before mapping. The
simulation models ship with DC:

```bash
find "$SYNOPSYS" -name '*.v' | xargs grep -l 'module GTECH_FD1'
```

Usually there is an all-in-one `gtech_lib.v`; read that rather than the
individual cell files, or you will get duplicate definitions.

## "not synthesizable" / UnsynthesizedDU

```
UnsynthesizedDU: Design Unit 'FIFO' not synthesizable; SYNTH_#### error(s)
```

This is a *downstream* message. The real cause is the `SYNTH_####` violation,
which is reported separately — go read that one.

A common offender is the array-size threshold: a multi-dimensional array whose
total bit count exceeds `mthresh` (4096 by default) makes SpyGlass refuse to
synthesize the whole module, which then becomes a black box. FIFOs and
register files hit this constantly.

```tcl
set_option handlememory yes   # model memories instead of expanding them
set_option mthresh 16384      # or raise the ceiling
```

`handlememory` is the cheaper fix. Raising `mthresh` fully expands the arrays:
the module gets analyzed properly, but design read is slower and new violations
appear from inside the module that was previously invisible. That is a feature,
not a regression.

To see an option's current value, including its default when you have never set
it:

```tcl
sg_shell> get_option mthresh
```

## Duplicate library cells (LIBERROR_313)

Memory compilers write every PVT corner of a macro into one directory. A glob
like `*ss*125c*.lib` happily matches two different voltage corners of the same
macro, and reading both is a duplicate-cell error.

Lint only needs pin direction and function, so one corner per macro is enough —
keep exactly one `.lib` per directory. `tools/collect_libs.sh` does this.

## SGDC commands in a Tcl script

```
SGDCSTX_010: Missing current_design specification for SGDC command 'sdc_data'
```

`sdc_data`, `clock`, `reset` and friends are **SGDC commands**: they belong in a
`.sgdc` file, under a `current_design` line. Written bare in a Tcl script they
have no design context and abort the run.

```tcl
# scripts/common_setup.tcl  — Tcl, so only read the file
read_file -type sgdc sgdc/top.sgdc
```

```tcl
# sgdc/top.sgdc  — SGDC, so current_design first
current_design chip_top
sdc_data -file constraints/func.sdc -mode func
```

The `-file` path is relative to the directory you launch the run from, not to
the `.sgdc` file. Use an absolute path when in doubt.

## Reloading a project

There is no reload command — close and open:

```tcl
sg_shell> close_project -force
sg_shell> open_project my.prj
```

Open it from the directory it was saved in, or its relative paths break.

Usually you do not need this at all. If a setup file changed, just re-run
`make <flow>`, which rebuilds the project from scratch. If you only changed an
option or a waiver, apply it in the shell and `run_goal` again — much faster
than a fresh design read on a large chip.

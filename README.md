# spyglass-flow

A small, version-controllable harness for running Synopsys SpyGlass checks from
a Makefile. One generic Tcl runner drives six flows — **lint, constraints, CDC,
RDC, DFT and low-power** — off a single shared design-read setup, so every flow
sees exactly the same design.

```
make lint          # one flow
make all           # every flow, in dependency order
make TOP=my_top cdc
```

## Why

Running SpyGlass by hand tends to produce one `.prj` per check, each with its
own copy of the file list, the `set_option` lines and the library paths. They
drift. A CDC run then disagrees with a lint run for reasons nobody can
reconstruct.

Here the design read lives in exactly one file (`scripts/common_setup.tcl`), the
flow-to-goal mapping lives in a table (`scripts/run_flow.tcl`), and everything
is plain text that diffs cleanly.

## Layout

```
Makefile                  flow entry point
scripts/
  common_setup.tcl        design read: RTL, options, libs, SGDC  (shared)
  run_flow.tcl            generic runner; FLOW env var selects the goal set
  err_by_design.py        split a moresimple report by design block
sgdc/top.sgdc             clock / reset / sdc_data declarations
filelist/rtl.f            RTL file list
waivers/lint.awl          per-flow waivers (<flow>.awl is auto-loaded)
tools/
  collect_libs.sh         pick one timing-lib corner per memory macro
  lint.prj                standalone project-file example
  run_lint.tcl            standalone sg_shell example
```

Generated at run time: `work/`, `logs/`, `reports/` (all git-ignored).

## Quick start

1. **Fill in the file list** — `filelist/rtl.f`, one path per line
   (`+incdir+` / `+define+` work too).

2. **Declare clocks and resets** — `sgdc/top.sgdc`. CDC and RDC are meaningless
   without these. If you have an SDC, point at it with `sdc_data` instead of
   repeating the clocks by hand; SpyGlass translates it and merges both sources
   (SDC wins on conflict).

3. **Check the goal names.** The `GOALS` table in `scripts/run_flow.tcl` uses
   common GuideWare 2.0 names, which differ between releases:

   ```bash
   spyglass -project <any.prj> -showgoals
   ```

   Then fix the table:

   ```tcl
   array set GOALS {
       lint  {lint/lint_rtl}
       cn    {constraints/sdc_check}
       cdc   {cdc/cdc_setup_check cdc/cdc_verify_struct}
       rdc   {rdc/rdc_verify_struct}
       dft   {dft/dft_scan_ready}
       lp    {lp/lp_verify_struct}
   }
   ```

   One flow may map to several goals; they run in order and each writes its own
   report.

4. **Run.** `make TOP=<your_top> lint`

### Variables

| Variable | Default | Meaning |
|---|---|---|
| `TOP` | `chip_top` | top module |
| `SG_SHELL` | `sg_shell` | path to the shell binary |
| `LIB_ROOT` | `/path/to/memory/libs` | memory-lib root; scanned recursively, empty string skips |

## Where each flow belongs

```
RTL coding ──► RTL freeze ──────────► Synthesis ──► DFT/P&R ──► Signoff
   lint         lint (full)                            │
                cn   ◄── must pass before synthesis    │
                cdc → rdc               re-run cdc/rdc/dft on the netlist
                dft  (scan-readiness)   re-verify lp, refine power numbers
                lp   (UPF intent)
```

| Flow | Checks | Needs |
|---|---|---|
| `lint` | synthesizability, latches, width mismatch, multi-driver | file list |
| `cn` | SDC/SGDC completeness and consistency | an SDC via `sdc_data` |
| `cdc` | clock-domain crossings, metastability, reconvergence | `clock` in SGDC |
| `rdc` | reset-domain crossings | `reset` in SGDC |
| `dft` | scan-readiness, clock/reset controllability | `test_mode` in SGDC |
| `lp` | UPF structure: isolation, level shifters, retention | a UPF |

`make all` runs them as `lint → cn → cdc → rdc → dft → lp`. The order matters:
a dirty lint buries the other flows in noise, and a wrong SGDC/SDC makes
CDC/RDC/DFT results untrustworthy. Only `cn` actually requires an SDC — the
other five run without one.

## Waivers

`waivers/<flow>.awl` is loaded automatically when it exists, so lint waivers
never leak into the CDC run.

```tcl
waive -rule { SYNTH_89 } -comment "initial value at declaration, reviewed"
waive -ip "my_verified_ip" -comment "vendor IP, integration still checked"
waive -regexp -du "SRAM_.*_ARRAY" -rule { InferLatch } -comment "latch-based RF, intended"
```

Give every waiver a `-comment`; the waiver report is only as reviewable as its
reasons. See [docs/waivers.md](docs/waivers.md) for the syntax traps —
`-rule` vs `-rules`, regex vs glob, and why `-du` will not match a hierarchy
path.

## Triaging a report

`scripts/err_by_design.py` splits all Error-severity violations by design block,
preserving the original message lines, so each block owner gets only their own:

```bash
cd <report-dir>
python err_by_design.py moresimple.rpt errors_by_design.txt
```

Edit the `TARGETS` table at the top of the script to match your blocks. Order
decides ownership when a hierarchy path spans several blocks — and it often
does, so check full paths before assigning blame.

## Not included

No RTL, netlists, timing libraries, vendor documentation or real violation
reports — none of that is mine to publish, and `.gitignore` is set up to keep
it out. This repo is the harness only.

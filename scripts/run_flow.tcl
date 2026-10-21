###########################################################################
# run_flow.tcl — invoked by the Makefile:
#   FLOW=<flow> sg_shell -tcl run_flow.tcl
#
# One script drives all six flows; the flow -> goal mapping lives in the
# GOALS table below.
#
# !!! Goal names differ between SpyGlass versions / GuideWare releases !!!
# First list the goals available in YOUR installation with:
#   spyglass -project <any.prj> -showgoals
# then fix the GOALS table. The names below are common GuideWare2.0
# defaults and serve as a template only.
###########################################################################

if {![info exists ::env(FLOW)]} {
    puts "ERROR: FLOW env var not set (expect lint/cn/cdc/rdc/dft/lp)"
    exit 1
}
set flow $::env(FLOW)
set top  $::env(TOP)

# ---- flow -> goal mapping (EDIT to match your installation) -------------
array set GOALS {
    lint  {lint/lint_rtl}
    cn    {constraints/sdc_check}
    cdc   {cdc/cdc_setup_check cdc/cdc_verify_struct}
    rdc   {rdc/rdc_verify_struct}
    dft   {dft/dft_scan_ready}
    lp    {lp/lp_verify_struct}
}

if {![info exists GOALS($flow)]} {
    puts "ERROR: unknown flow '$flow' (expect: [array names GOALS])"
    exit 1
}

# ---- project ------------------------------------------------------------
new_project work/$flow -projectwdir work -force

source scripts/common_setup.tcl

# ---- per-flow waiver: waivers/<flow>.awl is loaded when present ---------
if {[file exists waivers/$flow.awl]} {
    puts "==> loading waiver: waivers/$flow.awl"
    read_file -type awl waivers/$flow.awl
}

# ---- run every goal mapped to this flow ---------------------------------
foreach g $GOALS($flow) {
    puts "=================================================="
    puts "==  current_goal $g  (top=$top)"
    puts "=================================================="
    current_goal $g -top $top
    run_goal

    set tag [string map {/ _} $g]
    write_report moresimple > reports/${flow}_${tag}_moresimple.rpt
    write_report summary    > reports/${flow}_${tag}_summary.rpt
}

save_project
puts "==> flow '$flow' done."
exit

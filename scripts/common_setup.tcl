###########################################################################
# common_setup.tcl — design read / options / libs / SGDC shared by every
# flow. Sourced by scripts/run_flow.tcl; do not run standalone.
###########################################################################

set top $::env(TOP)

##### 1. Read RTL #########################################################
read_file -type sourcelist filelist/rtl.f

##### 2. Basic options ####################################################
set_option top          $top
set_option enableSV09   yes
# Model large memory arrays instead of expanding them bit-by-bit,
# avoids SYNTH_5273 (mthresh, default 4096 bits, exceeded)
set_option handlememory yes
# If SYNTH_5273 still fires, uncomment and raise the threshold:
# set_option mthresh 16384

# set_option incdir { rtl/include }
# set_option define { SYNTHESIS }

# Modules whose internals should NOT be analyzed (IP / memory wrapper /
# analog macro) — treated as blackboxes:
# set_option stop { my_fifo_ip analog_macro }

##### 3. Memory .lib (one corner per macro: ss/125c) ######################
# Some NLDM dirs hold several ss voltage corners (e.g. 0p90v AND 0p99v) of
# the same macro; reading both causes duplicate-cell LIBERROR_313. Corners
# of one macro live in the same directory, so keep only ONE lib per dir.
if {[info exists ::env(LIB_ROOT)] && $::env(LIB_ROOT) ne "" \
        && [file isdirectory $::env(LIB_ROOT)]} {
    set all [lsort [split [exec find $::env(LIB_ROOT) -name *ss*125c*.lib] "\n"]]
    array set seen {}
    set lib_files {}
    foreach f $all {
        if {$f eq ""} continue
        set d [file dirname $f]
        if {[info exists seen($d)]} continue    ;# one corner per directory
        set seen($d) 1
        lappend lib_files $f
    }
    puts "==> common_setup: reading [llength $lib_files] ss/125c libs (dedup from [llength $all] matches) under $::env(LIB_ROOT)"
    foreach lf $lib_files {
        read_file -type gateslib $lf
    }
} else {
    puts "==> common_setup: LIB_ROOT not set / not found, skip gateslib"
}

##### 4. SGDC (clock / reset / sdc_data declarations) #####################
# Consumed by CDC / RDC / Constraints / DFT — see sgdc/top.sgdc
#
# IMPORTANT: SGDC commands (current_design / clock / reset / sdc_data / ...)
# must live INSIDE the .sgdc file, NOT here in the Tcl script. Writing
# `sdc_data ...` directly in this script triggers:
#     SGDCSTX_010: Missing current_design specification for SGDC command
# because a bare Tcl line has no current_design context. Put sdc_data in
# sgdc/top.sgdc (under its current_design line) instead.
read_file -type sgdc sgdc/top.sgdc

##### 5. UPF (needed by the lp flow only; comment out if no low-power) ####
# read_file -type upf power/top.upf

#############################################################
# SpyGlass sg_shell Tcl script (run_lint.tcl)
#
# 用法:
#   sg_shell -tcl run_lint.tcl
# 或互動式:
#   sg_shell
#   sg_shell> source run_lint.tcl
#############################################################

# 開新 project（-force 覆蓋舊的）
new_project lint_run -projectwdir . -force

##### 讀 design #####
read_file -type sourcelist ./filelist.f

##### options #####
set_option top          top_module
set_option enableSV09   yes
set_option incdir       { ./rtl/include }
set_option define       { SYNTHESIS }
set_option stop         { sram_wrapper }

##### waiver #####
read_file -type awl ./waivers.awl

##### 跑 lint goal #####
current_goal lint/lint_rtl -top top_module
run_goal

##### 輸出報告 #####
# moresimple 是最常看的文字報告（每條 violation 一行）
write_report moresimple > ./reports/lint_moresimple.rpt
write_report summary    > ./reports/lint_summary.rpt
write_report waiver     > ./reports/lint_waiver.rpt

save_project
exit

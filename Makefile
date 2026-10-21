#############################################################
# SpyGlass Integrated Flow Makefile
#
#   make help              list all targets
#   make lint              run lint only
#   make all               run every flow in the recommended
#                          order: lint -> cn -> cdc -> rdc -> dft -> lp
#   make TOP=my_top lint   override the top module
#############################################################

# ---- user-overridable variables ---------------------------
TOP       ?= chip_top
SG_SHELL  ?= sg_shell
# Root directory of memory libs (recursively picks *ss*125c*.lib;
# set to an empty string to skip lib loading)
LIB_ROOT  ?= /path/to/memory/libs

# The six flows; the order below is the execution order of
# `make all` (lint/constraints must be clean first, otherwise
# the remaining checks are meaningless)
FLOWS     := lint cn cdc rdc dft lp

export TOP LIB_ROOT

# ---- targets ----------------------------------------------
.PHONY: all help clean $(FLOWS)

help:
	@echo "SpyGlass flow targets:"
	@echo "  make lint   - RTL lint (coding style / synthesizability)"
	@echo "  make cn     - Constraints: SDC/SGDC completeness check"
	@echo "  make cdc    - Clock Domain Crossing"
	@echo "  make rdc    - Reset Domain Crossing"
	@echo "  make dft    - DFT scan-readiness (RTL stage)"
	@echo "  make lp     - Low power / UPF intent check"
	@echo "  make all    - run every flow in the recommended order"
	@echo "  make clean  - remove work/ logs/ reports/"
	@echo ""
	@echo "variables: TOP=$(TOP)  SG_SHELL=$(SG_SHELL)"
	@echo "           LIB_ROOT=$(LIB_ROOT)"

all: $(FLOWS)

$(FLOWS):
	@mkdir -p work logs reports
	@echo "=================================================="
	@echo "==  SpyGlass flow : $@   (TOP=$(TOP))"
	@echo "=================================================="
	FLOW=$@ $(SG_SHELL) -tcl scripts/run_flow.tcl 2>&1 | tee logs/$@.log
	@echo "==> $@ finished, see reports/$@_*.rpt"

clean:
	rm -rf work logs reports

# -*- coding: utf-8 -*-
"""
err_by_design.py - Split SpyGlass moresimple.rpt errors by design block.

Usage:
    python err_by_design.py [moresimple.rpt] [output.txt]

Defaults:
    input  = ./moresimple.rpt
    output = ./error_by_design.txt

Original SpyGlass message lines are preserved verbatim.
Edit TARGETS below to match the blocks you care about; order matters
(a violation is assigned to the FIRST design whose pattern matches).
Anything unmatched falls into the OTHERS bucket.
"""
import io, re, sys
from collections import Counter, OrderedDict

# ---------------------------------------------------------------- config ---
# label -> regex matched against the whole violation line
# NOTE: verify the REAL instance names in your report before trusting a pattern;
#       a plausible-looking name may not be what the tool emits. Check with:
#   grep -E '^\[' moresimple.rpt | grep -oE '[A-Za-z0-9_]*<KEYWORD>[A-Za-z0-9_]*' | sort | uniq -c
TARGETS = OrderedDict([
    ("BLOCK_A  (NEW)",        r"BLOCK_A_RN0?\b"),
    ("BLOCK_B  (NEW)",        r"BLOCK_B0?_RN0?\b|BLOCK_B_[A-Za-z0-9_]+"),
    ("PIN_MUX  (REGEN)",      r"PIN_MUX0?\b|PIN_MUX_[A-Za-z0-9_]+"),
    ("PWR_ISO  (MODIFIED)",   r"PWR_ISO_TOP0?\b|PWR_ISO_MISC0?\b"),
    # (?<![A-Za-z0-9_]) = prefix match only, so I_FOO_REGFILE_0 is NOT counted
    ("REGF*  (MODIFIED)",     r"(?<![A-Za-z0-9_])REGF[A-Za-z0-9_]*"),
])
OTHERS = "OTHERS  (legacy / ported blocks)"

# severities to extract; drop to r"\bError\b" for Error only
SEV_WANTED = r"\b(Fatal|Error|SynthesisError)\b"

WIDTH = 100
# ---------------------------------------------------------------------------

def rule_of(line):
    p = line.split()
    return p[1] if len(p) > 1 else "?"

def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "moresimple.rpt"
    dst = sys.argv[2] if len(sys.argv) > 2 else "error_by_design.txt"

    sev_rx = re.compile(SEV_WANTED)
    hits = []
    with io.open(src, encoding="utf-8", errors="replace") as f:
        for ln in f:
            # violation lines start with a bracketed ID, e.g. [8141]
            if ln.startswith("[") and sev_rx.search(ln):
                hits.append(ln.rstrip("\n"))

    buckets = OrderedDict((k, []) for k in TARGETS)
    buckets[OTHERS] = []
    compiled = [(k, re.compile(p)) for k, p in TARGETS.items()]

    for ln in hits:
        for k, rx in compiled:
            if rx.search(ln):
                buckets[k].append(ln)
                break
        else:
            buckets[OTHERS].append(ln)

    out = []
    bar = "=" * WIDTH
    dash = "-" * WIDTH
    out += [bar, "SpyGlass Lint - ERRORS BY DESIGN", bar,
            "Source : %s" % src,
            "Scope  : %s" % SEV_WANTED,
            "Note   : original SpyGlass message lines preserved verbatim.",
            "         A violation goes to the FIRST design whose name appears in its message;",
            "         a hierarchy path may span several blocks (e.g. CombLoop) - check the full path.",
            "", dash, "SUMMARY", dash,
            "%-52s %7s   %s" % ("DESIGN", "ERRORS", "RULES")]
    for k, v in buckets.items():
        rc = Counter(rule_of(x) for x in v)
        rs = ", ".join("%s(%d)" % (r, c) for r, c in rc.most_common())
        out.append("%-52s %7d   %s" % (k, len(v), rs if rs else "-"))
    out += ["%-52s %7d" % ("TOTAL", len(hits)), ""]

    for k, v in buckets.items():
        out += ["", bar, "%s   -   %d error(s)" % (k, len(v)), bar]
        if not v:
            out.append("(none)")
            continue
        for r, c in Counter(rule_of(x) for x in v).most_common():
            out += ["", dash, "[ %s ]  %d error(s)" % (r, c), dash]
            out += [ln for ln in v if rule_of(ln) == r]

    with io.open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")

    print("total: %d" % len(hits))
    for k, v in buckets.items():
        print("  %-52s %d" % (k, len(v)))
    print("written: %s" % dst)

if __name__ == "__main__":
    main()

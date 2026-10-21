#!/bin/bash
###############################################################################
# collect_libs.sh - collect ONE timing-library corner per memory macro.
#
# Memory compilers emit every PVT corner of a macro into the same directory:
#   RF1P1040X6_ss_0p99v_0p99v_125c.lib
#   RF1P1040X6_tt_1p10v_1p10v_25c.lib
#   ...
# Reading more than one corner of the same macro makes SpyGlass fail with
# duplicate-cell errors (LIBERROR_313), so we keep exactly one per directory.
#
# Lint only needs pin direction and function, not timing, so any corner works.
#
# Usage:
#   cd <memory-lib-root>
#   ./collect_libs.sh
#
# Output:
#   collected_libs/  - one .lib per macro
#   lib_list.f       - path list, feed it to read_file -type gateslib
###############################################################################

set -u

ROOT="$(pwd)"
OUTDIR="$ROOT/collected_libs"
LIST="$ROOT/lib_list.f"

# Top-level directories to scan; missing ones are skipped silently.
TOPDIRS=(.)

# Vendor sub-directories, if your tree has them (e.g. Artisan / Virage).
# Leave as "." to scan TOPDIRS directly.
VENDORS=(.)

# Corner preference, left to right: the first one found per macro wins.
# Keep only (ss) if you want worst-case libs exclusively.
CORNER_PRIORITY=(tt ss ff)

# copy = duplicate files | link = symlink (saves space) | list = list only
MODE=list

###############################################################################
mkdir -p "$OUTDIR"
: > "$LIST"

count=0
warn=0
declare -A seen_dir
declare -A seen_name

for top in "${TOPDIRS[@]}"; do
    [ -d "$ROOT/$top" ] || continue
    for vendor in "${VENDORS[@]}"; do
        vdir="$ROOT/$top/$vendor"
        [ -d "$vdir" ] || continue

        # every macro gets its own directory
        while IFS= read -r memdir; do
            [ -d "$memdir" ] || continue

            picked=""
            for c in "${CORNER_PRIORITY[@]}"; do
                f=$(ls "$memdir"/*_${c}_*.lib 2>/dev/null | sort | head -n1)
                [ -n "$f" ] && { picked="$f"; break; }
            done
            # no preferred corner matched: fall back to any .lib
            [ -z "$picked" ] && picked=$(ls "$memdir"/*.lib 2>/dev/null | sort | head -n1)

            if [ -z "$picked" ]; then
                continue
            fi

            base=$(basename "$picked")
            # one lib per directory AND globally unique basename
            [ -n "${seen_dir[$memdir]:-}" ]  && continue
            [ -n "${seen_name[$base]:-}" ]   && { warn=$((warn+1)); continue; }
            seen_dir[$memdir]=1
            seen_name[$base]=1

            case "$MODE" in
                copy) cp -f "$picked" "$OUTDIR/$base"; echo "$OUTDIR/$base" >> "$LIST" ;;
                link) ln -sf "$picked" "$OUTDIR/$base"; echo "$OUTDIR/$base" >> "$LIST" ;;
                list) echo "$picked" >> "$LIST" ;;
            esac
            count=$((count+1))
        done < <(find "$vdir" -mindepth 1 -type d)
    done
done

echo "-------------------------------------------------------"
echo "collected $count lib(s); skipped $warn duplicate basename(s)"
echo "list: $LIST"
[ "$MODE" != list ] && echo "dir : $OUTDIR"

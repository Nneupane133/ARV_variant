#!/usr/bin/env bash
# Interactive BAM viewer using samtools tview.
#
# Opens the sorted BAM file aligned against the ARV reference in the terminal.
# Use keyboard shortcuts to navigate:
#
#   Arrow keys / h j k l  — scroll left/right/up/down
#   g                     — go to position  (e.g. KU169288:100)
#   n                     — go to next variant
#   b                     — toggle base quality display
#   i                     — toggle insert size display
#   c                     — toggle color mode
#   .                     — toggle dot/base display
#   q  or  Ctrl+C         — quit
#
# Usage:
#   bash view_bam.sh [SAMPLE_ID] [BAM_DIR] [REFERENCE] [POSITION]
#
# Arguments (defaults shown):
#   SAMPLE_ID  - SRR/sample ID               (default: SRR12620879)
#   BAM_DIR    - Directory with sorted BAM   (default: arv_mapping_results)
#   REFERENCE  - ARV reference FASTA         (default: avian_reovirus.fa)
#   POSITION   - Start position              (default: KU169288:1)
#
# Examples:
#   bash view_bam.sh
#   bash view_bam.sh SRR12620879
#   bash view_bam.sh SRR12620879 arv_mapping_results avian_reovirus.fa KU169290:500

# ── arguments / defaults ──────────────────────────────────────────────────────
SAMPLE_ID="${1:-SRR12620879}"
BAM_DIR="${2:-arv_mapping_results}"
REFERENCE="${3:-avian_reovirus.fa}"
POSITION="${4:-KU169288:1}"

SORTED_BAM="${BAM_DIR}/${SAMPLE_ID}.sorted.bam"

# ── dependency check ──────────────────────────────────────────────────────────
if ! command -v samtools &>/dev/null; then
    echo "Error: samtools not found." >&2
    exit 1
fi

# ── validate files ────────────────────────────────────────────────────────────
[[ -f "$SORTED_BAM" ]]     || { echo "Error: BAM not found: ${SORTED_BAM}" >&2; exit 1; }
[[ -f "${SORTED_BAM}.bai" ]] || { echo "Error: BAM index not found. Run: samtools index ${SORTED_BAM}" >&2; exit 1; }
[[ -f "$REFERENCE" ]]      || { echo "Error: Reference not found: ${REFERENCE}" >&2; exit 1; }

# ── show ARV segment names for navigation reference ───────────────────────────
echo "============================================================"
echo " BAM Viewer — samtools tview"
echo " Sample    : ${SAMPLE_ID}"
echo " BAM       : ${SORTED_BAM}"
echo " Reference : ${REFERENCE}"
echo " Starting  : ${POSITION}"
echo "------------------------------------------------------------"
echo " ARV Segments (use 'g' to jump):"
grep "^>" "$REFERENCE" | awk '{print "   " $1}' | tr -d '>'
echo "------------------------------------------------------------"
echo " Controls: arrows=scroll  g=goto  n=next variant  q=quit"
echo "============================================================"
echo ""

# ── open tview ────────────────────────────────────────────────────────────────
samtools tview \
    -p "$POSITION" \
    "$SORTED_BAM" \
    "$REFERENCE"
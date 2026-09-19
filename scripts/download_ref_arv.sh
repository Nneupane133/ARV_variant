#!/usr/bin/env bash
# Download Avian Orthoreovirus genome segments from NCBI GenBank
# and combine into a single FASTA file.
#
# Accessions : KU169288 – KU169297 (10 segments)
# Output     : avian_reovirus.fa (combined FASTA)
#
# Uses NCBI E-utilities API (no extra tools needed — only curl or wget).
#
# Usage:
#   ./download_arv_genome.sh [OUTPUT_DIR] [COMBINED_OUTPUT]
#
# Arguments (all optional — defaults shown):
#   OUTPUT_DIR       - Directory to save individual FASTA files  (default: arv_segments)
#   COMBINED_OUTPUT  - Name of the combined FASTA file           (default: avian_reovirus.fa)
#
# Example:
#   ./download_arv_genome.sh arv_segments avian_reovirus.fa

set -euo pipefail

# ── arguments / defaults ──────────────────────────────────────────────────────
OUTPUT_DIR="${1:-arv_segments}"
COMBINED_OUTPUT="${2:-avian_reovirus.fa}"

# ── GenBank accessions to download ───────────────────────────────────────────
ACCESSIONS=(
    KU169288
    KU169289
    KU169290
    KU169291
    KU169292
    KU169293
    KU169294
    KU169295
    KU169296
    KU169297
)

# NCBI E-utilities base URL
EFETCH_URL="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"

# ── dependency check ──────────────────────────────────────────────────────────
if command -v curl &>/dev/null; then
    DOWNLOADER="curl"
elif command -v wget &>/dev/null; then
    DOWNLOADER="wget"
else
    echo "Error: Neither curl nor wget found. Please install one." >&2
    exit 1
fi

# ── create output directory ───────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── download each accession as FASTA ─────────────────────────────────────────
echo "============================================================"
echo " Downloading ${#ACCESSIONS[@]} ARV genome segments from NCBI"
echo " → ${OUTPUT_DIR}/"
echo "============================================================"

FAILED=()

for ACC in "${ACCESSIONS[@]}"; do
    OUT_FILE="${OUTPUT_DIR}/${ACC}.fasta"

    if [[ -f "$OUT_FILE" && -s "$OUT_FILE" ]]; then
        echo "  [skip] ${ACC}.fasta already exists"
        continue
    fi

    echo "  Downloading ${ACC} ..."

    URL="${EFETCH_URL}?db=nucleotide&id=${ACC}&rettype=fasta&retmode=text"

    if [[ "$DOWNLOADER" == "curl" ]]; then
        curl -s -L --retry 3 --retry-delay 2 -o "$OUT_FILE" "$URL"
    else
        wget -q --tries=3 --waitretry=2 -O "$OUT_FILE" "$URL"
    fi

    # verify the file looks like a FASTA (starts with '>')
    if [[ ! -s "$OUT_FILE" ]] || ! grep -q "^>" "$OUT_FILE"; then
        echo "  [ERROR] Failed to download or invalid FASTA: ${ACC}" >&2
        rm -f "$OUT_FILE"
        FAILED+=("$ACC")
    else
        HEADER=$(grep "^>" "$OUT_FILE" | head -1)
        echo "  [OK]   ${ACC} → ${HEADER}"
    fi

    # be polite to NCBI — pause between requests
    sleep 0.5
done

# ── report any failures ───────────────────────────────────────────────────────
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo "WARNING: The following accessions failed to download:" >&2
    printf '  %s\n' "${FAILED[@]}" >&2
    echo "Check your internet connection or the accession numbers and retry." >&2
fi

# ── combine into single FASTA using cat ──────────────────────────────────────
echo ""
echo "============================================================"
echo " Combining segments into: ${COMBINED_OUTPUT}"
echo "============================================================"

# build list of files that exist and are non-empty
FASTA_FILES=()
for ACC in "${ACCESSIONS[@]}"; do
    FASTA="${OUTPUT_DIR}/${ACC}.fasta"
    if [[ -f "$FASTA" && -s "$FASTA" ]]; then
        FASTA_FILES+=("$FASTA")
    else
        echo "  WARNING: skipping missing/empty file: ${FASTA}" >&2
    fi
done

if [[ ${#FASTA_FILES[@]} -eq 0 ]]; then
    echo "Error: No FASTA files available to combine." >&2
    exit 1
fi

# cat all segments into one file in accession order
cat "${FASTA_FILES[@]}" > "$COMBINED_OUTPUT"

COUNT=${#FASTA_FILES[@]}

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Done!"
echo "  Segments combined   : ${COUNT} / ${#ACCESSIONS[@]}"
echo "  Individual FASTAs   : ${OUTPUT_DIR}/"
echo "  Combined FASTA      : ${COMBINED_OUTPUT}"
echo ""
echo "Sequences in combined file:"
grep "^>" "$COMBINED_OUTPUT"
echo ""
TOTAL_BASES=$(grep -v "^>" "$COMBINED_OUTPUT" | tr -d '\n\r ' | wc -c)
echo "Total bases in combined file: ${TOTAL_BASES}"
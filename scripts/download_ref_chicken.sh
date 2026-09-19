#!/usr/bin/env bash
# Download the Gallus gallus (chicken) genome from NCBI.
#
# NCBI nucleotide : AADN00000000.3  (WGS project)
# Assembly        : GCA_000002315.3 (Gallus_gallus-5.0)
# Output          : chicken_genome/GCA_000002315.3_genomic.fna
#
# Uses the NCBI Datasets REST API — same source as the NCBI website Download button.
# No extra tools required beyond curl or wget + unzip.
#
# Usage:
#   ./download_chicken_genome.sh [OUTPUT_DIR]
#
# Arguments (optional — default shown):
#   OUTPUT_DIR - Directory to save the genome  (default: chicken_genome)
#
# Example:
#   ./download_chicken_genome.sh chicken_genome

set -euo pipefail

# ── arguments / defaults ──────────────────────────────────────────────────────
OUTPUT_DIR="${1:-chicken_genome}"

# ── genome settings ───────────────────────────────────────────────────────────
# AADN00000000.3 (WGS nucleotide) corresponds to assembly GCA_000002315.3
ASSEMBLY="GCA_000002315.3"
GENOME_FASTA="${OUTPUT_DIR}/${ASSEMBLY}_genomic.fna"
ZIP_FILE="${OUTPUT_DIR}/ncbi_dataset.zip"

# NCBI Datasets API URL
API_URL="https://api.ncbi.nlm.nih.gov/datasets/v2/genome/accession/${ASSEMBLY}/download?include_annotation_type=GENOME_FASTA&filename=ncbi_dataset.zip"

# ── dependency check ──────────────────────────────────────────────────────────
if ! command -v unzip &>/dev/null; then
    echo "Error: 'unzip' not found. Please install it." >&2
    exit 1
fi

if command -v curl &>/dev/null; then
    DOWNLOADER="curl"
elif command -v wget &>/dev/null; then
    DOWNLOADER="wget"
else
    echo "Error: Neither curl nor wget found." >&2
    exit 1
fi

# ── skip if already downloaded ────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

if [[ -f "$GENOME_FASTA" && -s "$GENOME_FASTA" ]]; then
    echo "Genome already exists — skipping download: ${GENOME_FASTA}"
    echo ""
    echo "File info:"
    ls -lh "$GENOME_FASTA"
    echo "Sequences in file:"
    grep -c "^>" "$GENOME_FASTA" || true
    exit 0
fi

# ── download zip ──────────────────────────────────────────────────────────────
echo "============================================================"
echo " Downloading Gallus gallus genome"
echo " NCBI WGS   : AADN00000000.3"
echo " Assembly   : ${ASSEMBLY} (Gallus_gallus-5.0)"
echo " Output dir : ${OUTPUT_DIR}/"
echo " Size       : ~703 MB"
echo "============================================================"
echo ""
echo "Downloading from NCBI Datasets API ..."

if [[ "$DOWNLOADER" == "curl" ]]; then
    curl -L --progress-bar --retry 3 --retry-delay 5 \
         -o "$ZIP_FILE" "$API_URL"
else
    wget --progress=bar:force --tries=3 --waitretry=5 \
         -O "$ZIP_FILE" "$API_URL"
fi

echo ""
echo "Download complete. Extracting FASTA ..."

# ── extract FASTA ─────────────────────────────────────────────────────────────
unzip -o "$ZIP_FILE" -d "$OUTPUT_DIR"

# locate .fna inside extracted folder
FOUND=$(find "${OUTPUT_DIR}/ncbi_dataset/data/${ASSEMBLY}" \
             -name "*.fna" 2>/dev/null | head -1)

if [[ -z "$FOUND" ]]; then
    echo "Error: .fna file not found in the downloaded zip. Contents:" >&2
    find "$OUTPUT_DIR" -type f >&2
    exit 1
fi

mv "$FOUND" "$GENOME_FASTA"
echo "Genome saved: ${GENOME_FASTA}"

# ── clean up ──────────────────────────────────────────────────────────────────
rm -f "$ZIP_FILE"
rm -rf "${OUTPUT_DIR}/ncbi_dataset" "${OUTPUT_DIR}/README.md"
echo "Cleaned up temporary files."

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Done! Chicken genome ready."
echo "  File    : ${GENOME_FASTA}"
echo "  Size    : $(ls -lh "$GENOME_FASTA" | awk '{print $5}')"
echo "  Contigs : $(grep -c '^>' "$GENOME_FASTA") sequences"
echo "============================================================"
echo ""
echo "Next step — index and map with BWA:"
echo "  bash run_bwa_mapping.sh SRR12620879 ${GENOME_FASTA}"
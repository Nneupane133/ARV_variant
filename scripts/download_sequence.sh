#!/usr/bin/env bash
# Download and convert SRA data from NCBI using prefetch and fasterq-dump.
# Uses SRA Toolkit commands "prefetch" and "fasterq-dump" to download
# sequencing data and convert it into FASTQ format.
#
# Usage:
#   ./download_sra_data.sh <SRR_ID> <OUTPUT_DIR>
#
# Arguments:
#   SRR_ID      - The SRA accession ID (e.g., SRR12620879)
#   OUTPUT_DIR  - Directory where the FASTQ files will be saved
#
# Example:
#   ./download_sra_data.sh SRR12620879 data

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────
usage() {
    echo "Usage: $0 <SRR_ID> <OUTPUT_DIR>"
    echo "  SRR_ID     - SRA accession ID (e.g., SRR12620879)"
    echo "  OUTPUT_DIR - Directory where FASTQ files will be saved"
    exit 1
}

# ── argument handling ─────────────────────────────────────────────────────────
if [[ $# -lt 2 ]]; then
    # Fall back to defaults when called with no arguments (mirrors __main__ block)
    SRR_ID="SRR12620879"
    OUTPUT_DIR="data"  
    echo "No arguments provided — using defaults: SRR_ID=${SRR_ID}, OUTPUT_DIR=${OUTPUT_DIR}"
else
    SRR_ID="$1"
    OUTPUT_DIR="$2"
fi

# ── dependency check ──────────────────────────────────────────────────────────
for cmd in prefetch fasterq-dump; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' not found. Please install the SRA Toolkit." >&2
        exit 1
    fi
done

# ── main ──────────────────────────────────────────────────────────────────────
# Create output directory if it does not exist
mkdir -p "$OUTPUT_DIR"

echo "Starting download for ${SRR_ID} → ${OUTPUT_DIR}"

# Download SRA file from NCBI
if prefetch "$SRR_ID"; then
    echo "prefetch completed for ${SRR_ID}"
else
    echo "Error occurred during prefetch for ${SRR_ID}" >&2
    exit 1
fi

# Convert SRA file to FASTQ format
if fasterq-dump "$SRR_ID" \
        -O "$OUTPUT_DIR" \
        --split-files \
        --threads 4; then
    echo "Download and conversion completed successfully!"
else
    echo "Error occurred during fasterq-dump for ${SRR_ID}" >&2
    exit 1
fi
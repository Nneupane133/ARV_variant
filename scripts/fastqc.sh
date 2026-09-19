#!/usr/bin/env bash
# Run FastQC on paired-end FASTQ files in a directory.
# Identifies .fastq and .fastq.gz files in the input directory and performs
# quality control (QC) analysis using the FastQC tool.
#
# Usage:
#   ./run_fastqc.sh [INPUT_DIR] [OUTPUT_DIR] [THREADS]
#
# Arguments (all optional — defaults shown):
#   INPUT_DIR   - Directory containing FASTQ files       (default: data)
#   OUTPUT_DIR  - Directory where FastQC results go      (default: fastqc_results)
#   THREADS     - Number of threads for parallel processing (default: 2)
#
# Example:
#   ./run_fastqc.sh data fastqc_results 4

set -euo pipefail

# ── defaults (mirror Python __main__ block) ───────────────────────────────────
INPUT_DIR="${1:-data}"
OUTPUT_DIR="${2:-fastqc_results}"
THREADS="${3:-2}"

# ── dependency check ──────────────────────────────────────────────────────────
if ! command -v fastqc &>/dev/null; then
    echo "Error: 'fastqc' not found. Please install FastQC." >&2
    exit 1
fi

# ── validate input directory ──────────────────────────────────────────────────
if [[ ! -d "$INPUT_DIR" ]]; then
    echo "Error: Input directory not found: ${INPUT_DIR}" >&2
    exit 1
fi

# ── collect FASTQ files (sorted, mirrors Python logic) ────────────────────────
mapfile -t FASTQ_FILES < <(
    find "$INPUT_DIR" -maxdepth 1 -type f \( -name "*.fastq" -o -name "*.fastq.gz" \) \
    | sort
)

if [[ ${#FASTQ_FILES[@]} -eq 0 ]]; then
    echo "Error: No FASTQ files found in: ${INPUT_DIR}" >&2
    exit 1
fi

echo "Found ${#FASTQ_FILES[@]} FASTQ file(s) in '${INPUT_DIR}':"
printf '  %s\n' "${FASTQ_FILES[@]}"

# ── create output directory ───────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── run FastQC ────────────────────────────────────────────────────────────────
echo "Running FastQC with ${THREADS} thread(s) → ${OUTPUT_DIR}"

if fastqc -t "$THREADS" -o "$OUTPUT_DIR" "${FASTQ_FILES[@]}"; then
    echo "FastQC completed successfully! Results are in: ${OUTPUT_DIR}"
else
    echo "Error: FastQC failed." >&2
    exit 1
fi
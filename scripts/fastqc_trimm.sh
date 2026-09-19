#!/usr/bin/env bash
# Run FastQC on trimmed paired-end FASTQ files in a directory.
# Scans the input directory for .fastq and .fastq.gz files and performs
# quality control analysis using FastQC. Outputs HTML and ZIP reports.
#
# Usage:
#   ./run_trimmed_fastqc.sh [INPUT_DIR] [OUTPUT_DIR] [THREADS]
#
# Arguments (all optional — defaults shown):
#   INPUT_DIR   - Directory containing trimmed FASTQ files    (default: trimmed_data)
#   OUTPUT_DIR  - Directory where FastQC results will be saved (default: trimmed_fastqc_results)
#   THREADS     - Number of CPU threads                        (default: 2)
#
# Example:
#   ./run_trimmed_fastqc.sh trimmed_data trimmed_fastqc_results 4

set -euo pipefail

# ── defaults (mirror Python __main__ block) ───────────────────────────────────
INPUT_DIR="${1:-trimmed_data}"
OUTPUT_DIR="${2:-trimmed_fastqc_results}"
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

# ── collect FASTQ files (sorted) ─────────────────────────────────────────────
mapfile -t FASTQ_FILES < <(
    find "$INPUT_DIR" -maxdepth 1 -type f \( -name "*.fastq" -o -name "*.fastq.gz" \) \
    | sort
)

if [[ ${#FASTQ_FILES[@]} -eq 0 ]]; then
    echo "Error: No FASTQ files found in: ${INPUT_DIR}" >&2
    exit 1
fi

echo "Found ${#FASTQ_FILES[@]} trimmed FASTQ file(s) in '${INPUT_DIR}':"
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
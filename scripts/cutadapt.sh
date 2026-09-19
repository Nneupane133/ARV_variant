#!/usr/bin/env bash
# Trim paired-end FASTQ files using cutadapt.
# Trims 5'/3' ends, applies quality filtering, and removes short reads.
# Raw FASTQ files are preserved in the input directory.
#
# Usage:
#   ./run_cutadapt.sh <SAMPLE_ID> [INPUT_DIR] [OUTPUT_DIR] [THREADS] [TRIM_5] [TRIM_3] [QUALITY] [MIN_LEN]
#
# Arguments (defaults shown):
#   SAMPLE_ID   - SRR/sample ID, e.g. SRR12620879         (required)
#   INPUT_DIR   - Directory with raw FASTQ files           (default: data)
#   OUTPUT_DIR  - Directory for trimmed files              (default: trimmed_data)
#   THREADS     - CPU threads                              (default: 4)
#   TRIM_5      - Bases to trim from 5' end               (default: 10)
#   TRIM_3      - Bases to trim from 3' end               (default: 10)
#   QUALITY     - Quality cutoff (set 0 to skip)          (default: 20)
#   MIN_LEN     - Minimum read length to retain           (default: 30)
#
# Example:
#   ./run_cutadapt.sh SRR12620879 data trimmed_data 4 10 10 20 30

set -euo pipefail

# ── arguments / defaults ──────────────────────────────────────────────────────
SAMPLE_ID="${1:?Error: SAMPLE_ID is required. Usage: $0 <SAMPLE_ID> [INPUT_DIR] [OUTPUT_DIR] ...}"
INPUT_DIR="${2:-data}"
OUTPUT_DIR="${3:-trimmed_data}"
THREADS="${4:-4}"
TRIM_5="${5:-4}"
TRIM_3="${6:-4}"
QUALITY="${7:-10}"
MIN_LEN="${8:-5}"

# ── dependency check ──────────────────────────────────────────────────────────
if ! command -v cutadapt &>/dev/null; then
    echo "Error: 'cutadapt' not found. Please install cutadapt." >&2
    exit 1
fi

# ── input files ───────────────────────────────────────────────────────────────
R1="${INPUT_DIR}/${SAMPLE_ID}_1.fastq"
R2="${INPUT_DIR}/${SAMPLE_ID}_2.fastq"

if [[ ! -f "$R1" || ! -f "$R2" ]]; then
    echo "Error: FASTQ files for ${SAMPLE_ID} not found." >&2
    echo "  Expected: ${R1}" >&2
    echo "  Expected: ${R2}" >&2
    exit 1
fi

# ── output files (only trimmed FASTQs — what downstream steps need) ───────────
mkdir -p "$OUTPUT_DIR"
OUT_R1="${OUTPUT_DIR}/${SAMPLE_ID}_1.trimmed.fastq"
OUT_R2="${OUTPUT_DIR}/${SAMPLE_ID}_2.trimmed.fastq"

# ── build cutadapt command ────────────────────────────────────────────────────
CMD=(
    cutadapt
    -j "$THREADS"
    -u "$TRIM_5"          # trim N bases from 5' end
    -u "-${TRIM_3}"       # trim N bases from 3' end
    -m "$MIN_LEN"         # discard reads shorter than MIN_LEN
    -o "$OUT_R1"
    -p "$OUT_R2"
)

# add quality trimming only if QUALITY > 0
if [[ "$QUALITY" -gt 0 ]]; then
    CMD+=(-q "${QUALITY},${QUALITY}")
fi

CMD+=("$R1" "$R2")

# ── run cutadapt ──────────────────────────────────────────────────────────────
echo "Trimming ${SAMPLE_ID} ..."
echo "  Input  : ${R1}  ${R2}"
echo "  Output : ${OUT_R1}  ${OUT_R2}"
echo "  Settings: 5'=${TRIM_5}  3'=${TRIM_3}  quality=${QUALITY}  min_len=${MIN_LEN}"

if "${CMD[@]}"; then
    echo "Trimming completed successfully!"
else
    echo "Error: cutadapt failed for ${SAMPLE_ID}." >&2
    exit 1
fi

echo "Done. Trimmed files ready in: ${OUTPUT_DIR}/"
echo "Raw files preserved in: ${INPUT_DIR}/"
#!/usr/bin/env bash
# Index the Avian Orthoreovirus (ARV) reference genome and align host-filtered
# (unmapped) paired-end reads using BWA-MEM.
#
# Input: unmapped reads from host filtering (chicken genome removed)
#        These are the viral / non-host reads output by bwa_host_filter.sh
#
# Workflow:
#   1. BWA index reference (skipped if already indexed)
#   2. samtools faidx index (skipped if already exists)
#   3. BWA-MEM alignment → SAM
#   4. SAM → BAM (SAM deleted to save space)
#   5. Sort BAM
#   6. Index sorted BAM
#   7. Print alignment summary (flagstat)
#
# Usage:
#   ./run_arv_mapping.sh <SAMPLE_ID> [REFERENCE] [INPUT_DIR] [OUTPUT_DIR] [THREADS]
#
# Arguments (defaults shown):
#   SAMPLE_ID   - SRR/sample ID, e.g. SRR12620879                 (required)
#   REFERENCE   - Path to ARV reference FASTA                      (default: avian_reovirus.fa)
#   INPUT_DIR   - Directory with unmapped FASTQ files              (default: host_filter_results)
#   OUTPUT_DIR  - Directory for mapping outputs                    (default: arv_mapping_results)
#   THREADS     - CPU threads for BWA and samtools                 (default: 4)
#
# Input files expected:
#   {INPUT_DIR}/{SAMPLE_ID}_unmapped_1.fastq
#   {INPUT_DIR}/{SAMPLE_ID}_unmapped_2.fastq
#
# Example:
#   ./run_arv_mapping.sh SRR12620879 avian_reovirus.fa host_filter_results arv_mapping_results 4

set -euo pipefail

# ── arguments / defaults ──────────────────────────────────────────────────────
SAMPLE_ID="${1:?Error: SAMPLE_ID is required. Usage: $0 <SAMPLE_ID> [REFERENCE] [INPUT_DIR] [OUTPUT_DIR] [THREADS]}"
REFERENCE="${2:-avian_reovirus.fa}"
INPUT_DIR="${3:-host_filter_results}"
OUTPUT_DIR="${4:-arv_mapping_results}"
THREADS="${5:-4}"

# ── dependency check ──────────────────────────────────────────────────────────
for cmd in bwa samtools; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' not found. Please install it." >&2
        exit 1
    fi
done

# ── validate inputs ───────────────────────────────────────────────────────────
R1="${INPUT_DIR}/${SAMPLE_ID}_unmapped_1.fastq"
R2="${INPUT_DIR}/${SAMPLE_ID}_unmapped_2.fastq"

[[ -f "$REFERENCE" ]] || { echo "Error: Reference not found: ${REFERENCE}" >&2; exit 1; }
[[ -f "$R1" ]]        || { echo "Error: R1 not found: ${R1}" >&2; exit 1; }
[[ -f "$R2" ]]        || { echo "Error: R2 not found: ${R2}" >&2; exit 1; }

# ── create output directory ───────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── output file paths ─────────────────────────────────────────────────────────
SAM_FILE="${OUTPUT_DIR}/${SAMPLE_ID}.sam"
BAM_FILE="${OUTPUT_DIR}/${SAMPLE_ID}.bam"
SORTED_BAM="${OUTPUT_DIR}/${SAMPLE_ID}.sorted.bam"

echo "============================================================"
echo " ARV Mapping Pipeline"
echo " Sample    : ${SAMPLE_ID}"
echo " Reference : ${REFERENCE}"
echo " Input     : ${R1}"
echo "           : ${R2}"
echo " Output    : ${OUTPUT_DIR}/"
echo " Threads   : ${THREADS}"
echo "============================================================"

# ── step 1: BWA index (skip if already done) ──────────────────────────────────
INDEX_MISSING=false
for ext in .amb .ann .bwt .pac .sa; do
    [[ -f "${REFERENCE}${ext}" ]] || { INDEX_MISSING=true; break; }
done

if $INDEX_MISSING; then
    echo ""
    echo "[Step 1] Indexing reference genome with BWA ..."
    echo "  CMD: bwa index ${REFERENCE}"
    bwa index "$REFERENCE"
    echo "  BWA index complete."
else
    echo ""
    echo "[Step 1] BWA index already exists — skipping."
fi

# ── step 2: samtools faidx index (skip if already done) ──────────────────────
if [[ ! -f "${REFERENCE}.fai" ]]; then
    echo ""
    echo "[Step 2] Creating samtools FASTA index ..."
    echo "  CMD: samtools faidx ${REFERENCE}"
    samtools faidx "$REFERENCE"
    echo "  FASTA index complete."
else
    echo ""
    echo "[Step 2] FASTA index (.fai) already exists — skipping."
fi

# ── step 3: BWA-MEM alignment → SAM ──────────────────────────────────────────
echo ""
echo "[Step 3] Aligning reads with BWA-MEM ..."
echo "  CMD: bwa mem -t ${THREADS} ${REFERENCE} ${R1} ${R2} > ${SAM_FILE}"
bwa mem -t "$THREADS" "$REFERENCE" "$R1" "$R2" > "$SAM_FILE"
echo "  Alignment complete."

# ── step 4: SAM → BAM ────────────────────────────────────────────────────────
echo ""
echo "[Step 4] Converting SAM to BAM ..."
echo "  CMD: samtools view -@ ${THREADS} -bS ${SAM_FILE} > ${BAM_FILE}"
samtools view -@ "$THREADS" -bS "$SAM_FILE" > "$BAM_FILE"
rm -f "$SAM_FILE"
echo "  SAM deleted to save space."

# ── step 5: sort BAM ──────────────────────────────────────────────────────────
echo ""
echo "[Step 5] Sorting BAM ..."
echo "  CMD: samtools sort -@ ${THREADS} -o ${SORTED_BAM} ${BAM_FILE}"
samtools sort -@ "$THREADS" -o "$SORTED_BAM" "$BAM_FILE"
rm -f "$BAM_FILE"
echo "  Unsorted BAM deleted."

# ── step 6: index sorted BAM ──────────────────────────────────────────────────
echo ""
echo "[Step 6] Indexing sorted BAM ..."
echo "  CMD: samtools index ${SORTED_BAM}"
samtools index "$SORTED_BAM"
echo "  Index complete."

# ── step 7: alignment summary ─────────────────────────────────────────────────
echo ""
echo "[Step 7] Alignment summary (flagstat):"
echo "------------------------------------------------------------"
samtools flagstat "$SORTED_BAM"
echo "------------------------------------------------------------"

# ── final summary ─────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Mapping complete for: ${SAMPLE_ID}"
echo "  Sorted BAM : ${SORTED_BAM}"
echo "  BAM index  : ${SORTED_BAM}.bai"
echo "============================================================"
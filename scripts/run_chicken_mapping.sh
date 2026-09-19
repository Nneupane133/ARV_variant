#!/bin/bash
#
# ============================================================
#  ASC Job: BWA Host Filtering — Chicken Genome
#
#  Submit with:  run_script bwa_host_filter_job.sh
#  Resources are set via .asc_queue file (NOT #PBS directives)
# ============================================================
#
# Align trimmed paired-end reads to the Gallus gallus reference genome,
# then extract unmapped read pairs (viral / non-host reads) as FASTQ.
#
# Pipeline:
#   1.  BWA index reference              (skipped if already indexed)
#   2.  samtools faidx                   (skipped if already exists)
#   3.  BWA-MEM alignment → SAM
#   4.  SAM → BAM  (SAM deleted)
#   5.  Sort BAM   (unsorted BAM deleted)
#   6.  Index sorted BAM
#   7.  Alignment summary (flagstat)
#   8.  Extract unmapped read pairs (-f 12 -F 256)
#   9.  Unmapped BAM → paired FASTQ
#
# Note: Chicken genome expected at chicken_genome/GCA_000002315.3_genomic.fna
#
# Submit:
#   qsub bwa_host_filter_job.sh
#
# Monitor:
#   qstat -u $USER
#   tail -f bwa_host_filter.log
#
# ── settings — edit these before submitting ───────────────────────────────────
SAMPLE_ID="SRR12620879"
REFERENCE="chicken_genome/GCA_000002315.3_genomic.fna"
INPUT_DIR="trimmed_data"
OUTPUT_DIR="host_filter_results"
THREADS=8
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── resolve project root ───────────────────────────────────────────────────────
# When submitted via qsub, PBS_O_WORKDIR is the directory where qsub was run.
# When run interactively, fall back to one level above the scripts/ directory.
cd "${PBS_O_WORKDIR:-$(dirname "$0")/..}" || exit 1

echo "============================================================"
echo " BWA Host Filtering Job"
echo " Sample    : ${SAMPLE_ID}"
echo " Reference : ${REFERENCE}"
echo " Threads   : ${THREADS}"
echo " Started   : $(date)"
echo " Host      : $(hostname)"
echo " Directory : $(pwd)"
echo "============================================================"

# ── dependency check ──────────────────────────────────────────────────────────
for cmd in bwa samtools; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' not found." >&2
        exit 1
    fi
done

# ── validate trimmed input files ──────────────────────────────────────────────
R1="${INPUT_DIR}/${SAMPLE_ID}_1.trimmed.fastq"
R2="${INPUT_DIR}/${SAMPLE_ID}_2.trimmed.fastq"

[[ -f "$R1" ]] || { echo "Error: R1 not found: ${R1}" >&2; exit 1; }
[[ -f "$R2" ]] || { echo "Error: R2 not found: ${R2}" >&2; exit 1; }

echo ""
echo "Input files confirmed:"
echo "  R1: ${R1}  ($(wc -l < "$R1" | awk '{print $1/4}') reads)"
echo "  R2: ${R2}  ($(wc -l < "$R2" | awk '{print $1/4}') reads)"

# ── validate reference ────────────────────────────────────────────────────────
[[ -f "$REFERENCE" && -s "$REFERENCE" ]] || {
    echo "Error: Reference genome not found: ${REFERENCE}" >&2
    exit 1
}
echo "Reference genome confirmed: ${REFERENCE}"

# ══════════════════════════════════════════════════════════════
# STEP 1 — BWA index (skip if already done)
# ══════════════════════════════════════════════════════════════
echo ""
echo "------------------------------------------------------------"
echo "[Step 1] BWA index"
echo "------------------------------------------------------------"

INDEX_MISSING=false
for ext in .amb .ann .bwt .pac .sa; do
    [[ -f "${REFERENCE}${ext}" ]] || { INDEX_MISSING=true; break; }
done

if $INDEX_MISSING; then
    echo "  Indexing reference (this takes ~10 min for the chicken genome) ..."
    bwa index "$REFERENCE"
    echo "  BWA index complete."
else
    echo "  BWA index already exists — skipping."
fi

# ══════════════════════════════════════════════════════════════
# STEP 2 — samtools faidx (skip if already done)
# ══════════════════════════════════════════════════════════════
echo ""
echo "------------------------------------------------------------"
echo "[Step 2] samtools faidx"
echo "------------------------------------------------------------"

if [[ ! -f "${REFERENCE}.fai" ]]; then
    samtools faidx "$REFERENCE"
    echo "  FASTA index created."
else
    echo "  FASTA index already exists — skipping."
fi

# ══════════════════════════════════════════════════════════════
# STEP 4 — BWA-MEM alignment → SAM
# ══════════════════════════════════════════════════════════════
mkdir -p "$OUTPUT_DIR"

SAM_FILE="${OUTPUT_DIR}/${SAMPLE_ID}.sam"
BAM_FILE="${OUTPUT_DIR}/${SAMPLE_ID}.bam"
SORTED_BAM="${OUTPUT_DIR}/${SAMPLE_ID}.sorted.bam"
UNMAPPED_BAM="${OUTPUT_DIR}/${SAMPLE_ID}.unmapped.bam"
UNMAPPED_R1="${OUTPUT_DIR}/${SAMPLE_ID}_unmapped_1.fastq"
UNMAPPED_R2="${OUTPUT_DIR}/${SAMPLE_ID}_unmapped_2.fastq"
UNMAPPED_SINGLE="${OUTPUT_DIR}/${SAMPLE_ID}_unmapped_single.fastq"

echo ""
echo "------------------------------------------------------------"
echo "[Step 3] BWA-MEM alignment"
echo "------------------------------------------------------------"
echo "  CMD: bwa mem -t ${THREADS} ${REFERENCE} ${R1} ${R2}"
bwa mem -t "$THREADS" "$REFERENCE" "$R1" "$R2" > "$SAM_FILE"
echo "  Alignment complete."

# ══════════════════════════════════════════════════════════════
# STEP 5 — SAM → BAM
# ══════════════════════════════════════════════════════════════
echo ""
echo "------------------------------------------------------------"
echo "[Step 4] SAM → BAM"
echo "------------------------------------------------------------"
samtools view -@ "$THREADS" -bS "$SAM_FILE" > "$BAM_FILE"
rm -f "$SAM_FILE"
echo "  Converted. SAM deleted."

# ══════════════════════════════════════════════════════════════
# STEP 6 — Sort BAM
# ══════════════════════════════════════════════════════════════
echo ""
echo "------------------------------------------------------------"
echo "[Step 5] Sort BAM"
echo "------------------------------------------------------------"
samtools sort -@ "$THREADS" -o "$SORTED_BAM" "$BAM_FILE"
rm -f "$BAM_FILE"
echo "  Sorted. Unsorted BAM deleted."

# ══════════════════════════════════════════════════════════════
# STEP 7 — Index sorted BAM
# ══════════════════════════════════════════════════════════════
echo ""
echo "------------------------------------------------------------"
echo "[Step 6] Index sorted BAM"
echo "------------------------------------------------------------"
samtools index "$SORTED_BAM"
echo "  Index created: ${SORTED_BAM}.bai"

# ══════════════════════════════════════════════════════════════
# STEP 8 — Alignment summary
# ══════════════════════════════════════════════════════════════
echo ""
echo "------------------------------------------------------------"
echo "[Step 7] Alignment summary (flagstat)"
echo "------------------------------------------------------------"
samtools flagstat "$SORTED_BAM"

# ══════════════════════════════════════════════════════════════
# STEP 9 — Extract unmapped read pairs
# -f 12  : both reads unmapped (flag 4 + flag 8)
# -F 256 : exclude secondary alignments
# ══════════════════════════════════════════════════════════════
echo ""
echo "------------------------------------------------------------"
echo "[Step 8] Extract unmapped read pairs"
echo "------------------------------------------------------------"
samtools view -@ "$THREADS" -b -f 12 -F 256 "$SORTED_BAM" > "$UNMAPPED_BAM"
UNMAPPED_COUNT=$(samtools view -c "$UNMAPPED_BAM")
echo "  Unmapped reads extracted: ${UNMAPPED_COUNT}"

# ══════════════════════════════════════════════════════════════
# STEP 10 — Unmapped BAM → paired FASTQ
# ══════════════════════════════════════════════════════════════
echo ""
echo "------------------------------------------------------------"
echo "[Step 9] Unmapped BAM → paired FASTQ"
echo "------------------------------------------------------------"
samtools fastq \
    -@ "$THREADS" \
    -1 "$UNMAPPED_R1" \
    -2 "$UNMAPPED_R2" \
    -0 /dev/null \
    -s "$UNMAPPED_SINGLE" \
    -n \
    "$UNMAPPED_BAM"

R1_READS=$(( $(wc -l < "$UNMAPPED_R1") / 4 ))
R2_READS=$(( $(wc -l < "$UNMAPPED_R2") / 4 ))

# ══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ══════════════════════════════════════════════════════════════
echo ""
echo "============================================================"
echo " Pipeline complete!"
echo " Finished : $(date)"
echo "------------------------------------------------------------"
echo "  Sorted BAM (host)  : ${SORTED_BAM}"
echo "  Unmapped BAM       : ${UNMAPPED_BAM}"
echo "  Unmapped R1 FASTQ  : ${UNMAPPED_R1}  (${R1_READS} reads)"
echo "  Unmapped R2 FASTQ  : ${UNMAPPED_R2}  (${R2_READS} reads)"
echo "------------------------------------------------------------"
echo " Next step — map unmapped reads to ARV reference:"
echo "   bash run_arv_mapping.sh ${SAMPLE_ID} avian_reovirus.fa ${OUTPUT_DIR} arv_mapping_results"
echo "============================================================"

#!/usr/bin/env bash
# Align trimmed paired-end reads to a reference genome using BWA-MEM,
# then extract unmapped read pairs as FASTQ files (host filtering).
#
# Workflow:
#   1. Index reference genome (BWA + samtools) if not already indexed
#   2. BWA-MEM alignment → SAM
#   3. SAM → BAM conversion
#   4. Sort and index BAM
#   5. Extract unmapped read pairs (-f 12 -F 256)
#   6. Convert unmapped BAM → paired FASTQ
#
# Usage:
#   ./run_bwa_mapping.sh <SAMPLE_ID> <REFERENCE_FASTA> [INPUT_DIR] [OUTPUT_DIR] [THREADS]
#
# Arguments (defaults shown):
#   SAMPLE_ID        - SRR/sample ID, e.g. SRR12620879                         (required)
#   REFERENCE_FASTA  - Path to reference genome FASTA, e.g. chicken genome     (required)
#   INPUT_DIR        - Directory with trimmed FASTQ files                       (default: trimmed_data)
#   OUTPUT_DIR       - Directory to save mapping outputs                        (default: refmap_results)
#   THREADS          - CPU threads for BWA and samtools                         (default: 4)
#
# Example:
#   ./run_bwa_mapping.sh SRR12620879 reference/GCA_000002315.3_genomic.fna trimmed_data refmap_results 4

set -euo pipefail

# ── helper: print + run a command ────────────────────────────────────────────
run_cmd() {
    local description="$1"; shift
    echo ""
    echo "Running: ${description}"
    echo "  CMD: $*"
    "$@"
}

# ── arguments / defaults ──────────────────────────────────────────────────────
SAMPLE_ID="${1:?Error: SAMPLE_ID is required.}"
REFERENCE_FASTA="${2:-reference/GCA_000002315.3_genomic.fna}"
INPUT_DIR="${3:-trimmed_data}"
OUTPUT_DIR="${4:-refmap_results}"
THREADS="${5:-4}"

# ── dependency check ──────────────────────────────────────────────────────────
for cmd in bwa samtools; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' not found. Please install it." >&2
        exit 1
    fi
done

# ── validate input files ──────────────────────────────────────────────────────
R1="${INPUT_DIR}/${SAMPLE_ID}_1.trimmed.fastq"
R2="${INPUT_DIR}/${SAMPLE_ID}_2.trimmed.fastq"

[[ -f "$R1" ]]              || { echo "Error: Missing R1: ${R1}" >&2; exit 1; }
[[ -f "$R2" ]]              || { echo "Error: Missing R2: ${R2}" >&2; exit 1; }
[[ -f "$REFERENCE_FASTA" ]] || { echo "Error: Missing reference: ${REFERENCE_FASTA}" >&2; exit 1; }

# ── create output directory ───────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── define output file paths ──────────────────────────────────────────────────
SAM_FILE="${OUTPUT_DIR}/${SAMPLE_ID}.sam"
BAM_FILE="${OUTPUT_DIR}/${SAMPLE_ID}.bam"
SORTED_BAM="${OUTPUT_DIR}/${SAMPLE_ID}.sorted.bam"
UNMAPPED_BAM="${OUTPUT_DIR}/${SAMPLE_ID}.unmapped.bam"
UNMAPPED_R1="${OUTPUT_DIR}/${SAMPLE_ID}_unmapped_1.fastq"
UNMAPPED_R2="${OUTPUT_DIR}/${SAMPLE_ID}_unmapped_2.fastq"
UNMAPPED_SINGLE="${OUTPUT_DIR}/${SAMPLE_ID}_unmapped_single.fastq"

# ── step 1: BWA index (only if missing) ──────────────────────────────────────
INDEX_MISSING=false
for ext in .amb .ann .bwt .pac .sa; do
    [[ -f "${REFERENCE_FASTA}${ext}" ]] || { INDEX_MISSING=true; break; }
done

if $INDEX_MISSING; then
    run_cmd "Indexing reference genome (BWA): ${REFERENCE_FASTA}" \
        bwa index "$REFERENCE_FASTA"
else
    echo "BWA index already exists — skipping indexing."
fi

# ── step 2: samtools FASTA index (.fai) (only if missing) ────────────────────
if [[ ! -f "${REFERENCE_FASTA}.fai" ]]; then
    run_cmd "Creating FASTA index: ${REFERENCE_FASTA}.fai" \
        samtools faidx "$REFERENCE_FASTA"
else
    echo "FASTA index (.fai) already exists — skipping."
fi

# ── step 3: BWA-MEM alignment → SAM ──────────────────────────────────────────
echo ""
echo "Running: BWA-MEM alignment for ${SAMPLE_ID}"
echo "  CMD: bwa mem -t ${THREADS} ${REFERENCE_FASTA} ${R1} ${R2} > ${SAM_FILE}"
bwa mem -t "$THREADS" "$REFERENCE_FASTA" "$R1" "$R2" > "$SAM_FILE"

# ── step 4: SAM → BAM ────────────────────────────────────────────────────────
echo ""
echo "Running: SAM to BAM conversion for ${SAMPLE_ID}"
echo "  CMD: samtools view -@ ${THREADS} -bS ${SAM_FILE} > ${BAM_FILE}"
samtools view -@ "$THREADS" -bS "$SAM_FILE" > "$BAM_FILE"

# Remove SAM immediately to save disk space
rm -f "$SAM_FILE"
echo "  Removed intermediate SAM file."

# ── step 5: sort BAM ──────────────────────────────────────────────────────────
run_cmd "Sorting BAM for ${SAMPLE_ID}" \
    samtools sort -@ "$THREADS" -o "$SORTED_BAM" "$BAM_FILE"

# Remove unsorted BAM to save space
rm -f "$BAM_FILE"

# ── step 6: index sorted BAM ──────────────────────────────────────────────────
run_cmd "Indexing sorted BAM for ${SAMPLE_ID}" \
    samtools index "$SORTED_BAM"

# ── step 7: extract unmapped read pairs ───────────────────────────────────────
# -f 12  : both reads unmapped (flag 4 + flag 8)
# -F 256 : exclude secondary alignments
echo ""
echo "Running: Extracting unmapped read pairs for ${SAMPLE_ID}"
echo "  CMD: samtools view -@ ${THREADS} -b -f 12 -F 256 ${SORTED_BAM} > ${UNMAPPED_BAM}"
samtools view -@ "$THREADS" -b -f 12 -F 256 "$SORTED_BAM" > "$UNMAPPED_BAM"

# ── step 8: unmapped BAM → paired FASTQ ──────────────────────────────────────
run_cmd "Converting unmapped BAM to FASTQ for ${SAMPLE_ID}" \
    samtools fastq \
        -@ "$THREADS" \
        -1 "$UNMAPPED_R1" \
        -2 "$UNMAPPED_R2" \
        -0 /dev/null \
        -s "$UNMAPPED_SINGLE" \
        -n \
        "$UNMAPPED_BAM"

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Host filtering completed for ${SAMPLE_ID}"
echo "  Sorted BAM        : ${SORTED_BAM}"
echo "  Unmapped BAM      : ${UNMAPPED_BAM}"
echo "  Unmapped R1 FASTQ : ${UNMAPPED_R1}"
echo "  Unmapped R2 FASTQ : ${UNMAPPED_R2}"
echo "  Unmapped singletons: ${UNMAPPED_SINGLE}"
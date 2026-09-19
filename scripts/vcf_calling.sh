#!/usr/bin/env bash
# Variant calling on Avian Orthoreovirus (ARV) mapped reads using bcftools.
#
# Workflow:
#   1. bcftools mpileup  — compute per-base pileup from sorted BAM
#   2. bcftools call     — call SNPs and indels
#   3. bcftools filter   — filter low-quality variants
#   4. bgzip + tabix     — compress and index the final VCF
#   5. bcftools stats    — print variant summary
#
# Usage:
#   ./run_variant_calling.sh <SAMPLE_ID> [REFERENCE] [BAM_DIR] [OUTPUT_DIR] [MIN_DEPTH] [MIN_QUAL]
#
# Arguments (defaults shown):
#   SAMPLE_ID   - SRR/sample ID, e.g. SRR12620879                   (required)
#   REFERENCE   - Path to ARV reference FASTA                        (default: avian_reovirus.fa)
#   BAM_DIR     - Directory containing the sorted BAM file           (default: arv_mapping_results)
#   OUTPUT_DIR  - Directory for VCF output files                     (default: variant_results)
#   MIN_DEPTH   - Minimum read depth to call a variant               (default: 10)
#   MIN_QUAL    - Minimum variant quality score (PHRED) to keep      (default: 20)
#
# Example:
#   ./run_variant_calling.sh SRR12620879 avian_reovirus.fa arv_mapping_results variant_results 10 20

set -euo pipefail

# ── arguments / defaults ──────────────────────────────────────────────────────
SAMPLE_ID="${1:?Error: SAMPLE_ID is required. Usage: $0 <SAMPLE_ID> [REFERENCE] [BAM_DIR] [OUTPUT_DIR] [MIN_DEPTH] [MIN_QUAL]}"
REFERENCE="${2:-avian_reovirus.fa}"
BAM_DIR="${3:-arv_mapping_results}"
OUTPUT_DIR="${4:-variant_results}"
MIN_DEPTH="${5:-10}"
MIN_QUAL="${6:-20}"

# ── dependency check ──────────────────────────────────────────────────────────
for cmd in bcftools bgzip tabix samtools; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' not found. Please install it." >&2
        exit 1
    fi
done

# ── validate inputs ───────────────────────────────────────────────────────────
SORTED_BAM="${BAM_DIR}/${SAMPLE_ID}.sorted.bam"
BAM_INDEX="${SORTED_BAM}.bai"

[[ -f "$REFERENCE" ]]  || { echo "Error: Reference not found: ${REFERENCE}" >&2; exit 1; }
[[ -f "$SORTED_BAM" ]] || { echo "Error: Sorted BAM not found: ${SORTED_BAM}" >&2; exit 1; }
[[ -f "$BAM_INDEX" ]]  || { echo "Error: BAM index not found: ${BAM_INDEX} — run samtools index first." >&2; exit 1; }

# ── check reference .fai index ────────────────────────────────────────────────
if [[ ! -f "${REFERENCE}.fai" ]]; then
    echo "Creating FASTA index for reference ..."
    samtools faidx "$REFERENCE"
fi

# ── create output directory ───────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── output file paths ─────────────────────────────────────────────────────────
RAW_VCF="${OUTPUT_DIR}/${SAMPLE_ID}.raw.vcf"
FILTERED_VCF="${OUTPUT_DIR}/${SAMPLE_ID}.filtered.vcf"
FINAL_VCF_GZ="${OUTPUT_DIR}/${SAMPLE_ID}.variants.vcf.gz"

echo "============================================================"
echo " Variant Calling Pipeline"
echo " Sample     : ${SAMPLE_ID}"
echo " Reference  : ${REFERENCE}"
echo " BAM        : ${SORTED_BAM}"
echo " Output     : ${OUTPUT_DIR}/"
echo " Min depth  : ${MIN_DEPTH}x"
echo " Min qual   : ${MIN_QUAL}"
echo "============================================================"

# ── step 1: mpileup + call (piped together) ───────────────────────────────────
echo ""
echo "[Step 1] Running bcftools mpileup + call ..."
echo "  Piling up reads against reference and calling variants ..."

bcftools mpileup \
    --fasta-ref "$REFERENCE" \
    --min-BQ 20 \
    --annotate FORMAT/AD,FORMAT/DP \
    --output-type u \
    "$SORTED_BAM" \
| bcftools call \
    --multiallelic-caller \
    --variants-only \
    --output-type v \
    --output "$RAW_VCF"

echo "  Raw variants saved: ${RAW_VCF}"

# count raw variants
RAW_COUNT=$(grep -vc "^#" "$RAW_VCF" || true)
echo "  Raw variant count: ${RAW_COUNT}"

# ── step 2: filter variants ───────────────────────────────────────────────────
echo ""
echo "[Step 2] Filtering variants ..."
echo "  Keeping variants with: depth >= ${MIN_DEPTH}x  AND  quality >= ${MIN_QUAL}"

bcftools filter \
    --include "INFO/DP >= ${MIN_DEPTH} && QUAL >= ${MIN_QUAL}" \
    --output-type v \
    --output "$FILTERED_VCF" \
    "$RAW_VCF"

FILTERED_COUNT=$(grep -vc "^#" "$FILTERED_VCF" || true)
echo "  Variants after filtering: ${FILTERED_COUNT}"

# ── step 3: bgzip + tabix index ──────────────────────────────────────────────
echo ""
echo "[Step 3] Compressing and indexing final VCF ..."
bgzip -c "$FILTERED_VCF" > "$FINAL_VCF_GZ"
tabix -p vcf "$FINAL_VCF_GZ"
echo "  Final VCF: ${FINAL_VCF_GZ}"
echo "  Index    : ${FINAL_VCF_GZ}.tbi"

# ── step 4: variant summary ───────────────────────────────────────────────────
echo ""
echo "[Step 4] Variant summary:"
echo "------------------------------------------------------------"
bcftools stats "$FINAL_VCF_GZ" | grep "^SN"
echo "------------------------------------------------------------"

echo ""
echo "Variant types breakdown:"
bcftools stats "$FINAL_VCF_GZ" | grep -A5 "Ts/Tv"

# ── step 5: list all variants ─────────────────────────────────────────────────
echo ""
echo "[Step 5] All passing variants:"
echo "------------------------------------------------------------"
echo "CHROM  POS  REF  ALT  QUAL  DEPTH"
bcftools query \
    --format '%CHROM\t%POS\t%REF\t%ALT\t%QUAL\t%INFO/DP\n' \
    "$FINAL_VCF_GZ"
echo "------------------------------------------------------------"

# ── final summary ─────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Variant calling complete for: ${SAMPLE_ID}"
echo "  Raw VCF      : ${RAW_VCF}       (${RAW_COUNT} variants)"
echo "  Filtered VCF : ${FILTERED_VCF}  (${FILTERED_COUNT} variants)"
echo "  Final VCF.gz : ${FINAL_VCF_GZ}"
echo "  VCF index    : ${FINAL_VCF_GZ}.tbi"
echo "============================================================"
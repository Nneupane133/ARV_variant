#!/bin/bash
# =============================================================================
# ARV Mapping Result Visualization Script
# Usage: bash arv_mapping_visualization.sh <SAMPLE_ID> [BAM_DIR] [REFERENCE] [OUTPUT_DIR]
# Example: bash arv_mapping_visualization.sh SRR12620879
#          bash arv_mapping_visualization.sh SRR12620879 arv_mapping_results avian_reovirus.fa arv_viz_results
# =============================================================================

set -euo pipefail

# ── Arguments & Defaults ─────────────────────────────────────────────────────
SAMPLE_ID="${1:?ERROR: SAMPLE_ID is required. Usage: bash $0 <SAMPLE_ID> [BAM_DIR] [REFERENCE] [OUTPUT_DIR]}"
BAM_DIR="${2:-arv_mapping_results}"
REFERENCE="${3:-avian_reovirus.fa}"
OUTPUT_DIR="${4:-arv_viz_results}"

# ── File Paths ────────────────────────────────────────────────────────────────
BAM="${BAM_DIR}/${SAMPLE_ID}.bam"
SORTED_BAM="${BAM_DIR}/${SAMPLE_ID}.sorted.bam"
TXT_DIR="${OUTPUT_DIR}/txt"
HTML_DIR="${OUTPUT_DIR}/html"

# ── Colors for terminal output ────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}   ARV Mapping Visualization — Sample: ${SAMPLE_ID}${NC}"
echo -e "${CYAN}============================================================${NC}"

# ── Preflight Checks ──────────────────────────────────────────────────────────
echo -e "\n${YELLOW}[CHECK] Verifying required files...${NC}"

command -v samtools &>/dev/null || { echo -e "${RED}ERROR: samtools not found. Please install samtools.${NC}"; exit 1; }

[[ -f "$SORTED_BAM" ]] || { echo -e "${RED}ERROR: Sorted BAM not found: $SORTED_BAM${NC}"; exit 1; }
[[ -f "$REFERENCE"  ]] || { echo -e "${RED}ERROR: Reference FASTA not found: $REFERENCE${NC}"; exit 1; }

# Check index exists for sorted BAM, create if missing
if [[ ! -f "${SORTED_BAM}.bai" ]]; then
    echo -e "${YELLOW}[INDEX] BAM index not found — creating index...${NC}"
    samtools index "$SORTED_BAM"
fi

echo -e "${GREEN}[OK] All required files present.${NC}"

# ── Create Output Directories ─────────────────────────────────────────────────
mkdir -p "$TXT_DIR" "$HTML_DIR"
echo -e "${GREEN}[OK] Output dirs: ${TXT_DIR}/ and ${HTML_DIR}/${NC}\n"

# =============================================================================
# 1. FLAG STATISTICS  (both BAM and sorted BAM)
# =============================================================================
echo -e "${YELLOW}[1/8] Generating flag statistics (flagstat)...${NC}"

if [[ -f "$BAM" ]]; then
    samtools flagstat "$BAM" \
        > "${TXT_DIR}/${SAMPLE_ID}.raw_flagstat.txt"
    echo -e "${GREEN}      Raw BAM flagstat → ${TXT_DIR}/${SAMPLE_ID}.raw_flagstat.txt${NC}"
fi

samtools flagstat "$SORTED_BAM" \
    > "${TXT_DIR}/${SAMPLE_ID}.sorted_flagstat.txt"
echo -e "${GREEN}      Sorted BAM flagstat → ${TXT_DIR}/${SAMPLE_ID}.sorted_flagstat.txt${NC}"

# =============================================================================
# 2. FULL STATISTICS  (samtools stats)
# =============================================================================
echo -e "\n${YELLOW}[2/8] Generating full alignment statistics (stats)...${NC}"

samtools stats -r "$REFERENCE" "$SORTED_BAM" \
    > "${TXT_DIR}/${SAMPLE_ID}.stats.txt"
echo -e "${GREEN}      Full stats → ${TXT_DIR}/${SAMPLE_ID}.stats.txt${NC}"

# =============================================================================
# 3. COVERAGE SUMMARY  (per ARV segment)
# =============================================================================
echo -e "\n${YELLOW}[3/8] Generating per-segment coverage summary...${NC}"

samtools coverage "$SORTED_BAM" \
    > "${TXT_DIR}/${SAMPLE_ID}.coverage_summary.txt"
echo -e "${GREEN}      Coverage summary → ${TXT_DIR}/${SAMPLE_ID}.coverage_summary.txt${NC}"

# =============================================================================
# 4. PER-POSITION DEPTH
# =============================================================================
echo -e "\n${YELLOW}[4/8] Generating per-position depth...${NC}"

samtools depth -a "$SORTED_BAM" \
    > "${TXT_DIR}/${SAMPLE_ID}.depth.txt"
echo -e "${GREEN}      Depth → ${TXT_DIR}/${SAMPLE_ID}.depth.txt${NC}"

# =============================================================================
# 5. PILEUP (base-level counts)
# =============================================================================
echo -e "\n${YELLOW}[5/8] Generating mpileup (base-level read counts)...${NC}"

samtools mpileup -f "$REFERENCE" "$SORTED_BAM" \
    > "${TXT_DIR}/${SAMPLE_ID}.pileup.txt"
echo -e "${GREEN}      Pileup → ${TXT_DIR}/${SAMPLE_ID}.pileup.txt${NC}"

# =============================================================================
# 6. TVIEW — Text alignment view (TXT)
# =============================================================================
echo -e "\n${YELLOW}[6/8] Generating tview alignment (text)...${NC}"

# Get all sequence names from the reference to iterate per segment
SEGMENTS=$(samtools view -H "$SORTED_BAM" | grep "^@SQ" | awk '{print $2}' | sed 's/SN://')

while IFS= read -r SEG; do
    # Get segment length
    SEG_LEN=$(samtools view -H "$SORTED_BAM" | grep "^@SQ.*SN:${SEG}" | grep -o 'LN:[0-9]*' | cut -d: -f2)

    echo -e "      Segment: ${SEG} (length: ${SEG_LEN} bp)"

    samtools tview \
        -d T \
        -p "${SEG}:1" \
        "$SORTED_BAM" \
        "$REFERENCE" \
        > "${TXT_DIR}/${SAMPLE_ID}.${SEG}.tview.txt" 2>/dev/null || true

done <<< "$SEGMENTS"

echo -e "${GREEN}      Tview TXT files → ${TXT_DIR}/${SAMPLE_ID}.*.tview.txt${NC}"

# =============================================================================
# 7. TVIEW — HTML alignment view (HTML)
# =============================================================================
echo -e "\n${YELLOW}[7/8] Generating tview alignment (HTML)...${NC}"

while IFS= read -r SEG; do
    samtools tview \
        -d H \
        -p "${SEG}:1" \
        "$SORTED_BAM" \
        "$REFERENCE" \
        > "${HTML_DIR}/${SAMPLE_ID}.${SEG}.tview.html" 2>/dev/null || true
done <<< "$SEGMENTS"

echo -e "${GREEN}      Tview HTML files → ${HTML_DIR}/${SAMPLE_ID}.*.tview.html${NC}"

# =============================================================================
# 8. GENERATE SUMMARY HTML REPORT
# =============================================================================
echo -e "\n${YELLOW}[8/8] Building combined HTML summary report...${NC}"

REPORT="${HTML_DIR}/${SAMPLE_ID}_summary_report.html"
FLAGSTAT_CONTENT=$(cat "${TXT_DIR}/${SAMPLE_ID}.sorted_flagstat.txt" 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
COVERAGE_CONTENT=$(cat "${TXT_DIR}/${SAMPLE_ID}.coverage_summary.txt" 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
STATS_SUMMARY=$(grep "^SN" "${TXT_DIR}/${SAMPLE_ID}.stats.txt" 2>/dev/null | sed 's/SN\t//; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
TOTAL_READS=$(grep "raw total sequences" "${TXT_DIR}/${SAMPLE_ID}.stats.txt" 2>/dev/null | awk '{print $NF}')
MAPPED=$(grep "reads mapped:" "${TXT_DIR}/${SAMPLE_ID}.stats.txt" 2>/dev/null | head -1 | awk '{print $NF}')
AVG_LEN=$(grep "average length:" "${TXT_DIR}/${SAMPLE_ID}.stats.txt" 2>/dev/null | awk '{print $NF}')
AVG_QUAL=$(grep "average quality:" "${TXT_DIR}/${SAMPLE_ID}.stats.txt" 2>/dev/null | awk '{print $NF}')

cat > "$REPORT" << HTML_EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>ARV Mapping Report — ${SAMPLE_ID}</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Segoe UI', Arial, sans-serif; background: #0f1117; color: #e2e8f0; line-height: 1.6; }
  header { background: linear-gradient(135deg, #1a1f35 0%, #2d3561 100%);
           padding: 32px 40px; border-bottom: 2px solid #3b82f6; }
  header h1 { font-size: 1.8rem; color: #60a5fa; margin-bottom: 6px; }
  header p  { color: #94a3b8; font-size: 0.95rem; }
  .container { max-width: 1200px; margin: 0 auto; padding: 32px 24px; }
  .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 16px; margin-bottom: 36px; }
  .stat-card { background: #1e2535; border: 1px solid #334155;
               border-radius: 10px; padding: 20px; text-align: center; }
  .stat-card .value { font-size: 2rem; font-weight: 700; color: #60a5fa; }
  .stat-card .label { font-size: 0.8rem; color: #64748b; text-transform: uppercase;
                      letter-spacing: 0.05em; margin-top: 4px; }
  h2 { font-size: 1.2rem; color: #93c5fd; margin-bottom: 14px;
       padding-bottom: 8px; border-bottom: 1px solid #1e2535; }
  section { background: #1a2030; border: 1px solid #2d3748;
            border-radius: 10px; padding: 24px; margin-bottom: 28px; }
  pre { background: #0d1117; border: 1px solid #1e2535; border-radius: 6px;
        padding: 16px; font-size: 0.8rem; color: #a8b8d0; overflow-x: auto;
        white-space: pre; font-family: 'Courier New', monospace; max-height: 400px; overflow-y: auto; }
  table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
  th { background: #1e3a5f; color: #93c5fd; padding: 10px 14px;
       text-align: left; font-weight: 600; }
  td { padding: 9px 14px; border-bottom: 1px solid #1e2535; color: #cbd5e1; }
  tr:hover td { background: #1e2535; }
  .badge { display: inline-block; padding: 2px 8px; border-radius: 12px;
           font-size: 0.75rem; font-weight: 600; }
  .badge-green { background: #14532d; color: #4ade80; }
  .badge-blue  { background: #1e3a5f; color: #60a5fa; }
  .seg-links { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 10px; }
  .seg-links a { background: #1e3a5f; color: #93c5fd; padding: 6px 14px;
                 border-radius: 6px; text-decoration: none; font-size: 0.85rem;
                 border: 1px solid #2d5f8a; transition: background 0.2s; }
  .seg-links a:hover { background: #2d4f7c; }
  footer { text-align: center; color: #475569; font-size: 0.8rem; padding: 28px;
           border-top: 1px solid #1e2535; margin-top: 24px; }
</style>
</head>
<body>

<header>
  <h1>🧬 ARV Mapping Summary Report</h1>
  <p>Sample: <strong style="color:#e2e8f0">${SAMPLE_ID}</strong> &nbsp;|&nbsp;
     Reference: <strong style="color:#e2e8f0">${REFERENCE}</strong> &nbsp;|&nbsp;
     Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>
</header>

<div class="container">

  <!-- KEY STATS CARDS -->
  <div class="stats-grid">
    <div class="stat-card">
      <div class="value">${TOTAL_READS:-—}</div>
      <div class="label">Total Reads</div>
    </div>
    <div class="stat-card">
      <div class="value">${MAPPED:-—}</div>
      <div class="label">Reads Mapped</div>
    </div>
    <div class="stat-card">
      <div class="value">${AVG_LEN:-—}</div>
      <div class="label">Avg Read Length (bp)</div>
    </div>
    <div class="stat-card">
      <div class="value">${AVG_QUAL:-—}</div>
      <div class="label">Avg Base Quality</div>
    </div>
  </div>

  <!-- FLAG STATISTICS -->
  <section>
    <h2>📊 Flag Statistics (sorted BAM)</h2>
    <pre>${FLAGSTAT_CONTENT}</pre>
  </section>

  <!-- COVERAGE PER SEGMENT -->
  <section>
    <h2>🗺️ Per-Segment Coverage Summary</h2>
    <p style="color:#64748b;font-size:0.82rem;margin-bottom:12px">
      meandepth = average read depth; covbases = bases with ≥1× coverage; coverage = % of segment covered
    </p>
    <pre>${COVERAGE_CONTENT}</pre>
  </section>

  <!-- SAMTOOLS STATS SUMMARY -->
  <section>
    <h2>📋 Alignment Statistics (samtools stats)</h2>
    <pre>${STATS_SUMMARY}</pre>
  </section>

  <!-- TVIEW HTML LINKS -->
  <section>
    <h2>🔬 Per-Segment Alignment Views (tview)</h2>
    <p style="color:#64748b;font-size:0.82rem;margin-bottom:14px">
      Each link opens the base-level read alignment for that ARV segment.
      Open individual <code>.tview.html</code> files from the <code>html/</code> folder:
    </p>
    <div class="seg-links">
HTML_EOF

# Add a link per segment
while IFS= read -r SEG; do
    echo "      <a href=\"${SAMPLE_ID}.${SEG}.tview.html\">🔗 ${SEG}</a>" >> "$REPORT"
done <<< "$SEGMENTS"

cat >> "$REPORT" << HTML_EOF
    </div>
  </section>

  <!-- FILE INDEX -->
  <section>
    <h2>📁 Generated Output Files</h2>
    <table>
      <thead><tr><th>File</th><th>Type</th><th>Description</th></tr></thead>
      <tbody>
        <tr><td>${SAMPLE_ID}.sorted_flagstat.txt</td><td><span class="badge badge-green">TXT</span></td><td>Mapping flag statistics (sorted BAM)</td></tr>
        <tr><td>${SAMPLE_ID}.raw_flagstat.txt</td><td><span class="badge badge-green">TXT</span></td><td>Mapping flag statistics (raw BAM)</td></tr>
        <tr><td>${SAMPLE_ID}.stats.txt</td><td><span class="badge badge-green">TXT</span></td><td>Full alignment statistics</td></tr>
        <tr><td>${SAMPLE_ID}.coverage_summary.txt</td><td><span class="badge badge-green">TXT</span></td><td>Per-segment coverage (mean depth, % covered)</td></tr>
        <tr><td>${SAMPLE_ID}.depth.txt</td><td><span class="badge badge-green">TXT</span></td><td>Per-position read depth (all positions)</td></tr>
        <tr><td>${SAMPLE_ID}.pileup.txt</td><td><span class="badge badge-green">TXT</span></td><td>Base-level mpileup output</td></tr>
        <tr><td>${SAMPLE_ID}.&lt;SEGMENT&gt;.tview.txt</td><td><span class="badge badge-green">TXT</span></td><td>Text alignment view per ARV segment</td></tr>
        <tr><td>${SAMPLE_ID}.&lt;SEGMENT&gt;.tview.html</td><td><span class="badge badge-blue">HTML</span></td><td>HTML alignment view per ARV segment</td></tr>
        <tr><td>${SAMPLE_ID}_summary_report.html</td><td><span class="badge badge-blue">HTML</span></td><td>This combined summary report</td></tr>
      </tbody>
    </table>
  </section>

</div>
<footer>ARV Mapping Visualization &nbsp;|&nbsp; Poultry Pathology — Auburn University &nbsp;|&nbsp; $(date '+%Y')</footer>
</body>
</html>
HTML_EOF

echo -e "${GREEN}      HTML report → ${REPORT}${NC}"

# =============================================================================
# DONE — Print Summary
# =============================================================================
echo -e "\n${CYAN}============================================================${NC}"
echo -e "${GREEN}✅  Visualization complete for sample: ${SAMPLE_ID}${NC}"
echo -e "${CYAN}============================================================${NC}"
echo -e ""
echo -e "  📂 TXT files  →  ${TXT_DIR}/"
echo -e "  🌐 HTML files →  ${HTML_DIR}/"
echo -e ""
echo -e "  Key files:"
echo -e "    ${TXT_DIR}/${SAMPLE_ID}.sorted_flagstat.txt"
echo -e "    ${TXT_DIR}/${SAMPLE_ID}.coverage_summary.txt"
echo -e "    ${TXT_DIR}/${SAMPLE_ID}.depth.txt"
echo -e "    ${TXT_DIR}/${SAMPLE_ID}.stats.txt"
echo -e "    ${TXT_DIR}/${SAMPLE_ID}.pileup.txt"
echo -e "    ${HTML_DIR}/${SAMPLE_ID}_summary_report.html  ← Open this in browser"
echo -e ""
echo -e "  💡 Tip: Open the HTML report in a browser for a visual summary."
echo -e "${CYAN}============================================================${NC}"

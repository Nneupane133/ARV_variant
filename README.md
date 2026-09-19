# 🦠 Avian Orthoreovirus (ARV) Genome Analysis Pipeline

<div align="center">

![Pipeline](https://img.shields.io/badge/Pipeline-ARV%20Genomics-blueviolet?style=for-the-badge&logo=dna)
![Platform](https://img.shields.io/badge/Platform-Alabama%20Supercomputer-orange?style=for-the-badge&logo=server)
![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![License](https://img.shields.io/badge/License-Research%20Use-blue?style=for-the-badge)

**A complete end-to-end bioinformatics pipeline for ARV variant discovery**  
*From raw sequencing reads → host filtering → viral mapping → SNP calling*

*Auburn University · Poultry Pathology*

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Pipeline Flow](#-pipeline-flow)
- [Prerequisites](#-prerequisites)
- [Folder Structure](#-folder-structure)
- [Scripts Reference](#-scripts-reference)
- [Getting Started — Clone & Set Up](#-getting-started--clone--set-up)
- [Step-by-Step Usage](#-step-by-step-usage)
- [Output Files](#-output-files)
- [Viewing Results](#-viewing-results)
- [Alabama Supercomputer (ASC) Notes](#-alabama-supercomputer-asc-notes)

---

## 🔬 Overview

This pipeline processes Illumina paired-end reads from Avian Orthoreovirus (ARV)-infected poultry samples through a rigorous multi-step workflow:

1. **Quality Control** — raw read QC with FastQC
2. **Adapter Trimming** — remove adapters & low-quality bases with Cutadapt
3. **Host Filtering** — map reads to *Gallus gallus* genome; extract unmapped (viral) reads
4. **Viral Mapping** — align host-depleted reads to the 10-segment ARV reference
5. **Variant Calling** — call SNPs/indels with bcftools; filter by depth & quality

> **Reference genome:** ARV S1133 strain · 10 segments · `KU169288`–`KU169297` · ~23,492 bp total  
> **Host genome:** *Gallus gallus* `GCA_000002315.3` (Gallus_gallus-5.0)  
> **Test sample:** SRR12620879

---

## 🔄 Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      ARV GENOME ANALYSIS PIPELINE                           │
└─────────────────────────────────────────────────────────────────────────────┘

  📥 RAW DATA                    📁 data/
        │                        SRR12620879_1.fastq
        │                        SRR12620879_2.fastq
        ▼
  ┌─────────────┐
  │  fastqc.sh  │  ──────────────▶  📁 fastqc_results/
  └──────┬──────┘                    Raw read QC reports
         │
         ▼
  ┌──────────────┐
  │ cutadapt.sh  │  ──────────────▶  📁 trimmed_data/
  └──────┬───────┘                    *_1.trimmed.fastq
         │                            *_2.trimmed.fastq
         │
         ▼
  ┌──────────────────┐
  │ fastqc_trimm.sh  │  ───────────▶  📁 trimmed_fastqc_results/
  └──────┬───────────┘                 Post-trim QC reports
         │
         ▼
  ┌─────────────────────┐
  │ run_chicken_         │
  │ mapping.sh          │  ─────────▶  📁 host_filter_results/
  │ (BWA → GalGal5)     │              *_unmapped_1.fastq  ◀── VIRAL READS
  └──────┬──────────────┘              *_unmapped_2.fastq
         │
         ▼
  ┌─────────────────────┐
  │ run_arv_mapping.sh  │  ─────────▶  📁 arv_mapping_results/
  │ (BWA-MEM → ARV)     │              *.sorted.bam
  └──────┬──────────────┘              *.sorted.bam.bai
         │
         ▼
  ┌─────────────────────┐
  │  vcf_calling.sh     │  ─────────▶  📁 variant_results/
  │  (bcftools)         │              *.raw.vcf
  └──────┬──────────────┘              *.filtered.vcf
         │                             *.variants.vcf.gz + .tbi
         ▼
  ┌─────────────────────┐
  │   view_bam.sh       │  ─────────▶  🖥️  Terminal: samtools tview
  │   (tview / IGV)     │              Interactive SNP viewer
  └─────────────────────┘
```

---

## ⚙️ Prerequisites

### Conda Environment

```bash
conda env create -f environment.yml
conda activate arv_pipeline
```

**Key tools included:**

| Tool | Version | Purpose |
|------|---------|---------|
| `sra-tools` | ≥3.0 | Download SRA data |
| `fastqc` | ≥0.12 | Read quality control |
| `cutadapt` | ≥4.0 | Adapter trimming |
| `bwa` | ≥0.7.17 | Short-read alignment |
| `samtools` | ≥1.17 | BAM processing |
| `bcftools` | ≥1.17 | Variant calling |
| `htslib` | ≥1.17 | bgzip + tabix |

---

## 📁 Folder Structure

```
arv_pipeline/
│
├── environment.yml                    # Conda environment
│
├── ── REFERENCE DATA ────────────────────────────────────
├── avian_reovirus.fa                  # ← ARV 10-segment reference (combined)
├── avian_reovirus.fa.fai              # samtools index
├── avian_reovirus.fa.{amb,ann,bwt…}  # BWA index files
│
├── chicken_genome/
│   └── GCA_000002315.3_genomic.fna   # Gallus gallus reference genome
│
├── scripts/                           # ← ALL pipeline scripts live here
│   ├── download_ref_arv.sh            #   Download 10 ARV segments → combined FASTA
│   ├── download_sequence.sh           #   Download paired-end FASTQ from SRA
│   ├── download_ref_chicken.sh        #   Download Gallus gallus genome
│   ├── fastqc.sh                      #   QC on raw reads
│   ├── cutadapt.sh                    #   Trim adapters & low-quality bases
│   ├── fastqc_trimm.sh                #   QC on trimmed reads
│   ├── run_chicken_mapping.sh         #   Host filtering (BWA → chicken)
│   ├── run_arv_mapping.sh             #   Viral mapping (BWA → ARV)
│   ├── vcf_calling.sh                 #   Variant calling (bcftools)
│   └── view_bam.sh                    #   Interactive BAM viewer (tview)
│
├── ── DATA DIRECTORIES ──────────────────────────────────
├── data/                              # Raw FASTQ input
├── fastqc_results/                    # Raw read QC output
├── trimmed_data/                      # Trimmed FASTQ
├── trimmed_fastqc_results/            # Trimmed read QC output
├── host_filter_results/               # Unmapped (viral) reads
├── arv_mapping_results/               # BAM files aligned to ARV
└── variant_results/                   # VCF files with variants
```

---

## 📜 Scripts Reference

### 1 · `download_ref_arv.sh` — Download ARV Reference

Downloads all 10 ARV segments from NCBI and combines them into a single multi-FASTA.

```bash
bash scripts/download_ref_arv.sh
```

| Parameter | Value |
|-----------|-------|
| Accessions | `KU169288` – `KU169297` (10 segments) |
| Output | `avian_reovirus.fa` |
| Method | NCBI `efetch` (E-utilities) |

---

### 2 · `download_sequence.sh` — Download Test Sample

Downloads paired-end FASTQ from the SRA.

```bash
bash scripts/download_sequence.sh            # downloads SRR12620879 by default
bash scripts/download_sequence.sh SRR99999   # custom accession
```

| Parameter | Value |
|-----------|-------|
| Default sample | `SRR12620879` |
| Output dir | `data/` |
| Output files | `SRR12620879_1.fastq`, `SRR12620879_2.fastq` |

---

### 3 · `download_ref_chicken.sh` — Download Host Genome

Downloads the *Gallus gallus* reference genome via NCBI Datasets API.

```bash
bash scripts/download_ref_chicken.sh
```

| Parameter | Value |
|-----------|-------|
| Assembly | `GCA_000002315.3` (Gallus_gallus-5.0) |
| Output | `chicken_genome/GCA_000002315.3_genomic.fna` |

> **ASC note:** Only needs to be run once. Skip if `chicken_genome/` already exists.

---

### 4 · `fastqc.sh` — Raw Read Quality Control

Runs FastQC on raw paired-end reads.

```bash
bash scripts/fastqc.sh                        # uses defaults
bash scripts/fastqc.sh SRR12620879 data/ fastqc_results/ 4
```

| Argument | Default | Description |
|----------|---------|-------------|
| `SAMPLE_ID` | `SRR12620879` | SRA accession |
| `INPUT_DIR` | `data/` | Directory with raw FASTQ |
| `OUTPUT_DIR` | `fastqc_results/` | FastQC HTML/ZIP output |
| `THREADS` | `4` | CPU threads |

---

### 5 · `cutadapt.sh` — Adapter Trimming

Trims Illumina adapters and low-quality bases with Cutadapt.

```bash
bash scripts/cutadapt.sh                      # uses defaults
bash scripts/cutadapt.sh SRR12620879 data/ trimmed_data/ 4
```

| Argument | Default | Description |
|----------|---------|-------------|
| `SAMPLE_ID` | `SRR12620879` | SRA accession |
| `INPUT_DIR` | `data/` | Raw FASTQ directory |
| `OUTPUT_DIR` | `trimmed_data/` | Trimmed FASTQ output |
| `THREADS` | `4` | CPU threads |

**Output:**

| File | Description |
|------|-------------|
| `trimmed_data/SRR12620879_1.trimmed.fastq` | Trimmed R1 |
| `trimmed_data/SRR12620879_2.trimmed.fastq` | Trimmed R2 |
| `trimmed_fastqc_results/` | HTML QC reports |

---

### 6 · `fastqc_trimm.sh` — Post-Trim QC

FastQC on trimmed reads to confirm adapter removal.

```bash
bash scripts/fastqc_trimm.sh                  # uses defaults
bash scripts/fastqc_trimm.sh SRR12620879 trimmed_data/ trimmed_fastqc_results/
```

---

### 7 · `run_chicken_mapping.sh` — Host Filtering ⭐

**The critical decontamination step.** Maps trimmed reads to the chicken genome; extracts the pairs where **both reads are unmapped** (your viral reads).

```bash
bash scripts/run_chicken_mapping.sh SRR12620879
bash scripts/run_chicken_mapping.sh SRR12620879 chicken_genome/GCA_000002315.3_genomic.fna trimmed_data/ host_filter_results/ 8
```

| Argument | Default | Description |
|----------|---------|-------------|
| `SAMPLE_ID` | *(required)* | SRA accession |
| `REFERENCE` | `chicken_genome/GCA_000002315.3_genomic.fna` | Host genome |
| `INPUT_DIR` | `trimmed_data/` | Trimmed FASTQ |
| `OUTPUT_DIR` | `host_filter_results/` | Unmapped reads output |
| `THREADS` | `4` | CPU threads |

**Unmapped read extraction flags:**

```
-f 12   →  both reads unmapped (flag 4 + flag 8)
-F 256  →  exclude secondary alignments
```

**Output:**

| File | Description |
|------|-------------|
| `host_filter_results/SRR12620879.sorted.bam` | Sorted alignment to chicken |
| `host_filter_results/SRR12620879_unmapped_1.fastq` | **Viral R1 reads** |
| `host_filter_results/SRR12620879_unmapped_2.fastq` | **Viral R2 reads** |

> **🖥️ ASC submission** (chicken genome BWA index requires ~16 GB RAM):
> ```bash
> qsub -q medium -l select=1:ncpus=8:mem=16gb -l walltime=6:00:00 scripts/run_chicken_mapping.sh
> ```

---

### 8 · `run_arv_mapping.sh` — ARV Alignment

Aligns host-filtered viral reads to the 10-segment ARV reference.

```bash
bash scripts/run_arv_mapping.sh SRR12620879
bash scripts/run_arv_mapping.sh SRR12620879 avian_reovirus.fa host_filter_results/ arv_mapping_results/ 4
```

| Argument | Default | Description |
|----------|---------|-------------|
| `SAMPLE_ID` | *(required)* | SRA accession |
| `REFERENCE` | `avian_reovirus.fa` | ARV multi-segment FASTA |
| `INPUT_DIR` | `host_filter_results/` | Unmapped reads from step 7 |
| `OUTPUT_DIR` | `arv_mapping_results/` | BAM output |
| `THREADS` | `4` | CPU threads |

**Pipeline steps:**
1. BWA index (skipped if exists)
2. samtools faidx (skipped if exists)
3. BWA-MEM alignment → SAM
4. SAM → BAM (SAM deleted)
5. Sort BAM (unsorted BAM deleted)
6. Index sorted BAM
7. Print flagstat summary

**Output:**

| File | Description |
|------|-------------|
| `arv_mapping_results/SRR12620879.sorted.bam` | Coordinate-sorted alignment |
| `arv_mapping_results/SRR12620879.sorted.bam.bai` | BAM index |

---

### 9 · `vcf_calling.sh` — Variant Calling

Calls SNPs and indels using bcftools mpileup → call → filter pipeline.

```bash
bash scripts/vcf_calling.sh SRR12620879
bash scripts/vcf_calling.sh SRR12620879 avian_reovirus.fa arv_mapping_results/ variant_results/ 4
```

| Argument | Default | Description |
|----------|---------|-------------|
| `SAMPLE_ID` | *(required)* | SRA accession |
| `REFERENCE` | `avian_reovirus.fa` | ARV reference |
| `INPUT_DIR` | `arv_mapping_results/` | BAM files |
| `OUTPUT_DIR` | `variant_results/` | VCF output |
| `THREADS` | `4` | CPU threads |

**Filtering thresholds:**

| Filter | Threshold | Meaning |
|--------|-----------|---------|
| Min depth | ≥ 10 reads | Only trust well-covered sites |
| Min QUAL | ≥ 20 | Phred-scaled quality score |

**Output:**

| File | Description |
|------|-------------|
| `variant_results/SRR12620879.raw.vcf` | All called variants (unfiltered) |
| `variant_results/SRR12620879.filtered.vcf` | High-confidence variants |
| `variant_results/SRR12620879.variants.vcf.gz` | bgzip-compressed VCF |
| `variant_results/SRR12620879.variants.vcf.gz.tbi` | tabix index |

---

### 10 · `view_bam.sh` — Interactive BAM Viewer

Opens an interactive terminal view of the alignment against the ARV reference.

```bash
bash scripts/view_bam.sh
bash scripts/view_bam.sh SRR12620879
bash scripts/view_bam.sh SRR12620879 arv_mapping_results/ avian_reovirus.fa KU169290:500
```

| Argument | Default | Description |
|----------|---------|-------------|
| `SAMPLE_ID` | `SRR12620879` | SRA accession |
| `BAM_DIR` | `arv_mapping_results/` | BAM directory |
| `REFERENCE` | `avian_reovirus.fa` | ARV reference |
| `POSITION` | `KU169288:1` | Starting position |

**Keyboard shortcuts in tview:**

| Key | Action |
|-----|--------|
| `Arrow keys` / `h j k l` | Scroll left / right / up / down |
| `g` | Go to position (e.g., `KU169290:500`) |
| `n` | Jump to next variant |
| `b` | Toggle base quality display |
| `c` | Toggle color mode |
| `.` | Toggle dot/base display |
| `q` / `Ctrl+C` | Quit |

**ARV Segment accessions for navigation:**

| Segment | Accession | Gene |
|---------|-----------|------|
| L1 | KU169288 | RNA-dependent RNA polymerase |
| L2 | KU169289 | λ-class capsid |
| L3 | KU169290 | λ-class capsid |
| M1 | KU169291 | μ-class capsid |
| M2 | KU169292 | μ-class capsid |
| M3 | KU169293 | μ-class capsid (NS) |
| S1 | KU169294 | σ-class (p10/p17/σC) |
| S2 | KU169295 | σ-class capsid |
| S3 | KU169296 | σ-class (σNS) |
| S4 | KU169297 | σ-class (σs) |

---

## 🚀 Step-by-Step Usage

### Complete Pipeline Run

```bash
# ── 1. Set up environment ─────────────────────────────────────────────────────
conda env create -f environment.yml
conda activate ARV

# ── 2. Download references (once only) ───────────────────────────────────────
bash scripts/download_ref_arv.sh             # → avian_reovirus.fa
bash scripts/download_ref_chicken.sh         # → chicken_genome/GCA_000002315.3_genomic.fna

# ── 3. Download test sample ───────────────────────────────────────────────────
bash scripts/download_sequence.sh SRR12620879   # → data/SRR12620879_1.fastq + _2.fastq

# ── 4. Quality control (raw reads) ───────────────────────────────────────────
bash scripts/fastqc.sh SRR12620879

# ── 5. Trim adapters ─────────────────────────────────────────────────────────
bash scripts/cutadapt.sh SRR12620879

# ── 6. Quality control (trimmed reads) ───────────────────────────────────────
bash scripts/fastqc_trimm.sh

# ── 7. Host filtering [submit to HPC] ────────────────────────────────────────
qsub -q medium -l select=1:ncpus=8:mem=16gb -l walltime=6:00:00 scripts/run_chicken_mapping.sh
#  → monitor: qstat -u $USER
#  → logs:    tail -f host_filter_results/bwa_host_filter.log

# ── 8. ARV mapping ────────────────────────────────────────────────────────────
bash scripts/run_arv_mapping.sh SRR12620879

# ── 9. Variant calling ────────────────────────────────────────────────────────
bash scripts/vcf_calling.sh SRR12620879

# ── 10. View alignment ───────────────────────────────────────────────────────
bash scripts/view_bam.sh SRR12620879
```

---

## 📊 Output Files

After a complete pipeline run, you will have:

```
variant_results/
├── SRR12620879.raw.vcf           ← all raw variants
├── SRR12620879.filtered.vcf      ← high-confidence SNPs (depth≥10, QUAL≥20)
├── SRR12620879.variants.vcf.gz   ← compressed, ready for downstream analysis
└── SRR12620879.variants.vcf.gz.tbi  ← tabix index for random access

arv_mapping_results/
├── SRR12620879.sorted.bam        ← coordinate-sorted alignment to ARV
└── SRR12620879.sorted.bam.bai   ← BAM index

host_filter_results/
├── SRR12620879_unmapped_1.fastq  ← viral R1 reads (chicken-depleted)
└── SRR12620879_unmapped_2.fastq  ← viral R2 reads (chicken-depleted)
```

### Interpreting VCF Output

```
# Quick summary of variants per ARV segment
grep -v "^#" variant_results/SRR12620879.filtered.vcf | cut -f1 | sort | uniq -c | sort -rn

# Count total filtered variants
grep -vc "^#" variant_results/SRR12620879.filtered.vcf

# View variants in a specific segment (e.g., S1 = KU169294)
grep "KU169294" variant_results/SRR12620879.filtered.vcf

# Check coverage depth at variant sites
bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\t[%DP]\n' \
    variant_results/SRR12620879.filtered.vcf
```

---

## 🖥️ Viewing Results

### Terminal — samtools tview

```bash
# View from the start of segment L1
bash scripts/view_bam.sh SRR12620879 arv_mapping_results/ avian_reovirus.fa KU169288:1

# Jump directly to a specific position
bash scripts/view_bam.sh SRR12620879 arv_mapping_results/ avian_reovirus.fa KU169294:350
```

### Direct samtools tview command

```bash
samtools tview arv_mapping_results/SRR12620879.sorted.bam avian_reovirus.fa
```

### IGV (Integrative Genomics Viewer)

For a graphical view, load into IGV:

```
1. Genome → Load from File → avian_reovirus.fa
2. File → Load from File  → arv_mapping_results/SRR12620879.sorted.bam
3. File → Load from File  → variant_results/SRR12620879.variants.vcf.gz
```

---

## 🖥️ Alabama Supercomputer (ASC) Notes

### Resource Requirements

| Step | RAM Needed | Queue |
|------|-----------|-------|
| BWA index (chicken genome) | ~16 GB | `medium` |
| BWA-MEM alignment (chicken) | ~16 GB | `medium` |
| BWA-MEM alignment (ARV) | ~2 GB | `small` |
| Variant calling | ~2 GB | `small` |

### Submission Commands

```bash
# Host filtering (requires medium queue)
qsub -q medium -l select=1:ncpus=8:mem=16gb -l walltime=6:00:00 scripts/run_chicken_mapping.sh

# Monitor jobs
qstat -u $USER
qstat -f <JOBID> | grep -E "job_state|resources_used|Resource_List"

# View live log
tail -f host_filter_results/bwa_host_filter.log
```

### ⚠️ Important Notes

- **Never run BWA index on the login node** — the chicken genome requires ~16 GB RAM which exceeds login node limits (~2–4 GB) and the job will be killed.
- ASC uses **PBS Pro** with `run_script` wrapper. Use direct `qsub` with `-q medium` flags for reliable resource allocation.
- The `small` queue is limited to **4 GB max** — insufficient for chicken genome BWA indexing.
- Load required modules before running: `module load bwa samtools bcftools`

---

## 📥 Getting Started — Clone & Set Up

### Clone the Repository

```bash
git clone https://github.com/nneupane133/ARV_variant.git
cd ARV_variant
```

> Replace `YOUR_USERNAME/arv-pipeline` with your actual GitHub repository path.

### Set Up on the Alabama Supercomputer (ASC)

```bash
# 1. SSH into ASC
ssh USERNAME@asaxlogin2.asc.edu

# 2. Navigate to your scratch/project directory
cd /scratch/YOUR_USERNAME/
# or
cd /home/YOUR_USERNAME/

# 3. Clone the pipeline
git clone https://github.com/YOUR_USERNAME/arv-pipeline.git
cd arv-pipeline

# 4. Make all scripts executable
chmod +x *.sh

# 5. Load required modules (ASC)
module load anaconda3
module load bwa
module load samtools
module load bcftools

# 6. Create and activate the conda environment
conda env create -f environment.yml
conda activate arv_pipeline
```

### Push Your Own Changes Back

```bash
# After editing scripts or adding results
git add .
git commit -m "Add ARV pipeline scripts and results"
git push origin main
```

### Keep Your Local Copy Up to Date

```bash
git pull origin main
```

---

## 📚 References

- **ARV Reference:** S1133 strain · GenBank `KU169288`–`KU169297`
- **Host Reference:** *Gallus gallus* · INSDC `GCA_000002315.3`
- **BWA-MEM:** Li H. (2013) Aligning sequence reads, clone sequences and assembly contigs with BWA-MEM. *arXiv:1303.3997*
- **bcftools:** Danecek P. et al. (2021) Twelve years of SAMtools and BCFtools. *GigaScience*
- **Cutadapt:** Martin M. (2011) Cutadapt removes adapter sequences from high-throughput sequencing reads. *EMBnet.journal*

---

<div align="center">

**Auburn University · Poultry Pathology · ARV Genomics Pipeline**  
*Contact: nzn0046@auburn.edu*

</div>

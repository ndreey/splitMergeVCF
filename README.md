# VCF Wrangle Script

This bash script automates the process of splitting and merging VCF files to extract:
- All variant sites
- Biallelic SNPs
- Invariant sites  
It also merges selected outputs and summarizes key statistics for each resulting file.

## Requirements

Ensure the following tools are available in your environment:
- `bcftools`
- `tabix`
- `bash`

If using a module system (e.g., SLURM), uncomment and modify the appropriate `ml load` lines in the script.

## Usage

```bash
bash splitMergeVCF.sh --vcf FILE --outdir DIR --prefix NAME
```

**Arguments:**
- `--vcf FILE` – Path to input VCF file (must be compressed `.vcf.gz`)
- `--outdir DIR` – Output directory (will be created if it doesn't exist)
- `--prefix NAME` – Prefix for all output files

### Example
```bash
bash splitMergeVCF.sh --vcf PELLEsubset.vcf.gz --outdir test-dir --prefix test
```

## Output Structure
```
test-dir/
├── stats
│   └── merge-split.stats
└── vcf-final
    ├── test.biallelic.vcf.gz
    ├── test.biallelic.vcf.gz.tbi
    ├── test.biallelic.with-invariants.vcf.gz
    ├── test.biallelic.with-invariants.vcf.gz.tbi
    ├── test.invariants.vcf.gz
    ├── test.invariants.vcf.gz.tbi
    ├── test.variants.vcf.gz
    └── test.variants.vcf.gz.tbi
```

## Notes

- The script checks for and creates tabix indices if missing.
- If output files already exist, they will be skipped (not overwritten).
- A summary of each VCF file is printed and saved as `merge-split.stats`.

#!/bin/bash


# Start the process
echo "$(date) [INFO]        Starting script execution"

# Load slurm modules
#ml load bcftools/1.20


# Parse argument flags
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --vcf)          VCF_F="$2"; shift ;;
        --outdir)       OUTDIR="$2"; shift ;;
        --prefix)       PREFIX="$2"; shift ;;
        -h|--help)
            echo "Usage: $0 --vcf FILE --outdir DIR --prefix STRING"
            exit 0 ;;
        *) echo "[ERROR] Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done


# Validate required arguments
if [[ -z $VCF_F || -z $OUTDIR || -z $PREFIX ]]; then
    echo "[ERROR] Missing required arguments."
    echo "Usage: $0 --vcf FILE --outdir DIR --prefix STRING"
    exit 1
fi

# Check if required files actually exist
if [ ! -s "$VCF_F" ]; then echo "[ERROR] VCF list file not found or empty: $VCF_F"; exit 1; fi

# Remove trailing slash from --outdir, if present
OUTDIR="${OUTDIR%/}"

# Output directories
FINDIR="$OUTDIR/vcf-final"
STATSDIR="$OUTDIR/stats"

mkdir -p $FINDIR $STATSDIR


# Define outputs for final VCFs
RAW_VARIANTS=${FINDIR}/${PREFIX}.variants.vcf.gz
RAW_BIALLELIC=${FINDIR}/${PREFIX}.biallelic.vcf.gz
INVARIANTS=${FINDIR}/${PREFIX}.invariants.vcf.gz
ALL_SITES_BIALLELIC=${FINDIR}/${PREFIX}.biallelic.with-invariants.vcf.gz

# Define stats file
STATS_OUT=$STATSDIR/${PREFIX}-merge-split.stats

echo "$(date) [START]       Processing VCF-WRANGLE for: $(basename $VCF_F)"

# Check so index of original vcf exists
if [ ! -f "$VCF_F.tbi" ]; then
    echo "$(date) [INFO]        Create index for $(basename $VCF_F)"
    tabix $VCF_F
else
    echo "$(date) [SKIP]        Index file for $(basename $VCF_F) exists"
fi

# Generate VCF file for all variants (snps, indels)
if [ ! -f "$RAW_VARIANTS" ]; then
    echo "$(date) [INFO]        Splitting $(basename $VCF_F) into variants only: $RAW_VARIANTS"
    bcftools view -c 1 -O z -o "$RAW_VARIANTS" "$VCF_F"
    tabix "$RAW_VARIANTS"
else
    echo "$(date) [SKIP]        Raw variants already exist: $RAW_VARIANTS"
fi

# Generate VCF file with only biallelic SNPs
if [ ! -f "$RAW_BIALLELIC" ]; then
    echo "$(date) [INFO]        Splitting $(basename $VCF_F) into only biallelic SNPs: $RAW_BIALLELIC"
    bcftools view -m2 -M2 -v snps -O z -o "$RAW_BIALLELIC" "$RAW_VARIANTS"
    tabix "$RAW_BIALLELIC"
else
    echo "$(date) [SKIP]        Raw biallelic SNPs already exist: $RAW_BIALLELIC"
fi

# Generate VCF file with invariants only
if [ ! -f "$INVARIANTS" ]; then
    echo "$(date) [INFO]        Splitting $(basename $VCF_F) into invariants only: $INVARIANTS"
    bcftools view -C 0 -O z -o "$INVARIANTS" "$VCF_F"
    tabix "$INVARIANTS"
else
    echo "$(date) [SKIP]        Filtered invariants already exist: $INVARIANTS"
fi

# Merge invariants and biallelic SNPs vcf.
if [ ! -f "$ALL_SITES_BIALLELIC" ]; then
    echo "$(date) [INFO]        Merging $INVARIANTS + $RAW_BIALLELIC SNPs: $ALL_SITES_BIALLELIC"
    bcftools concat --allow-overlaps "$INVARIANTS" "$RAW_BIALLELIC" -O z -o "$ALL_SITES_BIALLELIC"
    tabix "$ALL_SITES_BIALLELIC"
else
    echo "$(date) [SKIP]        Filtered merged VCF already exists: $ALL_SITES_BIALLELIC"
fi

# Get quick stats for the files
echo "$(date) [INFO]        Summarising stats from each VCF file: $STATS_OUT"
echo -e "VCF\tsamples\trecords\tinvariants\tSNPs\tMNPs\tindels\tothers\tmulti-sites\tmulti-SNPs" > $STATS_OUT
for FILE in $VCF_F $RAW_VARIANTS $RAW_BIALLELIC $INVARIANTS $ALL_SITES_BIALLELIC; do

    echo -e "$(basename $FILE)\t$(bcftools stats $FILE | grep -v "# SN," | grep -A 9 "# SN" | grep -v "#" | cut -f 4 | paste -sd$'\t')" >> $STATS_OUT

done

# Preview the file
echo -e "$(date) [FINISH]       VCF-wrangle complete\n"
echo -e "\n >> BCFTOOLS STATS FROM EACH VCF FILE << \n"
echo "Summary numbers:"
echo "number of records   .. number of data rows in the VCF"
echo "number of no-ALTs   .. reference-only sites, ALT is either '.' or identical to REF"
echo "number of SNPs      .. number of rows with a SNP"
echo "number of MNPs      .. number of rows with a MNP, such as CC>TT"
echo "number of indels    .. number of rows with an indel"
echo "number of others    .. number of rows with other type, for example a symbolic allele or a complex substitution, such as ACT>TCGA"
echo "number of multiallelic sites     .. number of rows with multiple alternate alleles"
echo "number of multiallelic SNP sites .. number of rows with multiple alternate alleles, all SNPs"
echo "Note that rows containing multiple types will be counted multiple times, in each counter. For example, a row with a SNP and an indel increments both the SNP and the indel counter."
echo ""

# Print out the stats
cat $STATS_OUT

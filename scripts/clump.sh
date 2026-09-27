set -eu

# Column selectors per input layout. The legacy wrapper chose these in Rust
# (plink2_clump_field_args); the plugin carries the value through env and the
# script owns the mapping. Unknown values fail loudly instead of falling back.
case "$PLINK2_CLUMP_INPUT_FORMAT" in
  twosamplemr|plink_assoc)
    FIELD_ARGS="--clump-id-field SNP --clump-p-field P"
    ;;
  ieu_open_gwas)
    FIELD_ARGS="--clump-id-field variant --clump-p-field pval"
    ;;
  *)
    echo "unsupported input_format: $PLINK2_CLUMP_INPUT_FORMAT" >&2
    exit 1
    ;;
esac

# Optional single-chromosome run. Absence of PLINK2_CLUMP_CHR (the optional
# `chr` param renders as an empty env value) means autosomes 1..=22.
CHR_SEQ="1 22"
CHR_ARGS=""
LABEL="autosomes 1..=22"
if [ -n "$PLINK2_CLUMP_CHR" ]; then
  CHR_SEQ="$PLINK2_CLUMP_CHR $PLINK2_CLUMP_CHR"
  CHR_ARGS="--chr $PLINK2_CLUMP_CHR"
  LABEL="chromosome $PLINK2_CLUMP_CHR"
fi

mkdir -p /work/per_chr
: > "${AUTONOMICS_OUTPUT1}"
for chr in $(seq $CHR_SEQ); do
  out_prefix=/work/per_chr/clump.chr${chr}
  plink2 \
     --bfile /panels/plink_ref/1000G.EUR.QC.${chr} \
     --clump cols=+chrom,+pos "${AUTONOMICS_INPUT0}" \
     $FIELD_ARGS \
     $CHR_ARGS \
     --clump-p1 "${PLINK2_CLUMP_P1}" \
     --clump-p2 "${PLINK2_CLUMP_P2}" \
     --clump-r2 "${PLINK2_CLUMP_R2}" \
     --clump-kb "${PLINK2_CLUMP_KB}" \
     --out "${out_prefix}" \
  >> "${AUTONOMICS_OUTPUT0}" 2>&1 || {
      echo "plink2 clump failed on chromosome ${chr}" >&2
      exit 1
   }
  if [ -f "${out_prefix}.clumps" ]; then
     sed "s/^/${chr}\t/" "${out_prefix}.clumps" \
       >> "${AUTONOMICS_OUTPUT1}" || true
  fi
  printf 'chr\t%s\n' "${chr}" >> "${AUTONOMICS_OUTPUT2}"
done
echo "plink2 clump completed across ${LABEL}" \
  >> "${AUTONOMICS_OUTPUT0}"

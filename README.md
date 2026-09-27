# plink2 plugin

Migrated from the legacy `plink2_clump_container` wrapper in nodes-io.
One directory = one plugin family = one git-able unit.

## Layout

- `manifest.toml` — node kind `plink2_clump`: params, ports, the 1000G
  EUR PLINK binary panel binding, image provenance
- `scripts/clump.sh` — the execution script, referenced relatively and
  inlined by the loader at startup
- `Dockerfile` — image provenance: official PLINK2 v2.0.0-a.6.26
  (`plink2_linux_avx2.zip`, upstream SHA256 enforced at build time);
  build and push still go through GHCR
- `fixtures/chr22.sumstats.tsv` — smoke-test sumstats (SNP + P columns)
- `test_plink2_clump.sh` — image baseline: builds the image, publishes
  the `wjixiang/catalog-plink-ref-1000g-eur-binary` panel package, and
  smoke-tests the pinned binary version

## Install

```sh
export AUTONOMICS_PLUGIN_ROOT=/mnt/projects/node-plugins
cargo test -p container-plugin --test plink2_migration   # golden parity
```

Declare the family in `~/.autonomics/plugins.toml` (or the deployment
equivalent) once it is pushed to git:

```toml
[[plugin]]
name = "plink2"
git = "git@github.com:auto-nomics/plink2-plugin.git"
rev = "<pinned commit SHA>"
```

## Migration parity

The golden test (`container-plugin/tests/plink2_migration.rs`) compares
the compiled `ContainerCommandSpec` against the legacy Rust wrapper's
output: image, outputs, panel bundle, resources, timeout, and env
defaults are byte-exact. Deliberate deltas, recorded for honesty:

- The legacy artifact prefix `/artifacts/plink2_clump_container` drops
  the `_container` suffix together with the kind (the manifest-level
  `/artifacts/{kind}` convention used by the whole wave).
- The legacy command vector `["sh", "-c"]` becomes interpreter `sh`;
  the executor inserts the materialized script at index 1, and the
  trailing `-c` was a no-op positional under `sh <script>`.
- The `ClumpInputFormat` enum flattens to a `string` param; the script
  maps `twosamplemr`/`plink_assoc`/`ieu_open_gwas` to the official
  `--clump-id-field`/`--clump-p-field` selectors and rejects anything
  else, replacing the Rust type system with a `case` stanza.
- Numeric thresholds travel through env (`PLINK2_CLUMP_*`) instead of
  Rust string building; the rendered default spellings (`5e-8`,
  `1e-6`, `0.001`, `10000`) are identical to the legacy `format!`
  output.

The script preserves the legacy semantics exactly: per-chromosome
`--bfile /panels/plink_ref/1000G.EUR.QC.<chr>` loop over `seq 1 22`
(or the single `--chr <n>`), `--clump cols=+chrom,+pos` against the
input file, non-zero exit on any per-chromosome failure, chromosome-
prefixed concatenation of the official `.clumps` tables, the
per-chromosome marker rows in the chromosomes output, and the final
completion line in the log. There is no gzip stanza: the legacy wrapper
never decompressed inputs (PLINK2 reads gzip natively).

# syntax=docker/dockerfile:1
# ============================================================
# RNA-seq + ChIP/ATAC + Enrichment + Survival + Single-cell + TCGA
# Base: rocker/tidyverse 4.6.2 (Ubuntu 26.04, includes RStudio Server)
# ============================================================

FROM --platform=linux/amd64 rocker/tidyverse:4.6.2

ENV DEBIAN_FRONTEND=noninteractive

# ---- System deps ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libfreetype-dev \
    libpng-dev \
    libtiff-dev \
    libjpeg-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libcairo2-dev \
    libxt-dev \
    libgit2-dev \
    libglpk-dev \
    libgsl-dev \
    libudunits2-dev \
    libhdf5-dev \
    libgfortran5 \
    libblas-dev \
    liblapack-dev \
    libnlopt-dev \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    cmake \
    pandoc \
    curl \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ---- Bootstrap BiocManager + remotes ----
RUN R -q --no-save <<'EOF'
options(Ncpus = parallel::detectCores())
for (p in c("BiocManager", "remotes"))
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
BiocManager::install(ask = FALSE, update = FALSE)   # Bioc release matching R 4.6
EOF

# ---- Helper: install only what's missing, then fail the build if anything is absent ----
RUN cat > /opt/install_pkgs.R <<'EOF'
install_pkgs <- function(pkgs) {
  options(Ncpus = parallel::detectCores())
  need <- setdiff(pkgs, rownames(installed.packages()))
  if (length(need)) BiocManager::install(need, ask = FALSE, update = FALSE)
  miss <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(miss)) stop("Not installed: ", paste(miss, collapse = ", "))
  cat("OK:", length(pkgs), "packages\n")
}
EOF

# ---- Bioconductor: RNA-seq, enrichment, TF activity ----
RUN R -q --no-save <<'EOF'
source("/opt/install_pkgs.R")
install_pkgs(c(
  "DESeq2", "edgeR", "limma", "apeglm", "biomaRt", "AnnotationDbi",
  "org.Hs.eg.db", "org.Mm.eg.db",
  "clusterProfiler", "enrichplot", "DOSE", "ReactomePA", "reactome.db", "graphite",
  "GSVA", "GSEABase", "fgsea",
  "ComplexHeatmap", "EnhancedVolcano", "tidybulk",
  "dorothea", "OmnipathR"
))
EOF

# ---- Bioconductor: ChIP-seq / ATAC-seq / genome tracks / TCGA ----
RUN R -q --no-save <<'EOF'
source("/opt/install_pkgs.R")
install_pkgs(c(
  "ChIPseeker", "DiffBind", "Gviz",
  "TxDb.Hsapiens.UCSC.hg38.knownGene", "TxDb.Mmusculus.UCSC.mm39.knownGene",
  "TCGAbiolinks", "GenomicDataCommons"
))
EOF

# ---- Bioconductor: single-cell infrastructure ----
RUN R -q --no-save <<'EOF'
source("/opt/install_pkgs.R")
install_pkgs(c(
  "SingleCellExperiment", "scater", "scran", "scuttle", "metapod",
  "BiocNeighbors", "BiocSingular", "HDF5Array", "sparseMatrixStats"
))
EOF

# ---- CRAN: plotting, utilities, data I/O ----
RUN R -q --no-save <<'EOF'
source("/opt/install_pkgs.R")
install_pkgs(c(
  "msigdbr", "homologene",
  "ggrepel", "pheatmap", "RColorBrewer", "gplots", "viridis", "corrplot",
  "ggsci", "ggsignif", "ggridges", "ggrastr", "ggtext", "ggvenn",
  "UpSetR", "ComplexUpset", "svglite",
  "data.table", "janitor", "openxlsx", "writexl", "docopt",
  "fastDummies", "doBy", "carData", "FNN", "ROCR", "Rtsne", "quantreg",
  "memuse", "reticulate"
))
EOF

# ---- CRAN: survival + stats ----
RUN R -q --no-save <<'EOF'
source("/opt/install_pkgs.R")
install_pkgs(c(
  "survival", "ggsurvfit", "survminer", "survMisc",
  "broom", "broom.helpers", "forestmodel",
  "maxstat", "exactRankTests", "fitdistrplus", "goftest", "polynom"
))
EOF

# ---- CRAN: Seurat / Signac stack ----
RUN R -q --no-save <<'EOF'
source("/opt/install_pkgs.R")
install_pkgs(c(
  "Seurat", "SeuratObject", "Signac", "sctransform",
  "patchwork", "ggpubr", "cowplot",
  "ica", "RANN", "RcppAnnoy", "RcppHNSW", "RcppProgress",
  "pbapply", "progressr", "spam", "sp", "tensor", "dqrng", "minqa", "nloptr"
))
EOF

# ---- Rocker extras you had (usually already in the base image) ----
RUN R -q --no-save <<'EOF'
source("/opt/install_pkgs.R")
install_pkgs(c(
  "tidyverse", "devtools", "BiocManager", "littler",
  "arrow", "duckdb", "fst", "RMariaDB", "RPostgres", "Lahman", "nycflights13"
))
EOF

# ---- Final parity check: every top-level package from the old image + the ones it missed ----
RUN R -q --no-save <<'EOF'
old_top <- c(
  "BiocNeighbors", "BiocSingular", "ChIPseeker", "clusterProfiler",
  "ComplexHeatmap", "DiffBind", "dorothea", "edgeR", "EnhancedVolcano",
  "GenomicDataCommons", "graphite", "GSEABase", "Gviz", "HDF5Array", "metapod",
  "OmnipathR", "org.Hs.eg.db", "org.Mm.eg.db", "reactome.db", "scuttle",
  "sparseMatrixStats", "TCGAbiolinks", "tidybulk",
  "TxDb.Hsapiens.UCSC.hg38.knownGene", "TxDb.Mmusculus.UCSC.mm39.knownGene",
  "arrow", "BiocManager", "broom.helpers", "carData", "ComplexUpset",
  "corrplot", "devtools", "doBy", "docopt", "dqrng", "duckdb",
  "exactRankTests", "fastDummies", "fitdistrplus", "FNN", "forestmodel",
  "fst", "ggrastr", "ggridges", "ggsci", "ggsignif", "ggsurvfit", "ggtext",
  "ggvenn", "goftest", "homologene", "ica", "janitor", "Lahman", "littler",
  "memuse", "minqa", "msigdbr", "nloptr", "nycflights13", "openxlsx",
  "pbapply", "pheatmap", "polynom", "progressr", "quantreg", "RANN",
  "RcppAnnoy", "RcppHNSW", "RcppProgress", "reticulate", "RMariaDB", "ROCR",
  "RPostgres", "Rtsne", "sctransform", "sp", "spam", "survMisc", "svglite",
  "tensor", "tidyverse", "UpSetR", "viridis", "writexl"
)
previously_missing <- c(
  "DESeq2", "apeglm", "limma", "biomaRt", "fgsea", "GSVA", "ReactomePA",
  "SingleCellExperiment", "scater", "scran",
  "Seurat", "SeuratObject", "Signac", "survminer", "ggpubr", "maxstat",
  "cowplot", "patchwork"
)
expected <- unique(c(old_top, previously_missing))
miss <- expected[!vapply(expected, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) stop("Parity check failed, missing: ", paste(miss, collapse = ", "))
cat("\nParity check passed:", length(expected), "packages |", R.version.string,
    "| Bioconductor", as.character(BiocManager::version()), "\n")
EOF

EXPOSE 8787
CMD ["/init"]

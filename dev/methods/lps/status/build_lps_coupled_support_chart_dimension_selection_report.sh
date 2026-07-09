#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEX="$SCRIPT_DIR/lps_coupled_support_chart_dimension_selection_report.tex"
BUILD_INFO="$SCRIPT_DIR/lps_coupled_support_chart_dimension_selection_report_build_info.tex"

BUILD_DATETIME="$(TZ='America/New_York' date '+%Y-%m-%d %H:%M:%S %Z')"

cat > "$BUILD_INFO" <<EOF
\renewcommand{\reportbuilddatetime}{$BUILD_DATETIME}
EOF

cd "$SCRIPT_DIR"
pdflatex -interaction=nonstopmode -halt-on-error "$(basename "$TEX")"
pdflatex -interaction=nonstopmode -halt-on-error "$(basename "$TEX")"

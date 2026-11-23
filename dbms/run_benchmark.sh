#!/usr/bin/env bash
# ==============================================================================
# Patra AP 2026: Benchmark Runner for 68 Relational Workload Queries
# Team T0066 | PostgreSQL 18.6
#
# Usage: ./dbms/run_benchmark.sh [database_name]
# Default database: patra_ap
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 "$ROOT/dbms/run_benchmark.py" "$@"

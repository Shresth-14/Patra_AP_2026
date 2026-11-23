#!/usr/bin/env python3
"""Run every CP3 query three times and save PostgreSQL execution plans."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
QUERY_FILE = ROOT / "dbms" / "04_queries.sql"
PLANS_DIR = ROOT / "dbms" / "plans"
TIMINGS_FILE = ROOT / "dbms" / "05_query_timings.md"
MARKER = re.compile(
    r"^--\s+([RW]\d+)\s+--\s+(READ|WRITE)\s+(.*?)\n(.*?)(?=^--\s+[RW]\d+\s+--|\Z)",
    re.MULTILINE | re.DOTALL,
)
EXECUTION_TIME = re.compile(r"Execution Time:\s+([\d.]+)\s+ms")


def read_queries() -> list[dict[str, str]]:
    source = QUERY_FILE.read_text(encoding="utf-8")
    queries: list[dict[str, str]] = []
    for match in MARKER.finditer(source):
        query_id, query_type, description, body = match.groups()
        # Query comments are documentation; execute only the SQL statement.
        sql = re.sub(r"--[^\n]*", "", body).strip()
        if not sql:
            raise ValueError(f"{query_id} has no SQL statement")
        statements = [part.strip() for part in sql.split(";") if part.strip()]
        if len(statements) != 1:
            raise ValueError(f"{query_id} must contain one SQL statement, found {len(statements)}")
        queries.append(
            {"id": query_id, "type": query_type, "description": description.strip(), "sql": statements[0]}
        )
    queries.sort(key=lambda item: (item["id"][0] != "R", int(item["id"][1:])))
    if not queries:
        raise ValueError(f"No query markers found in {QUERY_FILE}")
    return queries


def psql(args: argparse.Namespace, sql: str) -> str:
    command = [args.psql, "-X", "-v", "ON_ERROR_STOP=1", "-P", "pager=off", "-qAt"]
    if args.host:
        command.extend(["-h", args.host])
    if args.port:
        command.extend(["-p", str(args.port)])
    if args.user:
        command.extend(["-U", args.user])
    command.extend(["-d", args.database, "-c", sql])
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"psql failed with exit code {result.returncode}")
    return result.stdout


def run_queries(args: argparse.Namespace) -> tuple[list[dict[str, object]], str, str]:
    queries = read_queries()
    PLANS_DIR.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, object]] = []

    for query in queries:
        plan_parts: list[str] = []
        times: list[float] = []
        for run_number in range(1, 4):
            explained_sql = f"EXPLAIN (ANALYZE, BUFFERS, TIMING ON)\n{query['sql']}"
            if query["type"] == "WRITE":
                sql = f"SET search_path TO patra, public; BEGIN; {explained_sql}; ROLLBACK;"
            else:
                sql = f"SET search_path TO patra, public; {explained_sql};"
            plan = psql(args, sql).strip()
            matches = EXECUTION_TIME.findall(plan)
            if len(matches) != 1:
                raise RuntimeError(f"{query['id']} run {run_number}: expected one Execution Time, got {len(matches)}")
            times.append(float(matches[0]))
            plan_parts.append(f"=== {query['id']} run {run_number} ===\n{plan}\n")
        (PLANS_DIR / f"{query['id']}.txt").write_text("\n".join(plan_parts), encoding="utf-8")
        rows.append({**query, "times": times, "average": sum(times) / len(times)})
        print(f"{query['id']}: {times[0]:.3f}, {times[1]:.3f}, {times[2]:.3f} ms")

    version = psql(args, "SELECT version();").strip().splitlines()[0]
    row_total = psql(args, "SELECT sum(n_live_tup)::bigint FROM pg_stat_user_tables;").strip()
    return rows, version, row_total


def generate_report(rows: list[dict[str, object]], version: str, row_total: str) -> None:
    md = [
        "# Patra AP: Baseline Query Timings",
        "",
        f"**Database:** `{os.environ.get('PGDATABASE', 'patra_ap')}` | **PostgreSQL:** `{version}` | **Seeded rows:** {row_total}",
        "",
        "## Methodology",
        "",
        "- Schema: `dbms/03_schema.sql`; deterministic fixtures: `dbms/seed.sql`.",
        f"- Workload: {len(rows)} queries from `dbms/04_queries.sql` ({sum(r['type'] == 'READ' for r in rows)} READ and {sum(r['type'] == 'WRITE' for r in rows)} WRITE).",
        "- Each query was measured three times with `EXPLAIN (ANALYZE, BUFFERS, TIMING ON)` against the local benchmark database.",
        "- WRITE queries ran inside `BEGIN`/`ROLLBACK`, so every run started from the same fixture state.",
        "- Full plans for all runs are saved in `dbms/plans/<query_id>.txt`.",
        "- These figures describe this local PostgreSQL version and synthetic fixture set; they are not production latency estimates.",
        "",
        "## Timings",
        "",
        "| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |",
        "|:---|:---:|:---|---:|---:|---:|---:|",
    ]
    for row in rows:
        t = row["times"]
        md.append(
            f"| {row['id']} | {row['type']} | {row['description']} | {t[0]:.3f} | {t[1]:.3f} | {t[2]:.3f} | {row['average']:.3f} |"
        )
    TIMINGS_FILE.write_text("\n".join(md) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", default=os.environ.get("PGDATABASE", "patra_ap"))
    parser.add_argument("--host", default=os.environ.get("PGHOST"))
    parser.add_argument("--port", type=int, default=int(os.environ["PGPORT"]) if os.environ.get("PGPORT") else None)
    parser.add_argument("--user", default=os.environ.get("PGUSER"))
    parser.add_argument("--psql", default=os.environ.get("PSQL", "psql"))
    args = parser.parse_args()
    try:
        rows, version, row_total = run_queries(args)
        generate_report(rows, version, row_total)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"benchmark failed: {exc}", file=sys.stderr)
        return 1
    print(f"Wrote {TIMINGS_FILE.relative_to(ROOT)} and {len(rows)} plan files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

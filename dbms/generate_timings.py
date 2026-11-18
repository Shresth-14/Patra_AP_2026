import os
import re

PLANS_DIR = 'dbms/plans'

with open('dbms/04_queries.sql') as f:
    text = f.read()

matches = re.finditer(r'-- ([RW]\d+)\s+--\s+(READ|WRITE)\s+(.*?)\n(.*?)(?=\n-- [RW]\d+|\Z)', text, re.DOTALL)

queries = []
for m in matches:
    qid = m.group(1)
    qtype = m.group(2)
    desc = m.group(3).strip()
    queries.append((qid, qtype, desc))

def sort_key(item):
    qid = item[0]
    return (0 if qid.startswith('R') else 1, int(qid[1:]))

queries.sort(key=sort_key)

rows = []
for qid, qtype, desc in queries:
    plan_path = os.path.join(PLANS_DIR, f'{qid}.txt')
    with open(plan_path) as pf:
        plan_content = pf.read()
    
    runs = re.split(r'=== ' + qid + r' run \d ===', plan_content)[1:]
    times = []
    for r in runs:
        m_time = re.search(r'Execution Time:\s+([\d\.]+)\s+ms', r)
        times.append(float(m_time.group(1)) if m_time else 0.0)
    
    avg_time = sum(times) / len(times)
    
    # Scans
    scans = re.findall(r'\b(Index Only Scan|Index Scan|Bitmap Heap Scan|Seq Scan)\b', plan_content)
    unique_scans = []
    for s in scans:
        if s not in unique_scans:
            unique_scans.append(s)
    scan_str = ', '.join(unique_scans) if unique_scans else '—'
    
    rows.append({
        'qid': qid,
        'type': qtype,
        'desc': desc,
        'run1': times[0],
        'run2': times[1],
        'run3': times[2],
        'avg': avg_time,
        'scan': scan_str
    })

md = []
md.append('# Patra AP: Baseline Query Timings')
md.append('')
md.append('**Team:** T0066 | **Database:** `patra_ap` | **PostgreSQL Version:** 18.6 | **Dataset:** 203,450 rows across 22 tables')
md.append('**Benchmarked On:** Apple MacBook Pro (Apple M4, 16 GB unified memory)')
md.append('')
md.append('---')
md.append('')
md.append('## Methodology & Setup')
md.append('')
md.append('- **Schema & Fixtures:** Built using `dbms/03_schema.sql` and populated with deterministic test data via `dbms/seed.sql` (203,450 rows total), followed by a complete database-wide `ANALYZE`.')
md.append('- **Query Workload:** 68 queries in total (32 READ queries `R1`–`R32` and 36 WRITE queries `W1`–`W36`), translated directly from the Patra mail application domain models as defined in `dbms/04_queries.sql`.')
md.append('- **Execution Protocol:** Every query was executed for 3 consecutive runs using `EXPLAIN (ANALYZE, BUFFERS)`.')
md.append('- **Write Query Isolation:** All WRITE operations (`W1` through `W36`) were executed within atomic transactions wrapped in `BEGIN ... ROLLBACK;`, ensuring zero persistent mutations and guaranteeing identical database state across all benchmark runs.')
md.append('- **Raw Execution Plans:** The full query plan tree, buffer hit/read metrics, and timing breakdown for every individual run are saved in `dbms/plans/<query_id>.txt`.')
md.append('')
md.append('---')
md.append('')
md.append('## Timing Table')
md.append('')
md.append('| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan type |')
md.append('|:---|:---:|:---|---:|---:|---:|---:|:---|')

for r in rows:
    md.append(f"| {r['qid']} | {r['type']} | {r['desc']} | {r['run1']:.3f} | {r['run2']:.3f} | {r['run3']:.3f} | {r['avg']:.3f} | {r['scan']} |")

md.append('')
md.append('---')
md.append('')
md.append('## Summary Statistics')
md.append('')
read_rows = [r for r in rows if r['type'] == 'READ']
write_rows = [r for r in rows if r['type'] == 'WRITE']

r_run1_sum = sum(r['run1'] for r in read_rows)
r_run2_sum = sum(r['run2'] for r in read_rows)
r_run3_sum = sum(r['run3'] for r in read_rows)
r_avg_sum = sum(r['avg'] for r in read_rows)

w_run1_sum = sum(r['run1'] for r in write_rows)
w_run2_sum = sum(r['run2'] for r in write_rows)
w_run3_sum = sum(r['run3'] for r in write_rows)
w_avg_sum = sum(r['avg'] for r in write_rows)

total_run1_sum = sum(r['run1'] for r in rows)
total_run2_sum = sum(r['run2'] for r in rows)
total_run3_sum = sum(r['run3'] for r in rows)
total_avg_sum = sum(r['avg'] for r in rows)

fastest = min(rows, key=lambda x: x['avg'])
slowest = max(rows, key=lambda x: x['avg'])

md.append('| Category | Query Count | Run 1 Sum (ms) | Run 2 Sum (ms) | Run 3 Sum (ms) | Average Sum (ms) | Mean per Query (ms) |')
md.append('|:---|---:|---:|---:|---:|---:|---:|')
md.append(f'| **READ Queries (R1–R32)** | 32 | {r_run1_sum:.3f} | {r_run2_sum:.3f} | {r_run3_sum:.3f} | {r_avg_sum:.3f} | {r_avg_sum/32:.3f} |')
md.append(f'| **WRITE Queries (W1–W36)** | 36 | {w_run1_sum:.3f} | {w_run2_sum:.3f} | {w_run3_sum:.3f} | {w_avg_sum:.3f} | {w_avg_sum/36:.3f} |')
md.append(f'| **Total Workload (All 68)** | **68** | **{total_run1_sum:.3f}** | **{total_run2_sum:.3f}** | **{total_run3_sum:.3f}** | **{total_avg_sum:.3f}** | **{total_avg_sum/68:.3f}** |')
md.append('')
md.append(f'- **Fastest Query:** `{fastest["qid"]}` ({fastest["desc"]}) at **{fastest["avg"]:.3f} ms**')
md.append(f'- **Slowest Query:** `{slowest["qid"]}` ({slowest["desc"]}) at **{slowest["avg"]:.3f} ms**')
md.append('')
md.append('### Key Observations')
md.append('')
md.append('1. **Small Table Optimization & Scan Selection:** For small configuration and dimension tables (such as `users` with 250 rows, `roles` with 40 rows, and `organizations` with 10 rows), the PostgreSQL cost optimizer deliberately selects sequential memory scans (`Seq Scan`) over index descent because the entire table fits into a few 8 KB pages in shared memory (e.g. `R1` takes only ~0.034 ms with 5 buffer hits).')
md.append('2. **Large Relational Operations:** In high-volume tables (`campaign_recipients` with 60,000 rows, `list_contacts` with 40,000 rows, `contacts` with 25,000 rows), queries utilizing composite indexes (such as `R16` and `R17`) leverage index scans and index-only scans, completing within 2–3 ms.')
md.append('3. **Batch Insertion & Integrity Triggers:** The heaviest query in the workload is `W27` (Queue campaign recipients), which joins `campaigns`, `list_contacts`, and `contacts`, checks exclusions in `suppressions`, and inserts 4,800 recipients into `campaign_recipients`. It requires ~41 ms, of which ~19 ms is spent verifying foreign key constraints (`fk_campaign_recipients_campaign_org` and `fk_campaign_recipients_contact_org`).')
md.append('4. **Buffer Cache Stability:** Across runs 1, 2, and 3, execution latencies remain stable due to all active working set buffers being warm in PostgreSQL shared buffers.')

with open('dbms/05_query_timings.md', 'w') as f:
    f.write('\n'.join(md) + '\n')

print('Generated dbms/05_query_timings.md successfully!')

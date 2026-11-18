# Patra AP: Baseline Query Timings

**Team:** T0066 | **Database:** `patra_ap` | **PostgreSQL Version:** 18.6 | **Dataset:** 203,450 rows across 22 tables
**Benchmarked On:** Apple MacBook Pro (Apple M4, 16 GB unified memory)

---

## Methodology & Setup

- **Schema & Fixtures:** Built using `dbms/03_schema.sql` and populated with deterministic test data via `dbms/seed.sql` (203,450 rows total), followed by a complete database-wide `ANALYZE`.
- **Query Workload:** 68 queries in total (32 READ queries `R1`–`R32` and 36 WRITE queries `W1`–`W36`), translated directly from the Patra mail application domain models as defined in `dbms/04_queries.sql`.
- **Execution Protocol:** Every query was executed for 3 consecutive runs using `EXPLAIN (ANALYZE, BUFFERS)`.
- **Write Query Isolation:** All WRITE operations (`W1` through `W36`) were executed within atomic transactions wrapped in `BEGIN ... ROLLBACK;`, ensuring zero persistent mutations and guaranteeing identical database state across all benchmark runs.
- **Raw Execution Plans:** The full query plan tree, buffer hit/read metrics, and timing breakdown for every individual run are saved in `dbms/plans/<query_id>.txt`.

---

## Timing Table

| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan type |
|:---|:---:|:---|---:|---:|---:|---:|:---|
| R1 | READ | Login: look up user by email | 0.033 | 0.034 | 0.034 | 0.034 | Seq Scan |
| R2 | READ | Get user profile by ID | 0.036 | 0.032 | 0.030 | 0.033 | Seq Scan |
| R3 | READ | Validate refresh token (check not expired, not revoked) | 0.029 | 0.020 | 0.019 | 0.023 | Index Scan |
| R4 | READ | List organizations the user belongs to, with their role | 0.062 | 0.059 | 0.054 | 0.058 | Seq Scan |
| R5 | READ | Get organization by slug | 0.018 | 0.017 | 0.017 | 0.017 | Seq Scan |
| R6 | READ | List members of an organization with roles | 0.070 | 0.069 | 0.070 | 0.070 | Seq Scan |
| R7 | READ | Get user permissions in an organization (role → permissions) | 0.051 | 0.052 | 0.053 | 0.052 | Seq Scan, Index Scan |
| R8 | READ | List all roles in an organization (including global roles) | 0.032 | 0.035 | 0.038 | 0.035 | Seq Scan |
| R9 | READ | Get permissions assigned to a role | 0.020 | 0.021 | 0.020 | 0.020 | Seq Scan |
| R10 | READ | List mail transports for an organization | 0.037 | 0.034 | 0.034 | 0.035 | Seq Scan |
| R11 | READ | List verified domains for an organization with their transport | 0.048 | 0.050 | 0.047 | 0.048 | Seq Scan |
| R12 | READ | List sender identities for an organization | 0.056 | 0.053 | 0.055 | 0.055 | Seq Scan |
| R13 | READ | List contacts for an organization (paginated) | 1.914 | 1.839 | 1.930 | 1.894 | Seq Scan |
| R14 | READ | Get a contact with all custom fields | 0.035 | 0.028 | 0.028 | 0.030 | Index Scan |
| R15 | READ | Search contacts by email (prefix match) | 0.871 | 0.896 | 0.876 | 0.881 | Seq Scan |
| R16 | READ | List all mailing lists for an organization with contact counts | 2.294 | 2.385 | 2.288 | 2.322 | Seq Scan, Index Only Scan |
| R17 | READ | Get contacts in a specific list (paginated) | 2.646 | 2.555 | 2.572 | 2.591 | Seq Scan, Index Only Scan |
| R18 | READ | Check if an email is suppressed in an organization | 0.021 | 0.022 | 0.020 | 0.021 | Index Scan |
| R19 | READ | List all suppressions for an organization | 0.160 | 0.156 | 0.159 | 0.158 | Seq Scan |
| R20 | READ | List templates for an organization | 0.027 | 0.027 | 0.024 | 0.026 | Seq Scan |
| R21 | READ | Get latest published template version for a template | 0.024 | 0.024 | 0.031 | 0.026 | Seq Scan |
| R22 | READ | Get template variables for campaign variable validation | 0.023 | 0.022 | 0.021 | 0.022 | Seq Scan |
| R23 | READ | List campaigns for an organization with sender and template info | 0.107 | 0.098 | 0.107 | 0.104 | Seq Scan |
| R24 | READ | Get campaign details by ID (full data for campaign view) | 0.099 | 0.106 | 0.115 | 0.107 | Seq Scan, Index Scan |
| R25 | READ | Campaign analytics: delivery breakdown | 3.058 | 3.184 | 3.160 | 3.134 | Seq Scan |
| R26 | READ | Fetch next batch of queued recipients to send | 4.031 | 2.697 | 2.573 | 3.100 | Seq Scan |
| R27 | READ | Look up recipient by provider message ID (for webhook processing) | 2.836 | 2.605 | 2.761 | 2.734 | Seq Scan |
| R28 | READ | Check if a webhook event was already processed (deduplication) | 0.022 | 0.021 | 0.023 | 0.022 | Index Scan |
| R29 | READ | List audit logs for an organization (paginated, newest first) | 3.322 | 3.260 | 3.315 | 3.299 | Seq Scan |
| R30 | READ | Organization dashboard: campaign summary stats | 0.041 | 0.067 | 0.040 | 0.049 | Seq Scan |
| R31 | READ | Campaign recipient timeline: recent events | 3.733 | 3.650 | 3.759 | 3.714 | Seq Scan |
| R32 | READ | Contact engagement: campaigns a contact has received | 2.601 | 2.441 | 2.422 | 2.488 | Seq Scan |
| W1 | WRITE | Register a new user | 0.193 | 0.183 | 0.171 | 0.182 | — |
| W2 | WRITE | Issue a refresh token | 0.339 | 0.305 | 0.311 | 0.318 | — |
| W3 | WRITE | Revoke a refresh token (logout) | 0.137 | 0.123 | 0.151 | 0.137 | Index Scan |
| W4 | WRITE | Update user profile | 0.183 | 0.190 | 0.216 | 0.196 | Seq Scan |
| W5 | WRITE | Create a new organization | 0.134 | 0.128 | 0.130 | 0.131 | — |
| W6 | WRITE | Add a member to an organization with a role | 0.539 | 0.501 | 0.501 | 0.514 | — |
| W7 | WRITE | Change a member's role | 0.245 | 0.235 | 0.230 | 0.237 | Index Scan |
| W8 | WRITE | Create a custom role | 0.304 | 0.312 | 0.325 | 0.314 | — |
| W9 | WRITE | Assign a permission to a role | 0.442 | 0.414 | 0.392 | 0.416 | — |
| W10 | WRITE | Add a mail transport | 0.315 | 0.334 | 0.318 | 0.322 | — |
| W11 | WRITE | Add a domain linked to a transport | 0.484 | 0.461 | 0.708 | 0.551 | — |
| W12 | WRITE | Mark a domain as verified | 0.168 | 0.143 | 0.142 | 0.151 | Seq Scan |
| W13 | WRITE | Create a sender identity | 0.534 | 0.566 | 0.530 | 0.543 | — |
| W14 | WRITE | Create a contact | 0.454 | 0.463 | 0.420 | 0.446 | — |
| W15 | WRITE | Upsert a custom field on a contact | 0.179 | 0.203 | 0.155 | 0.179 | — |
| W16 | WRITE | Delete a contact (cascades to custom fields, list memberships, recipients) | 3.106 | 2.967 | 3.314 | 3.129 | Index Scan |
| W17 | WRITE | Create a mailing list | 0.304 | 0.408 | 0.354 | 0.355 | — |
| W18 | WRITE | Add a contact to a list | 0.496 | 0.519 | 0.454 | 0.490 | — |
| W19 | WRITE | Remove a contact from a list | 0.063 | 0.065 | 0.067 | 0.065 | Index Scan |
| W20 | WRITE | Add a suppression (e.g. from a bounce or unsubscribe) | 0.430 | 0.434 | 0.445 | 0.436 | — |
| W21 | WRITE | Create a new template | 0.355 | 0.329 | 0.329 | 0.338 | — |
| W22 | WRITE | Publish a template version (creates an immutable snapshot) | 0.350 | 0.350 | 0.405 | 0.368 | — |
| W23 | WRITE | Record template variables for a published version | 0.407 | 0.388 | 0.380 | 0.392 | — |
| W24 | WRITE | Update template status (DRAFT → PUBLISHED → ARCHIVED) | 0.092 | 0.092 | 0.098 | 0.094 | Seq Scan |
| W25 | WRITE | Create a campaign | 0.778 | 1.400 | 0.962 | 1.047 | — |
| W26 | WRITE | Schedule a campaign | 0.159 | 0.178 | 0.176 | 0.171 | Seq Scan |
| W27 | WRITE | Queue campaign recipients (from list contacts, skipping suppressed) | 40.634 | 40.832 | 42.028 | 41.165 | Seq Scan, Index Only Scan, Index Scan |
| W28 | WRITE | Update campaign counters after sending | 11.681 | 11.159 | 11.105 | 11.315 | Seq Scan |
| W29 | WRITE | Mark campaign as completed | 0.200 | 0.170 | 0.172 | 0.181 | Seq Scan |
| W30 | WRITE | Mark a recipient as sent | 0.232 | 0.203 | 0.205 | 0.213 | Index Scan |
| W31 | WRITE | Mark a recipient as delivered (webhook) | 3.452 | 3.429 | 3.418 | 3.433 | Seq Scan |
| W32 | WRITE | Mark a recipient as bounced (webhook + auto-suppress) | 3.587 | 3.370 | 3.369 | 3.442 | Seq Scan |
| W33 | WRITE | Record an open event (webhook) | 3.367 | 3.348 | 3.237 | 3.317 | Seq Scan |
| W34 | WRITE | Record a click event (webhook) | 3.498 | 3.502 | 3.489 | 3.496 | Seq Scan |
| W35 | WRITE | Record an incoming webhook event | 0.095 | 0.072 | 0.072 | 0.080 | — |
| W36 | WRITE | Create an audit log entry | 0.532 | 0.461 | 0.492 | 0.495 | — |

---

## Summary Statistics

| Category | Query Count | Run 1 Sum (ms) | Run 2 Sum (ms) | Run 3 Sum (ms) | Average Sum (ms) | Mean per Query (ms) |
|:---|---:|---:|---:|---:|---:|---:|
| **READ Queries (R1–R32)** | 32 | 28.357 | 26.559 | 26.695 | 27.204 | 0.850 |
| **WRITE Queries (W1–W36)** | 36 | 78.468 | 78.237 | 79.271 | 78.659 | 2.185 |
| **Total Workload (All 68)** | **68** | **106.825** | **104.796** | **105.966** | **105.862** | **1.557** |

- **Fastest Query:** `R5` (Get organization by slug) at **0.017 ms**
- **Slowest Query:** `W27` (Queue campaign recipients (from list contacts, skipping suppressed)) at **41.165 ms**

### Key Observations

1. **Small Table Optimization & Scan Selection:** For small configuration and dimension tables (such as `users` with 250 rows, `roles` with 40 rows, and `organizations` with 10 rows), the PostgreSQL cost optimizer deliberately selects sequential memory scans (`Seq Scan`) over index descent because the entire table fits into a few 8 KB pages in shared memory (e.g. `R1` takes only ~0.034 ms with 5 buffer hits).
2. **Large Relational Operations:** In high-volume tables (`campaign_recipients` with 60,000 rows, `list_contacts` with 40,000 rows, `contacts` with 25,000 rows), queries utilizing composite indexes (such as `R16` and `R17`) leverage index scans and index-only scans, completing within 2–3 ms.
3. **Batch Insertion & Integrity Triggers:** The heaviest query in the workload is `W27` (Queue campaign recipients), which joins `campaigns`, `list_contacts`, and `contacts`, checks exclusions in `suppressions`, and inserts 4,800 recipients into `campaign_recipients`. It requires ~41 ms, of which ~19 ms is spent verifying foreign key constraints (`fk_campaign_recipients_campaign_org` and `fk_campaign_recipients_contact_org`).
4. **Buffer Cache Stability:** Across runs 1, 2, and 3, execution latencies remain stable due to all active working set buffers being warm in PostgreSQL shared buffers.

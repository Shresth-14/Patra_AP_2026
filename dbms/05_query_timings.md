# Patra AP: Baseline Query Timings

**Database:** `patra_ap` | **PostgreSQL:** `PostgreSQL 15.19 (Homebrew) on aarch64-apple-darwin25.6.0, compiled by Apple clang version 21.0.0 (clang-2100.1.1.101), 64-bit` | **Seeded rows:** 203450

## Methodology

- Schema: `dbms/03_schema.sql`; deterministic fixtures: `dbms/seed.sql`.
- Workload: 68 queries from `dbms/04_queries.sql` (32 READ and 36 WRITE).
- Each query was measured three times with `EXPLAIN (ANALYZE, BUFFERS, TIMING ON)` against the local benchmark database.
- WRITE queries ran inside `BEGIN`/`ROLLBACK`, so every run started from the same fixture state.
- Full plans for all runs are saved in `dbms/plans/<query_id>.txt`.
- These figures describe this local PostgreSQL version and synthetic fixture set; they are not production latency estimates.

## Timings

| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|:---|:---:|:---|---:|---:|---:|---:|
| R1 | READ | Login: look up user by email | 0.047 | 0.042 | 0.038 | 0.042 |
| R2 | READ | Get user profile by ID | 0.040 | 0.041 | 0.039 | 0.040 |
| R3 | READ | Validate refresh token (check not expired, not revoked) | 0.021 | 0.021 | 0.020 | 0.021 |
| R4 | READ | List organizations the user belongs to, with their role | 0.104 | 0.099 | 0.094 | 0.099 |
| R5 | READ | Get organization by slug | 0.024 | 0.024 | 0.025 | 0.024 |
| R6 | READ | List members of an organization with roles | 0.138 | 0.125 | 0.143 | 0.135 |
| R7 | READ | Get user permissions in an organization (role → permissions) | 0.089 | 0.080 | 0.088 | 0.086 |
| R8 | READ | List all roles in an organization (including global roles) | 0.054 | 0.053 | 0.060 | 0.056 |
| R9 | READ | Get permissions assigned to a role | 0.041 | 0.038 | 0.039 | 0.039 |
| R10 | READ | List mail transports for an organization | 0.059 | 0.060 | 0.061 | 0.060 |
| R11 | READ | List verified domains for an organization with their transport | 0.092 | 0.077 | 0.077 | 0.082 |
| R12 | READ | List sender identities for an organization | 0.096 | 0.085 | 0.085 | 0.089 |
| R13 | READ | List contacts for an organization (paginated) | 4.400 | 4.019 | 3.894 | 4.104 |
| R14 | READ | Get a contact with all custom fields | 0.053 | 0.048 | 0.047 | 0.049 |
| R15 | READ | Search contacts by email (prefix match) | 0.044 | 0.041 | 0.034 | 0.040 |
| R16 | READ | List all mailing lists for an organization with contact counts | 4.937 | 4.685 | 5.013 | 4.878 |
| R17 | READ | Get contacts in a specific list (paginated) | 5.663 | 5.316 | 5.392 | 5.457 |
| R18 | READ | Check if an email is suppressed in an organization | 0.037 | 0.089 | 0.034 | 0.053 |
| R19 | READ | List all suppressions for an organization | 0.327 | 0.326 | 0.318 | 0.324 |
| R20 | READ | List templates for an organization | 0.044 | 0.042 | 0.041 | 0.042 |
| R21 | READ | Get latest published template version for a template | 0.057 | 0.046 | 0.039 | 0.047 |
| R22 | READ | Get template variables for campaign variable validation | 0.045 | 0.038 | 0.040 | 0.041 |
| R23 | READ | List campaigns for an organization with sender and template info | 0.200 | 0.179 | 0.175 | 0.185 |
| R24 | READ | Get campaign details by ID (full data for campaign view) | 0.169 | 0.172 | 0.156 | 0.166 |
| R25 | READ | Campaign analytics: delivery breakdown | 7.234 | 6.468 | 6.667 | 6.790 |
| R26 | READ | Fetch next batch of queued recipients to send | 5.691 | 5.324 | 5.684 | 5.566 |
| R27 | READ | Look up recipient by provider message ID (for webhook processing) | 5.888 | 6.376 | 5.958 | 6.074 |
| R28 | READ | Check if a webhook event was already processed (deduplication) | 0.042 | 0.030 | 0.027 | 0.033 |
| R29 | READ | List audit logs for an organization (paginated, newest first) | 7.088 | 7.392 | 6.905 | 7.128 |
| R30 | READ | Organization dashboard: campaign summary stats | 0.078 | 0.071 | 0.079 | 0.076 |
| R31 | READ | Campaign recipient timeline: recent events | 7.836 | 7.734 | 7.704 | 7.758 |
| R32 | READ | Contact engagement: campaigns a contact has received | 5.492 | 5.477 | 4.725 | 5.231 |
| W1 | WRITE | Register a new user | 0.382 | 0.262 | 0.285 | 0.310 |
| W2 | WRITE | Issue a refresh token | 0.688 | 0.528 | 0.490 | 0.569 |
| W3 | WRITE | Revoke a refresh token (logout) | 0.229 | 0.203 | 0.201 | 0.211 |
| W4 | WRITE | Update user profile | 0.320 | 0.344 | 0.312 | 0.325 |
| W5 | WRITE | Create a new organization | 0.260 | 0.227 | 0.232 | 0.240 |
| W6 | WRITE | Add a member to an organization with a role | 1.222 | 1.013 | 0.932 | 1.056 |
| W7 | WRITE | Change a member's role | 0.422 | 0.415 | 0.497 | 0.445 |
| W8 | WRITE | Create a custom role | 0.538 | 0.464 | 0.471 | 0.491 |
| W9 | WRITE | Assign a permission to a role | 0.822 | 0.792 | 0.660 | 0.758 |
| W10 | WRITE | Add a mail transport | 0.584 | 0.479 | 0.521 | 0.528 |
| W11 | WRITE | Add a domain linked to a transport | 0.884 | 0.796 | 0.722 | 0.801 |
| W12 | WRITE | Mark a domain as verified | 0.219 | 0.190 | 0.183 | 0.197 |
| W13 | WRITE | Create a sender identity | 1.762 | 0.888 | 0.939 | 1.196 |
| W14 | WRITE | Create a contact | 0.757 | 0.736 | 0.614 | 0.702 |
| W15 | WRITE | Upsert a custom field on a contact | 0.610 | 0.237 | 0.253 | 0.367 |
| W16 | WRITE | Delete a contact (cascades to custom fields, list memberships, recipients) | 8.434 | 7.976 | 7.683 | 8.031 |
| W17 | WRITE | Create a mailing list | 0.879 | 0.640 | 0.700 | 0.740 |
| W18 | WRITE | Add a contact to a list | 1.020 | 0.927 | 0.874 | 0.940 |
| W19 | WRITE | Remove a contact from a list | 0.134 | 0.134 | 0.099 | 0.122 |
| W20 | WRITE | Add a suppression (e.g. from a bounce or unsubscribe) | 0.807 | 0.621 | 0.769 | 0.732 |
| W21 | WRITE | Create a new template | 0.638 | 0.565 | 0.502 | 0.568 |
| W22 | WRITE | Publish a template version (creates an immutable snapshot) | 0.614 | 0.494 | 0.494 | 0.534 |
| W23 | WRITE | Record template variables for a published version | 0.696 | 0.645 | 0.658 | 0.666 |
| W24 | WRITE | Update template status (DRAFT → PUBLISHED → ARCHIVED) | 0.154 | 0.169 | 0.138 | 0.154 |
| W25 | WRITE | Create a campaign | 1.518 | 1.322 | 1.375 | 1.405 |
| W26 | WRITE | Schedule a campaign | 0.271 | 0.317 | 0.280 | 0.289 |
| W27 | WRITE | Queue campaign recipients (from list contacts, skipping suppressed) | 74.389 | 76.514 | 77.357 | 76.087 |
| W28 | WRITE | Update campaign counters after sending | 25.875 | 24.200 | 24.292 | 24.789 |
| W29 | WRITE | Mark campaign as completed | 0.254 | 0.226 | 0.255 | 0.245 |
| W30 | WRITE | Mark a recipient as sent | 0.405 | 0.325 | 0.308 | 0.346 |
| W31 | WRITE | Mark a recipient as delivered (webhook) | 7.965 | 7.683 | 7.379 | 7.676 |
| W32 | WRITE | Mark a recipient as bounced (webhook + auto-suppress) | 7.572 | 7.613 | 7.269 | 7.485 |
| W33 | WRITE | Record an open event (webhook) | 7.417 | 6.904 | 6.625 | 6.982 |
| W34 | WRITE | Record a click event (webhook) | 6.865 | 6.674 | 6.716 | 6.752 |
| W35 | WRITE | Record an incoming webhook event | 0.099 | 0.099 | 0.094 | 0.097 |
| W36 | WRITE | Create an audit log entry | 0.801 | 0.692 | 0.708 | 0.734 |

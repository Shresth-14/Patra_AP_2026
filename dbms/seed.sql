-- =====================================================================
-- Patra AP 2026: Deterministic Seed Data for CP4 Benchmark
-- Team T0066
--
-- Derived from schema in dbms/03_schema.sql and queries in dbms/04_queries.sql.
-- Provides deterministic fixtures for all 32 READ and 36 WRITE queries.
-- Inserts in strict foreign-key dependency order (Level 0 through Level 5).
--
-- Row Counts:
--   - organizations: 10
--   - users: 250
--   - permissions: 30
--   - roles: 40
--   - role_permissions: 150
--   - memberships: 300
--   - refresh_tokens: 500
--   - mail_transports: 25
--   - domains: 35
--   - sender_identities: 50
--   - contacts: 25,000 (Org 3 has 12,000)
--   - contact_custom_fields: 35,000
--   - lists: 60 (Org 3 has 10)
--   - list_contacts: 40,000 (List 9 has exactly 5,000)
--   - suppressions: 1,500 (Org 3 has 800; List 9 has exactly 200 suppressed)
--   - templates: 40
--   - template_versions: 90
--   - template_version_variables: 220
--   - campaigns: 150 (Campaign 12 has 10,000 recipients; Campaign 15 has 0)
--   - campaign_recipients: 60,000
--   - webhook_events: 15,000
--   - audit_logs: 25,000
-- =====================================================================

SET search_path TO patra, public;

BEGIN;

-- =====================================================================
-- LEVEL 0: ROOT TABLES (No Foreign Keys)
-- =====================================================================

-- 1. ORGANIZATIONS (10 total)
-- Primary benchmark tenant: Acme Corp (00000000-0000-0000-0000-000000000003)
-- Reserved slug for W5: 'acme-corp-benchmark' (omitted from seed)
INSERT INTO organizations (organization_id, name, slug, timezone, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000003', 'Acme Corp', 'acme-corp', 'Asia/Kolkata', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0001-000000000001', 'Apex Logistics', 'apex-logistics', 'UTC', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0001-000000000002', 'Beacon Media', 'beacon-media', 'America/New_York', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0001-000000000003', 'Crestline SaaS', 'crestline-saas', 'Europe/London', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0001-000000000004', 'Delta Retail', 'delta-retail', 'Asia/Tokyo', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0001-000000000005', 'Echo Health', 'echo-health', 'UTC', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0001-000000000006', 'Foxglove Studio', 'foxglove-studio', 'America/Los_Angeles', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0001-000000000007', 'Gamma Advisory', 'gamma-advisory', 'Europe/Berlin', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0001-000000000008', 'Horizon Labs', 'horizon-labs', 'Asia/Singapore', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0001-000000000009', 'Iris Stealth', 'iris-stealth', 'UTC', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- 2. USERS (250 total)
-- User 1: Primary auth user for R1, R2, R4, R7, W2, W4, W7, W25, W36
-- User 2: Dedicated fixture for W6 (has NO membership in Org 3)
-- Reserved email for W1: 'newuser@example.com' (omitted from seed)
INSERT INTO users (user_id, email, name, password_hash, avatar_url, is_platform_admin, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'user@example.com', 'Alice Admin', '$2b$12$e8YQ3dZk4L9vP1mQ7rTu4eX7nB1abcdefghijklmnopqrstuv', 'https://cdn.example.com/alice.png', true, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0000-000000000002', 'staff@example.com', 'Bob Staff', '$2b$12$e8YQ3dZk4L9vP1mQ7rTu4eX7nB1abcdefghijklmnopqrstuv', 'https://cdn.example.com/bob.png', false, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

INSERT INTO users (user_id, email, name, password_hash, avatar_url, is_platform_admin, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0002-' || lpad(to_hex(i), 12, '0') AS uuid),
    'user.' || i || '@example.org',
    'User ' || i,
    '$2b$12$e8YQ3dZk4L9vP1mQ7rTu4eX7nB1abcdefghijklmnopqrstuv',
    '',
    false,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(3, 250) AS s(i);

-- 3. PERMISSIONS (30 total)
INSERT INTO permissions (permission_code)
VALUES
    ('campaigns:read'), ('campaigns:create'), ('campaigns:update'), ('campaigns:delete'), ('campaigns:send'),
    ('contacts:read'), ('contacts:create'), ('contacts:update'), ('contacts:delete'), ('contacts:export'),
    ('lists:read'), ('lists:create'), ('lists:update'), ('lists:delete'),
    ('templates:read'), ('templates:create'), ('templates:update'), ('templates:delete'), ('templates:publish'),
    ('domains:read'), ('domains:create'), ('domains:verify'), ('domains:delete'),
    ('transports:read'), ('transports:create'), ('transports:update'), ('transports:delete'),
    ('members:read'), ('members:invite'), ('members:remove');

-- 4. WEBHOOK_EVENTS (15,000 total)
-- Dedicated event for R28: 'evt_resend_xyz789'
-- Reserved event for W35: 'evt_resend_w35_bench' (omitted from seed)
INSERT INTO webhook_events (webhook_event_id, provider, provider_event_id, event_type, payload, received_at)
VALUES
    ('00000000-0000-0000-0000-000000000028', 'RESEND', 'evt_resend_xyz789', 'email.delivered', '{"email": "contact8@acme.com", "event": "delivered"}'::jsonb, TIMESTAMPTZ '2026-11-15 10:15:00Z');

INSERT INTO webhook_events (webhook_event_id, provider, provider_event_id, event_type, payload, received_at)
SELECT
    CAST('00000000-0000-0000-0003-' || lpad(to_hex(i), 12, '0') AS uuid),
    CASE WHEN i % 3 = 0 THEN 'RESEND' WHEN i % 3 = 1 THEN 'SES' ELSE 'SMTP' END,
    'evt_synthetic_' || i,
    CASE WHEN i % 4 = 0 THEN 'email.delivered' WHEN i % 4 = 1 THEN 'email.opened' WHEN i % 4 = 2 THEN 'email.clicked' ELSE 'email.bounced' END,
    ('{"id": ' || i || ', "status": "processed"}')::jsonb,
    TIMESTAMPTZ '2026-01-01 00:00:00Z' + (i * INTERVAL '1 minute')
FROM generate_series(2, 15000) AS s(i);

-- =====================================================================
-- LEVEL 1: DEPENDENT TABLES (Direct References to Level 0)
-- =====================================================================

-- 5. ROLES (40 total)
-- 5 Global System Roles (organization_id IS NULL, is_system = true)
INSERT INTO roles (role_id, organization_id, name, description, is_system, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0004-000000000001', NULL, 'Super Admin', 'Full system access across all orgs', true, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0004-000000000002', NULL, 'Organization Owner', 'Primary administrator for an organization', true, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0004-000000000003', NULL, 'Organization Admin', 'Can manage campaigns, lists and members', true, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0004-000000000004', NULL, 'Standard Member', 'Can compose campaigns and view analytics', true, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0004-000000000005', NULL, 'Auditor', 'Read-only access to audit logs and statistics', true, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- Dedicated roles for Org 3:
-- Role 4: Primary benchmark role for R6, R9, W6, W9 (omits 'campaigns:send' so W9 can insert)
-- Role 5: Target role for W7 role change
-- Reserved name for W8: 'Campaign Manager' (omitted from Org 3)
INSERT INTO roles (role_id, organization_id, name, description, is_system, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', 'Marketing Specialist', 'Can view campaigns and manage templates', false, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000003', 'Compliance Officer', 'Review member actions and suppression records', false, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0004-000000000008', '00000000-0000-0000-0000-000000000003', 'Template Designer', 'Author draft templates', false, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0004-000000000009', '00000000-0000-0000-0000-000000000003', 'List Operator', 'Manage contacts and lists', false, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- Remaining 31 roles across other orgs
INSERT INTO roles (role_id, organization_id, name, description, is_system, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0004-' || lpad(to_hex(i + 9), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0001-' || lpad(to_hex((i % 9) + 1), 12, '0') AS uuid),
    'Custom Role ' || i,
    'Custom role description for testing',
    false,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 31) AS s(i);

-- 6. REFRESH_TOKENS (500 total)
-- Dedicated token for R3 and W3: id ...0002, hash 'hashed_token_value', active, expires 2028
-- Reserved token hash for W2: 'hashed_token' (omitted from seed)
INSERT INTO refresh_tokens (refresh_token_id, user_id, token_hash, expires_at, revoked_at, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'hashed_token_value', TIMESTAMPTZ '2028-01-01 00:00:00Z', NULL, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

INSERT INTO refresh_tokens (refresh_token_id, user_id, token_hash, expires_at, revoked_at, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0006-' || lpad(to_hex(i), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0002-' || lpad(to_hex(((i - 1) % 248) + 3), 12, '0') AS uuid),
    'token_hash_synthetic_' || i,
    CASE WHEN i % 5 = 0 THEN TIMESTAMPTZ '2025-01-01 00:00:00Z' ELSE TIMESTAMPTZ '2027-01-01 00:00:00Z' END,
    CASE WHEN i % 7 = 0 THEN TIMESTAMPTZ '2026-02-01 00:00:00Z' ELSE NULL END,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(2, 500) AS s(i);

-- 7. CONTACTS (25,000 total)
-- Org 3 has exactly 12,000 contacts:
--   - Contact 8: Dedicated for R14, R32, W15
--   - Contact 97: Dedicated for W19 deletion from List 9
--   - Contact 98: Dedicated for W18 insertion into List 9 (omitted from List 9)
--   - Contact 99: Dedicated for W16 cascade delete (zero recipient links)
--   - Contacts 5..150: Prefix 'john.' for R15 (email LIKE 'john%')
-- Reserved email for W14: 'john@example.com' in Org 3 (omitted from seed)
INSERT INTO contacts (contact_id, organization_id, email, name, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000003', 'contact8@acme.com', 'Acme Target Contact 8', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0000-000000000097', '00000000-0000-0000-0000-000000000003', 'contact97@acme.com', 'List Member 97 (For W19)', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0000-000000000098', '00000000-0000-0000-0000-000000000003', 'contact98@acme.com', 'Non List Member 98 (For W18)', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0000-000000000099', '00000000-0000-0000-0000-000000000003', 'contact99@acme.com', 'Disposable Contact 99 (For W16)', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- Remaining 11,996 contacts in Org 3
INSERT INTO contacts (contact_id, organization_id, email, name, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0007-' || lpad(to_hex(i), 12, '0') AS uuid),
    '00000000-0000-0000-0000-000000000003',
    CASE WHEN i <= 150 THEN 'john.' || i || '@acme.com' ELSE 'contact.' || i || '@acme.com' END,
    'Acme Contact ' || i,
    TIMESTAMPTZ '2026-01-01 00:00:00Z' + (i * INTERVAL '1 second'),
    TIMESTAMPTZ '2026-01-01 00:00:00Z' + (i * INTERVAL '1 second')
FROM generate_series(5, 12000) AS s(i);

-- Remaining 13,000 contacts across other orgs (Orgs 2-9)
INSERT INTO contacts (contact_id, organization_id, email, name, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0008-' || lpad(to_hex(i), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0001-' || lpad(to_hex(((i - 1) % 8) + 1), 12, '0') AS uuid),
    'external.contact.' || i || '@tenant.org',
    'External Contact ' || i,
    TIMESTAMPTZ '2026-01-01 00:00:00Z' + (i * INTERVAL '2 seconds'),
    TIMESTAMPTZ '2026-01-01 00:00:00Z' + (i * INTERVAL '2 seconds')
FROM generate_series(1, 13000) AS s(i);

-- 8. LISTS (60 total)
-- Dedicated list for R17, W18, W19, W25, W27: List 9 (00000000-0000-0000-0000-000000000009)
INSERT INTO lists (list_id, organization_id, name, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000003', 'Primary Newsletter Subscribers', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0009-000000000002', '00000000-0000-0000-0000-000000000003', 'Product Updates List', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0009-000000000003', '00000000-0000-0000-0000-000000000003', 'Enterprise Announcements', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0009-000000000004', '00000000-0000-0000-0000-000000000003', 'Beta Testers', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0009-000000000005', '00000000-0000-0000-0000-000000000003', 'Security Advisories', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0009-000000000006', '00000000-0000-0000-0000-000000000003', 'Weekly Digest Opt-in', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0009-000000000007', '00000000-0000-0000-0000-000000000003', 'Webinar Registrants', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0009-000000000008', '00000000-0000-0000-0000-000000000003', 'Customer Advisory Board', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0009-000000000009', '00000000-0000-0000-0000-000000000003', 'Event Attendees', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0009-000000000010', '00000000-0000-0000-0000-000000000003', 'Inactive Contacts Segment', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- Remaining 50 lists across other orgs
INSERT INTO lists (list_id, organization_id, name, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0009-' || lpad(to_hex(i + 16), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0001-' || lpad(to_hex(((i - 1) % 8) + 1), 12, '0') AS uuid),
    'Mailing List ' || (i + 10),
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 50) AS s(i);

-- 9. SUPPRESSIONS (1,500 total)
-- Dedicated suppression for R18: 'bounced@example.com' in Org 3
-- Exactly 200 suppressions matching the first 200 contacts of List 9 (contacts 5..204 in Org 3)
-- Reserved email for W20: 'suppress-bench@example.com' (omitted from seed)
INSERT INTO suppressions (suppression_id, organization_id, email, reason, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000018', '00000000-0000-0000-0000-000000000003', 'bounced@example.com', 'HARD_BOUNCE', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- 200 suppressions directly matching List 9 contacts (contacts 5 through 204 in Org 3)
INSERT INTO suppressions (suppression_id, organization_id, email, reason, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-000a-' || lpad(to_hex(i), 12, '0') AS uuid),
    '00000000-0000-0000-0000-000000000003',
    CASE WHEN i <= 150 THEN 'john.' || i || '@acme.com' ELSE 'contact.' || i || '@acme.com' END,
    CASE WHEN i % 3 = 0 THEN 'UNSUBSCRIBED' WHEN i % 3 = 1 THEN 'HARD_BOUNCE' ELSE 'COMPLAINT' END,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(5, 204) AS s(i);

-- Remaining 599 suppressions in Org 3 (Total in Org 3 = 800)
INSERT INTO suppressions (suppression_id, organization_id, email, reason, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-000a-' || lpad(to_hex(i), 12, '0') AS uuid),
    '00000000-0000-0000-0000-000000000003',
    'org3.suppressed.' || i || '@example.com',
    CASE WHEN i % 2 = 0 THEN 'HARD_BOUNCE' ELSE 'UNSUBSCRIBED' END,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(205, 803) AS s(i);

-- Remaining 700 suppressions across other orgs
INSERT INTO suppressions (suppression_id, organization_id, email, reason, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-000a-' || lpad(to_hex(i + 803), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0001-' || lpad(to_hex(((i - 1) % 8) + 1), 12, '0') AS uuid),
    'ext.suppressed.' || i || '@example.com',
    'MANUAL',
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 700) AS s(i);

-- 10. TEMPLATES (40 total)
-- Template 10: Dedicated template for R20, R21, W24
-- Template 20: Dedicated fixture for W22 (has ZERO existing versions)
INSERT INTO templates (template_id, organization_id, name, status, draft_blocks, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000003', 'Acme Monthly Newsletter Template', 'PUBLISHED', '[]'::jsonb, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0000-000000000020', '00000000-0000-0000-0000-000000000003', 'Draft Benchmark Template', 'DRAFT', '[]'::jsonb, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-000b-000000000003', '00000000-0000-0000-0000-000000000003', 'Product Updates Template', 'PUBLISHED', '[]'::jsonb, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-000b-000000000004', '00000000-0000-0000-0000-000000000003', 'Onboarding Email Series', 'PUBLISHED', '[]'::jsonb, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-000b-000000000005', '00000000-0000-0000-0000-000000000003', 'Security Advisory Notice', 'ARCHIVED', '[]'::jsonb, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-000b-000000000006', '00000000-0000-0000-0000-000000000003', 'Promotional Discount Offer', 'DRAFT', '[]'::jsonb, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-000b-000000000007', '00000000-0000-0000-0000-000000000003', 'Webinar Invite Layout', 'PUBLISHED', '[]'::jsonb, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-000b-000000000008', '00000000-0000-0000-0000-000000000003', 'Yearly Retrospective Digest', 'DRAFT', '[]'::jsonb, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- Remaining 32 templates across other orgs
INSERT INTO templates (template_id, organization_id, name, status, draft_blocks, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-000b-' || lpad(to_hex(i + 8), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0001-' || lpad(to_hex(((i - 1) % 8) + 1), 12, '0') AS uuid),
    'Tenant Template ' || (i + 8),
    CASE WHEN i % 3 = 0 THEN 'PUBLISHED' WHEN i % 3 = 1 THEN 'DRAFT' ELSE 'ARCHIVED' END,
    '[]'::jsonb,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 32) AS s(i);

-- 11. MAIL_TRANSPORTS (25 total)
-- Dedicated transport for W11: Transport 6 (00000000-0000-0000-0000-000000000006) in Org 3
INSERT INTO mail_transports (transport_id, organization_id, name, transport_type, credentials_encrypted, rate_per_second, daily_limit, is_default, status, last_tested_at, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000003', 'Acme Primary SES', 'SES', 'enc_key_prod_ses_001', 14.000, 50000, true, 'VERIFIED', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-000c-000000000002', '00000000-0000-0000-0000-000000000003', 'Acme Backup Resend', 'RESEND', 'enc_key_backup_resend_002', 5.000, 10000, false, 'VERIFIED', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-000c-000000000003', '00000000-0000-0000-0000-000000000003', 'Acme Staging SMTP', 'SMTP', 'enc_key_staging_smtp_003', 2.000, 2000, false, 'UNVERIFIED', NULL, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- Remaining 22 transports across other orgs
INSERT INTO mail_transports (transport_id, organization_id, name, transport_type, credentials_encrypted, rate_per_second, daily_limit, is_default, status, last_tested_at, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-000c-' || lpad(to_hex(i + 3), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0001-' || lpad(to_hex(((i - 1) % 8) + 1), 12, '0') AS uuid),
    'Mail Transport ' || (i + 3),
    CASE WHEN i % 3 = 0 THEN 'RESEND' WHEN i % 3 = 1 THEN 'SES' ELSE 'SMTP' END,
    'enc_key_generic_' || i,
    5.000,
    10000,
    (i % 3 = 0),
    'VERIFIED',
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 22) AS s(i);

-- 12. AUDIT_LOGS (25,000 total)
-- Org 3 has 13,000 audit logs (ordered by created_at DESC for R29)
INSERT INTO audit_logs (audit_log_id, organization_id, user_id, action, target_type, target_id, metadata, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-000d-' || lpad(to_hex(i), 12, '0') AS uuid),
    '00000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',
    CASE WHEN i % 4 = 0 THEN 'campaign.created' WHEN i % 4 = 1 THEN 'contact.imported' WHEN i % 4 = 2 THEN 'template.published' ELSE 'member.role_changed' END,
    'campaign',
    '00000000-0000-0000-0000-000000000012',
    ('{"batch": ' || i || '}')::jsonb,
    TIMESTAMPTZ '2026-01-01 00:00:00Z' + (i * INTERVAL '1 minute'),
    TIMESTAMPTZ '2026-01-01 00:00:00Z' + (i * INTERVAL '1 minute')
FROM generate_series(1, 13000) AS s(i);

-- Remaining 12,000 audit logs across other orgs
INSERT INTO audit_logs (audit_log_id, organization_id, user_id, action, target_type, target_id, metadata, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-000e-' || lpad(to_hex(i), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0001-' || lpad(to_hex(((i - 1) % 8) + 1), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0002-' || lpad(to_hex(((i - 1) % 248) + 3), 12, '0') AS uuid),
    'resource.updated',
    'general',
    'target_' || i,
    '{}'::jsonb,
    TIMESTAMPTZ '2026-01-01 00:00:00Z' + (i * INTERVAL '2 minutes'),
    TIMESTAMPTZ '2026-01-01 00:00:00Z' + (i * INTERVAL '2 minutes')
FROM generate_series(1, 12000) AS s(i);

-- =====================================================================
-- LEVEL 2: SECOND-DEGREE DEPENDENTS & JUNCTIONS
-- =====================================================================

-- 13. ROLE_PERMISSIONS (150 total)
-- Role 4 receives permissions for R9; 'campaigns:send' is OMITTED for W9
INSERT INTO role_permissions (role_id, permission_code)
VALUES
    ('00000000-0000-0000-0000-000000000004', 'campaigns:read'),
    ('00000000-0000-0000-0000-000000000004', 'templates:read'),
    ('00000000-0000-0000-0000-000000000004', 'contacts:read');

-- System role permissions (Super Admin has all 30 permissions)
INSERT INTO role_permissions (role_id, permission_code)
SELECT '00000000-0000-0000-0004-000000000001', p.permission_code
FROM permissions p;

-- Additional role-permission mappings to total 150 rows
INSERT INTO role_permissions (role_id, permission_code)
SELECT
    r.role_id,
    p.permission_code
FROM generate_series(1, 121) AS s(i)
CROSS JOIN LATERAL (
    SELECT role_id FROM roles ORDER BY role_id LIMIT 1 OFFSET (s.i % 35)
) AS r
CROSS JOIN LATERAL (
    SELECT permission_code FROM permissions ORDER BY permission_code LIMIT 1 OFFSET (s.i % 25)
) AS p
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- 14. MEMBERSHIPS (300 total)
-- User 1 is a member of Org 3 with Role 4 (R4, R6, R7)
-- User 2 has NO membership in Org 3 (dedicated for W6)
INSERT INTO memberships (user_id, organization_id, role_id, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0004-000000000002', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0001-000000000002', '00000000-0000-0000-0004-000000000003', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0004-000000000004', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- Populate Org 3 with 14 more members for R6 (total 15 members in Org 3)
INSERT INTO memberships (user_id, organization_id, role_id, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0002-' || lpad(to_hex(i), 12, '0') AS uuid),
    '00000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0004-000000000004',
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(3, 16) AS s(i);

-- Remaining memberships across other users and orgs to reach 300 total
INSERT INTO memberships (user_id, organization_id, role_id, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0002-' || lpad(to_hex(((i - 17) % 234) + 17), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0001-' || lpad(to_hex((((i - 17) / 234) % 8) + 1), 12, '0') AS uuid),
    '00000000-0000-0000-0004-000000000004',
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(17, 298) AS s(i)
ON CONFLICT (user_id, organization_id) DO NOTHING;

-- 15. CONTACT_CUSTOM_FIELDS (35,000 total)
-- Contact 8 has dedicated fields for R14 and W15 ('company')
-- Contact 99 has dedicated fields (cascades on W16 deletion)
INSERT INTO contact_custom_fields (contact_id, field_key, field_value)
VALUES
    ('00000000-0000-0000-0000-000000000008', 'company', 'Acme Corporation'),
    ('00000000-0000-0000-0000-000000000008', 'job_title', 'Principal Engineer'),
    ('00000000-0000-0000-0000-000000000008', 'account_tier', 'Enterprise Plus'),
    ('00000000-0000-0000-0000-000000000099', 'company', 'Temporary Corp (W16)'),
    ('00000000-0000-0000-0000-000000000099', 'disposable', 'true');

INSERT INTO contact_custom_fields (contact_id, field_key, field_value)
SELECT
    CAST('00000000-0000-0000-0007-' || lpad(to_hex(i), 12, '0') AS uuid),
    CASE WHEN (i % 3) = 0 THEN 'company' WHEN (i % 3) = 1 THEN 'department' ELSE 'location' END,
    'Custom Value ' || i
FROM generate_series(5, 12000) AS s(i);

INSERT INTO contact_custom_fields (contact_id, field_key, field_value)
SELECT
    CAST('00000000-0000-0000-0008-' || lpad(to_hex(i), 12, '0') AS uuid),
    CASE WHEN (i % 2) = 0 THEN 'industry' ELSE 'lead_score' END,
    'Score ' || (i % 100)
FROM generate_series(1, 12000) AS s(i)
ON CONFLICT (contact_id, field_key) DO NOTHING;

-- Additional custom fields to bring total to exactly 35,000
INSERT INTO contact_custom_fields (contact_id, field_key, field_value)
SELECT
    CAST('00000000-0000-0000-0007-' || lpad(to_hex(i), 12, '0') AS uuid),
    'vip_flag',
    'true'
FROM generate_series(5, 11003) AS s(i)
ON CONFLICT (contact_id, field_key) DO NOTHING;

-- 16. LIST_CONTACTS (40,000 total)
-- List 9 holds EXACTLY 5,000 contacts:
--   - Contact 8 (00000000-0000-0000-0000-000000000008)
--   - Contact 97 (00000000-0000-0000-0000-000000000097) [Dedicated for W19 deletion]
--   - Contacts 5..5002 in Org 3 (4,998 contacts)
-- Contact 98 is OMITTED from List 9 [Dedicated for W18 insertion]
-- Contact 99 is assigned to List 2 (proves cascade on W16 without touching List 9)
INSERT INTO list_contacts (list_id, contact_id)
VALUES
    ('00000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000008'),
    ('00000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000097'),
    ('00000000-0000-0000-0009-000000000002', '00000000-0000-0000-0000-000000000099');

-- Remaining 4,998 contacts into List 9 (Total in List 9 = exactly 5,000)
INSERT INTO list_contacts (list_id, contact_id)
SELECT
    '00000000-0000-0000-0000-000000000009',
    CAST('00000000-0000-0000-0007-' || lpad(to_hex(i), 12, '0') AS uuid)
FROM generate_series(5, 5002) AS s(i);

-- Remaining contacts in Org 3 lists (Total Org 3 list memberships = 20,000)
INSERT INTO list_contacts (list_id, contact_id)
SELECT
    CAST('00000000-0000-0000-0009-' || lpad(to_hex(((i % 8) + 2)), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0007-' || lpad(to_hex(i), 12, '0') AS uuid)
FROM generate_series(5, 12000) AS s(i)
ON CONFLICT (list_id, contact_id) DO NOTHING;

-- Further list contacts across Org 3
INSERT INTO list_contacts (list_id, contact_id)
SELECT
    '00000000-0000-0000-0009-000000000010',
    CAST('00000000-0000-0000-0007-' || lpad(to_hex(i), 12, '0') AS uuid)
FROM generate_series(5, 3007) AS s(i)
ON CONFLICT (list_id, contact_id) DO NOTHING;

-- List memberships across external orgs (20,000 rows across lists 11..60)
INSERT INTO list_contacts (list_id, contact_id)
SELECT
    CAST('00000000-0000-0000-0009-' || lpad(to_hex(((i % 50) + 17)), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0008-' || lpad(to_hex(i), 12, '0') AS uuid)
FROM generate_series(1, 13000) AS s(i)
ON CONFLICT (list_id, contact_id) DO NOTHING;

INSERT INTO list_contacts (list_id, contact_id)
SELECT
    CAST('00000000-0000-0000-0009-' || lpad(to_hex((((i + 12) % 50) + 17)), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0008-' || lpad(to_hex(i + 3000), 12, '0') AS uuid)
FROM generate_series(1, 7000) AS s(i)
ON CONFLICT (list_id, contact_id) DO NOTHING;

-- 17. DOMAINS (35 total)
-- Domain 7: Dedicated for R11, W12, W13 (linked to Transport 6 in Org 3)
-- Reserved name for W11: 'mail.acme.com' in Org 3 (omitted from seed)
INSERT INTO domains (domain_id, organization_id, transport_id, domain_name, is_verified, provider_domain_id, dns_records, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000006', 'email.acme.com', false, 'dom_prov_001', '{"spf": "pass", "dkim": "pass"}'::jsonb, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-000f-000000000002', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000006', 'news.acme.com', true, 'dom_prov_002', '{"spf": "pass"}'::jsonb, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-000f-000000000003', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000006', 'corp.acme.com', true, 'dom_prov_003', '{"spf": "pass"}'::jsonb, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- Remaining 32 domains across other orgs
INSERT INTO domains (domain_id, organization_id, transport_id, domain_name, is_verified, provider_domain_id, dns_records, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-000f-' || lpad(to_hex(i + 3), 12, '0') AS uuid),
    CAST('00000000-0000-0000-0001-' || lpad(to_hex(((i - 1) % 8) + 1), 12, '0') AS uuid),
    CAST('00000000-0000-0000-000c-' || lpad(to_hex(((i - 1) % 8) + 4), 12, '0') AS uuid),
    'domain' || i || '.tenant' || (((i - 1) % 8) + 1) || '.org',
    (i % 2 = 0),
    'prov_dom_' || i,
    '{}'::jsonb,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 32) AS s(i);

-- 18. TEMPLATE_VERSIONS (90 total)
-- Version 11: Dedicated version for R22, W23, W25 (under Template 10)
-- Template 20 has ZERO versions seeded (dedicated for W22)
INSERT INTO template_versions (template_version_id, template_id, organization_id, version_number, subject, preview_text, blocks, html, plain_text, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000003', 1, 'November Updates & News', 'Stay informed with Acme', '[{"type":"text","content":"Hello {{first_name}}"}]'::jsonb, '<html><body><h1>Acme Newsletter</h1></body></html>', 'Acme Newsletter Plaintext', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0010-000000000002', '00000000-0000-0000-000b-000000000003', '00000000-0000-0000-0000-000000000003', 1, 'Product Changelog v2.4', 'Exciting features', '[]'::jsonb, '<html>...</html>', 'Plain...', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0010-000000000003', '00000000-0000-0000-000b-000000000004', '00000000-0000-0000-0000-000000000003', 1, 'Welcome to the platform', 'Getting started guide', '[]'::jsonb, '<html>...</html>', 'Plain...', TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- Remaining 87 template versions distributed across templates 3..40 (skipping template 20!)
INSERT INTO template_versions (template_version_id, template_id, organization_id, version_number, subject, preview_text, blocks, html, plain_text, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0010-' || lpad(to_hex(i + 3), 12, '0') AS uuid),
    t.template_id,
    t.organization_id,
    (ROW_NUMBER() OVER (PARTITION BY t.template_id ORDER BY s.i)),
    'Template Version Subject ' || i,
    'Preview snippet ' || i,
    '[]'::jsonb,
    '<html>Template content</html>',
    'Plain text template content',
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 87) AS s(i)
JOIN LATERAL (
    SELECT template_id, organization_id
    FROM templates
    WHERE template_id NOT IN (
        '00000000-0000-0000-000b-000000000003',
        '00000000-0000-0000-000b-000000000004',
        '00000000-0000-0000-0000-000000000010',
        '00000000-0000-0000-0000-000000000020'
    )
    ORDER BY template_id
    OFFSET (s.i % 36)
    LIMIT 1
) AS t ON true;

-- =====================================================================
-- LEVEL 3: SENDER IDENTITIES & TEMPLATE VARIABLES
-- =====================================================================

-- 19. SENDER_IDENTITIES (50 total)
-- Sender 13: Dedicated sender for R12, W25 (00000000-0000-0000-0000-000000000013)
INSERT INTO sender_identities (sender_identity_id, organization_id, domain_id, display_name, from_email, reply_to, is_default, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000007', 'Acme Digest Team', 'news@email.acme.com', 'support@email.acme.com', true, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0011-000000000002', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000007', 'Acme Security Desk', 'security@email.acme.com', 'security@email.acme.com', false, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0011-000000000003', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-000f-000000000002', 'Acme Editorial', 'editor@news.acme.com', 'editor@news.acme.com', false, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- Remaining 47 senders across domains
INSERT INTO sender_identities (sender_identity_id, organization_id, domain_id, display_name, from_email, reply_to, is_default, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0011-' || lpad(to_hex(i + 3), 12, '0') AS uuid),
    d.organization_id,
    d.domain_id,
    'Sender ' || (i + 3),
    'sender.' || (i + 3) || '@' || d.domain_name,
    'reply.' || (i + 3) || '@' || d.domain_name,
    false,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 47) AS s(i)
JOIN LATERAL (
    SELECT domain_id, organization_id, domain_name
    FROM domains
    WHERE domain_id NOT IN ('00000000-0000-0000-0000-000000000007')
    ORDER BY domain_id
    OFFSET (s.i % 34)
    LIMIT 1
) AS d ON true;

-- 20. TEMPLATE_VERSION_VARIABLES (220 total)
-- Version 11 has variables for R22; 'first_name' and 'company' are OMITTED for W23
INSERT INTO template_version_variables (template_version_id, variable_name)
VALUES
    ('00000000-0000-0000-0000-000000000011', 'unsubscribe_url'),
    ('00000000-0000-0000-0000-000000000011', 'member_id');

-- Remaining variables distributed across versions
INSERT INTO template_version_variables (template_version_id, variable_name)
SELECT
    tv.template_version_id,
    v.var_name
FROM (
    SELECT template_version_id
    FROM template_versions
    WHERE template_version_id <> '00000000-0000-0000-0000-000000000011'
    ORDER BY template_version_id
) AS tv
CROSS JOIN LATERAL (
    VALUES ('first_name'), ('last_name'), ('company')
) AS v(var_name)
LIMIT 218;

-- =====================================================================
-- LEVEL 4: CAMPAIGNS
-- =====================================================================

-- 21. CAMPAIGNS (150 total)
-- Campaign 12: Dedicated active campaign for R24, R25, R26, R31, W26, W28, W29 (10,000 recipients)
-- Campaign 15: Dedicated fixture for W27 (targets List 9, has EXACTLY ZERO initial recipients)
INSERT INTO campaigns (campaign_id, organization_id, name, status, priority, template_version_id, sender_identity_id, list_id, created_by_id, scheduled_at, started_at, completed_at, total_recipients, sent_count, delivered_count, bounced_count, failed_count, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000003', 'November Customer Newsletter', 'SENDING', 'NORMAL', '00000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000001', TIMESTAMPTZ '2026-11-15 10:00:00Z', TIMESTAMPTZ '2026-11-15 10:05:00Z', NULL, 10000, 8500, 7500, 500, 500, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z'),
    ('00000000-0000-0000-0000-000000000015', '00000000-0000-0000-0000-000000000003', 'Unqueued Benchmark Campaign', 'DRAFT', 'NORMAL', '00000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000001', NULL, NULL, NULL, 0, 0, 0, 0, 0, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- Further 28 campaigns in Org 3 (Total in Org 3 = 30 campaigns)
INSERT INTO campaigns (campaign_id, organization_id, name, status, priority, template_version_id, sender_identity_id, list_id, created_by_id, scheduled_at, started_at, completed_at, total_recipients, sent_count, delivered_count, bounced_count, failed_count, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0012-' || lpad(to_hex(i), 12, '0') AS uuid),
    '00000000-0000-0000-0000-000000000003',
    'Acme Campaign ' || i,
    CASE WHEN i % 5 = 0 THEN 'COMPLETED' WHEN i % 5 = 1 THEN 'SENDING' WHEN i % 5 = 2 THEN 'SCHEDULED' WHEN i % 5 = 3 THEN 'QUEUED' ELSE 'DRAFT' END,
    CASE WHEN i % 4 = 0 THEN 'URGENT' ELSE 'NORMAL' END,
    '00000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000013',
    CAST('00000000-0000-0000-0009-' || lpad(to_hex(((i % 8) + 2)), 12, '0') AS uuid),
    '00000000-0000-0000-0000-000000000001',
    TIMESTAMPTZ '2026-11-20 09:00:00Z',
    TIMESTAMPTZ '2026-11-20 09:05:00Z',
    TIMESTAMPTZ '2026-11-20 12:00:00Z',
    1000, 950, 900, 30, 20,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 28) AS s(i);

-- Remaining 120 campaigns across other orgs
INSERT INTO campaigns (campaign_id, organization_id, name, status, priority, template_version_id, sender_identity_id, list_id, created_by_id, scheduled_at, started_at, completed_at, total_recipients, sent_count, delivered_count, bounced_count, failed_count, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0013-' || lpad(to_hex(i), 12, '0') AS uuid),
    org.organization_id,
    'Tenant Campaign ' || i,
    CASE WHEN i % 4 = 0 THEN 'COMPLETED' WHEN i % 4 = 1 THEN 'DRAFT' ELSE 'QUEUED' END,
    'NORMAL',
    tv.template_version_id,
    si.sender_identity_id,
    l.list_id,
    NULL,
    NULL, NULL, NULL,
    500, 480, 470, 5, 5,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 120) AS s(i)
JOIN LATERAL (
    SELECT organization_id
    FROM organizations
    WHERE organization_id = CAST(
        '00000000-0000-0000-0001-' || lpad(to_hex(((s.i - 1) % 8) + 1), 12, '0')
        AS uuid
    )
) AS org ON true
JOIN LATERAL (
    SELECT template_version_id, organization_id
    FROM template_versions
    WHERE organization_id = org.organization_id
    ORDER BY template_version_id
    OFFSET ((s.i - 1) / 8) % (
        SELECT count(*) FROM template_versions WHERE organization_id = org.organization_id
    )
    LIMIT 1
) AS tv ON true
JOIN LATERAL (
    SELECT sender_identity_id
    FROM sender_identities
    WHERE organization_id = org.organization_id
    LIMIT 1
) AS si ON true
JOIN LATERAL (
    SELECT list_id
    FROM lists
    WHERE organization_id = org.organization_id
    LIMIT 1
) AS l ON true;

-- =====================================================================
-- LEVEL 5: CAMPAIGN RECIPIENTS
-- =====================================================================

-- 22. CAMPAIGN_RECIPIENTS (60,000 total)
-- Recipient 14: Dedicated fixture for R27, W30, W31, W32, W33, W34
-- Initial status: 'SENT', provider_message_id: 'msg_provider_abc123'
-- Contact 8 is linked to Recipient 14 and receives campaigns for R32
-- Contact 99 has EXACTLY ZERO entries in campaign_recipients (proves W16)
-- Campaign 15 has EXACTLY ZERO entries in campaign_recipients (proves W27)
INSERT INTO campaign_recipients (recipient_id, organization_id, campaign_id, contact_id, email, status, provider_message_id, error, sent_at, delivered_at, bounced_at, opened_at, clicked_at, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000014', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000008', 'contact8@acme.com', 'SENT', 'msg_provider_abc123', NULL, TIMESTAMPTZ '2026-11-15 10:10:00Z', NULL, NULL, NULL, NULL, TIMESTAMPTZ '2026-01-01 00:00:00Z', TIMESTAMPTZ '2026-01-01 00:00:00Z');

-- Provide 3 more campaigns received by Contact 8 for R32 (R32 returns 4 campaigns)
INSERT INTO campaign_recipients (recipient_id, organization_id, campaign_id, contact_id, email, status, provider_message_id, error, sent_at, delivered_at, bounced_at, opened_at, clicked_at, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0014-' || lpad(to_hex(i), 12, '0') AS uuid),
    '00000000-0000-0000-0000-000000000003',
    CAST('00000000-0000-0000-0012-' || lpad(to_hex(i), 12, '0') AS uuid),
    '00000000-0000-0000-0000-000000000008',
    'contact8@acme.com',
    'DELIVERED',
    'msg_prior_' || i,
    NULL,
    TIMESTAMPTZ '2026-10-01 10:00:00Z' + (i * INTERVAL '1 day'),
    TIMESTAMPTZ '2026-10-01 10:02:00Z' + (i * INTERVAL '1 day'),
    NULL,
    TIMESTAMPTZ '2026-10-01 10:15:00Z' + (i * INTERVAL '1 day'),
    NULL,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 3) AS s(i);

-- Campaign 12 has exactly 10,000 recipients:
-- Already inserted: 1 (Recipient 14 in 'SENT' status)
-- Remaining 9,999 to insert:
--   - 500 QUEUED
--   - 999 SENT (so total SENT = 1,000)
--   - 4,000 DELIVERED
--   - 2,500 OPENED
--   - 1,000 CLICKED
--   - 500 BOUNCED
--   - 500 FAILED
INSERT INTO campaign_recipients (recipient_id, organization_id, campaign_id, contact_id, email, status, provider_message_id, error, sent_at, delivered_at, bounced_at, opened_at, clicked_at, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0015-' || lpad(to_hex(i), 12, '0') AS uuid),
    '00000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000012',
    c.contact_id,
    c.email,
    st.stat,
    'msg_c12_' || i,
    CASE WHEN st.stat IN ('BOUNCED', 'FAILED') THEN 'Delivery failure' ELSE NULL END,
    CASE WHEN st.stat <> 'QUEUED' THEN TIMESTAMPTZ '2026-11-15 10:00:00Z' + (i * INTERVAL '1 second') ELSE NULL END,
    CASE WHEN st.stat IN ('DELIVERED', 'OPENED', 'CLICKED') THEN TIMESTAMPTZ '2026-11-15 10:02:00Z' + (i * INTERVAL '1 second') ELSE NULL END,
    CASE WHEN st.stat = 'BOUNCED' THEN TIMESTAMPTZ '2026-11-15 10:05:00Z' + (i * INTERVAL '1 second') ELSE NULL END,
    CASE WHEN st.stat IN ('OPENED', 'CLICKED') THEN TIMESTAMPTZ '2026-11-15 10:15:00Z' + (i * INTERVAL '1 second') ELSE NULL END,
    CASE WHEN st.stat = 'CLICKED' THEN TIMESTAMPTZ '2026-11-15 10:20:00Z' + (i * INTERVAL '1 second') ELSE NULL END,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 9999) AS s(i)
JOIN LATERAL (
    SELECT
        CASE
            WHEN i <= 500  THEN 'QUEUED'
            WHEN i <= 1499 THEN 'SENT'
            WHEN i <= 5499 THEN 'DELIVERED'
            WHEN i <= 7999 THEN 'OPENED'
            WHEN i <= 8999 THEN 'CLICKED'
            WHEN i <= 9499 THEN 'BOUNCED'
            ELSE 'FAILED'
        END AS stat
) AS st ON true
JOIN LATERAL (
    SELECT contact_id, email
    FROM contacts
    WHERE organization_id = '00000000-0000-0000-0000-000000000003'
      AND contact_id NOT IN ('00000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000099')
    ORDER BY contact_id
    OFFSET (i - 1)
    LIMIT 1
) AS c ON true;

-- Remaining recipients across other campaigns in Org 3 (24,996 rows)
INSERT INTO campaign_recipients (recipient_id, organization_id, campaign_id, contact_id, email, status, provider_message_id, error, sent_at, delivered_at, bounced_at, opened_at, clicked_at, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0016-' || lpad(to_hex(i), 12, '0') AS uuid),
    '00000000-0000-0000-0000-000000000003',
    CAST('00000000-0000-0000-0012-' || lpad(to_hex(((i % 28) + 1)), 12, '0') AS uuid),
    c.contact_id,
    c.email,
    'DELIVERED',
    'msg_other_' || i,
    NULL,
    TIMESTAMPTZ '2026-11-20 09:10:00Z',
    TIMESTAMPTZ '2026-11-20 09:12:00Z',
    NULL, NULL, NULL,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 24996) AS s(i)
JOIN LATERAL (
    SELECT contact_id, email
    FROM contacts
    WHERE organization_id = '00000000-0000-0000-0000-000000000003'
      AND contact_id NOT IN ('00000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000099')
    ORDER BY contact_id
    OFFSET ((i * 3) % 11990)
    LIMIT 1
) AS c ON true
ON CONFLICT (organization_id, email, campaign_id) DO NOTHING;

-- Populate remaining recipient rows across other orgs to reach 60,000 total
INSERT INTO campaign_recipients (recipient_id, organization_id, campaign_id, contact_id, email, status, provider_message_id, error, sent_at, delivered_at, bounced_at, opened_at, clicked_at, created_at, updated_at)
SELECT
    CAST('00000000-0000-0000-0017-' || lpad(to_hex(i), 12, '0') AS uuid),
    c.organization_id,
    cmp.campaign_id,
    c.contact_id,
    c.email,
    'DELIVERED',
    'msg_ext_' || i,
    NULL,
    TIMESTAMPTZ '2026-11-20 09:10:00Z',
    TIMESTAMPTZ '2026-11-20 09:12:00Z',
    NULL, NULL, NULL,
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM generate_series(1, 25000) AS s(i)
JOIN LATERAL (
    SELECT contact_id, organization_id, email
    FROM contacts
    WHERE organization_id <> '00000000-0000-0000-0000-000000000003'
    ORDER BY contact_id
    OFFSET (i % 12900)
    LIMIT 1
) AS c ON true
JOIN LATERAL (
    SELECT campaign_id
    FROM campaigns
    WHERE organization_id = c.organization_id
    ORDER BY campaign_id
    OFFSET ((i - 1) / 12900) % (
        SELECT count(*) FROM campaigns WHERE organization_id = c.organization_id
    )
    LIMIT 1
) AS cmp ON true
ON CONFLICT (organization_id, email, campaign_id) DO NOTHING;

-- One final external recipient fills the last unique-key conflict in the
-- generated batch so the declared fixture total is exactly 60,000 rows.
INSERT INTO campaign_recipients (recipient_id, organization_id, campaign_id, contact_id, email, status, provider_message_id, sent_at, delivered_at, created_at, updated_at)
SELECT
    '00000000-0000-0000-0017-0000000061a9',
    c.organization_id,
    cmp.campaign_id,
    c.contact_id,
    c.email,
    'DELIVERED',
    'msg_ext_final',
    TIMESTAMPTZ '2026-11-20 09:10:00Z',
    TIMESTAMPTZ '2026-11-20 09:12:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z',
    TIMESTAMPTZ '2026-01-01 00:00:00Z'
FROM contacts c
JOIN campaigns cmp ON cmp.organization_id = c.organization_id
LEFT JOIN campaign_recipients cr
  ON cr.organization_id = c.organization_id
 AND cr.email = c.email
 AND cr.campaign_id = cmp.campaign_id
WHERE c.organization_id <> '00000000-0000-0000-0000-000000000003'
  AND cr.recipient_id IS NULL
ORDER BY c.contact_id, cmp.campaign_id
LIMIT 1;

COMMIT;

-- Update optimizer statistics immediately after transaction commit
ANALYZE;

-- =====================================================================
-- VALIDATION QUERIES (Read-Only Verification Section)
-- =====================================================================

-- 1. Verify row counts across all 22 tables
SELECT 'organizations'              AS table_name, count(*) AS actual_count, 10    AS expected_count FROM organizations
UNION ALL SELECT 'users'                      , count(*), 250   FROM users
UNION ALL SELECT 'permissions'                , count(*), 30    FROM permissions
UNION ALL SELECT 'roles'                      , count(*), 40    FROM roles
UNION ALL SELECT 'role_permissions'           , count(*), 150   FROM role_permissions
UNION ALL SELECT 'memberships'                , count(*), 300   FROM memberships
UNION ALL SELECT 'refresh_tokens'             , count(*), 500   FROM refresh_tokens
UNION ALL SELECT 'mail_transports'            , count(*), 25    FROM mail_transports
UNION ALL SELECT 'domains'                    , count(*), 35    FROM domains
UNION ALL SELECT 'sender_identities'          , count(*), 50    FROM sender_identities
UNION ALL SELECT 'contacts'                   , count(*), 25000 FROM contacts
UNION ALL SELECT 'contact_custom_fields'      , count(*), 35000 FROM contact_custom_fields
UNION ALL SELECT 'lists'                      , count(*), 60    FROM lists
UNION ALL SELECT 'list_contacts'              , count(*), 40000 FROM list_contacts
UNION ALL SELECT 'suppressions'               , count(*), 1500  FROM suppressions
UNION ALL SELECT 'templates'                  , count(*), 40    FROM templates
UNION ALL SELECT 'template_versions'          , count(*), 90    FROM template_versions
UNION ALL SELECT 'template_version_variables' , count(*), 220   FROM template_version_variables
UNION ALL SELECT 'campaigns'                  , count(*), 150   FROM campaigns
UNION ALL SELECT 'campaign_recipients'        , count(*), 60000 FROM campaign_recipients
UNION ALL SELECT 'webhook_events'             , count(*), 15000 FROM webhook_events
UNION ALL SELECT 'audit_logs'                 , count(*), 25000 FROM audit_logs;

-- 2. Verify deterministic entities exist
SELECT
    (SELECT count(*) FROM users WHERE user_id = '00000000-0000-0000-0000-000000000001' AND email = 'user@example.com') AS user1_exists,
    (SELECT count(*) FROM users WHERE user_id = '00000000-0000-0000-0000-000000000002') AS user2_exists,
    (SELECT count(*) FROM organizations WHERE organization_id = '00000000-0000-0000-0000-000000000003' AND slug = 'acme-corp') AS org3_exists,
    (SELECT count(*) FROM roles WHERE role_id = '00000000-0000-0000-0000-000000000004') AS role4_exists,
    (SELECT count(*) FROM mail_transports WHERE transport_id = '00000000-0000-0000-0000-000000000006') AS transport6_exists,
    (SELECT count(*) FROM domains WHERE domain_id = '00000000-0000-0000-0000-000000000007') AS domain7_exists,
    (SELECT count(*) FROM contacts WHERE contact_id = '00000000-0000-0000-0000-000000000008') AS contact8_exists,
    (SELECT count(*) FROM lists WHERE list_id = '00000000-0000-0000-0000-000000000009') AS list9_exists,
    (SELECT count(*) FROM templates WHERE template_id = '00000000-0000-0000-0000-000000000010') AS template10_exists,
    (SELECT count(*) FROM template_versions WHERE template_version_id = '00000000-0000-0000-0000-000000000011') AS version11_exists,
    (SELECT count(*) FROM campaigns WHERE campaign_id = '00000000-0000-0000-0000-000000000012') AS campaign12_exists,
    (SELECT count(*) FROM sender_identities WHERE sender_identity_id = '00000000-0000-0000-0000-000000000013') AS sender13_exists,
    (SELECT count(*) FROM campaign_recipients WHERE recipient_id = '00000000-0000-0000-0000-000000000014') AS recipient14_exists,
    (SELECT count(*) FROM campaigns WHERE campaign_id = '00000000-0000-0000-0000-000000000015') AS campaign15_exists,
    (SELECT count(*) FROM templates WHERE template_id = '00000000-0000-0000-0000-000000000020') AS template20_exists,
    (SELECT count(*) FROM contacts WHERE contact_id = '00000000-0000-0000-0000-000000000097') AS contact97_exists,
    (SELECT count(*) FROM contacts WHERE contact_id = '00000000-0000-0000-0000-000000000098') AS contact98_exists,
    (SELECT count(*) FROM contacts WHERE contact_id = '00000000-0000-0000-0000-000000000099') AS contact99_exists;

-- 3. Verify reserved WRITE query parameters are absent from initial state
SELECT
    (SELECT count(*) FROM users WHERE email = 'newuser@example.com') AS w1_reserved_free,               -- Expected: 0
    (SELECT count(*) FROM refresh_tokens WHERE token_hash = 'hashed_token') AS w2_reserved_free,        -- Expected: 0
    (SELECT count(*) FROM organizations WHERE slug = 'acme-corp-benchmark') AS w5_reserved_free,        -- Expected: 0
    (SELECT count(*) FROM memberships WHERE user_id = '00000000-0000-0000-0000-000000000002' AND organization_id = '00000000-0000-0000-0000-000000000003') AS w6_reserved_free, -- Expected: 0
    (SELECT count(*) FROM roles WHERE organization_id = '00000000-0000-0000-0000-000000000003' AND name = 'Campaign Manager') AS w8_reserved_free, -- Expected: 0
    (SELECT count(*) FROM role_permissions WHERE role_id = '00000000-0000-0000-0000-000000000004' AND permission_code = 'campaigns:send') AS w9_reserved_free, -- Expected: 0
    (SELECT count(*) FROM domains WHERE organization_id = '00000000-0000-0000-0000-000000000003' AND domain_name = 'mail.acme.com') AS w11_reserved_free, -- Expected: 0
    (SELECT count(*) FROM contacts WHERE organization_id = '00000000-0000-0000-0000-000000000003' AND email = 'john@example.com') AS w14_reserved_free, -- Expected: 0
    (SELECT count(*) FROM list_contacts WHERE list_id = '00000000-0000-0000-0000-000000000009' AND contact_id = '00000000-0000-0000-0000-000000000098') AS w18_reserved_free, -- Expected: 0
    (SELECT count(*) FROM suppressions WHERE organization_id = '00000000-0000-0000-0000-000000000003' AND email = 'suppress-bench@example.com') AS w20_reserved_free, -- Expected: 0
    (SELECT count(*) FROM template_versions WHERE template_id = '00000000-0000-0000-0000-000000000020') AS w22_template20_versions, -- Expected: 0
    (SELECT count(*) FROM template_version_variables WHERE template_version_id = '00000000-0000-0000-0000-000000000011' AND variable_name IN ('first_name', 'company')) AS w23_reserved_free, -- Expected: 0
    (SELECT count(*) FROM webhook_events WHERE provider_event_id = 'evt_resend_w35_bench') AS w35_reserved_free; -- Expected: 0

-- 4. Verify List 9 membership and suppressions distribution
SELECT
    (SELECT count(*) FROM list_contacts WHERE list_id = '00000000-0000-0000-0000-000000000009') AS list9_total_contacts, -- Expected: 5000
    (
        SELECT count(*)
        FROM list_contacts lc
        JOIN contacts c ON c.contact_id = lc.contact_id
        JOIN suppressions s ON s.organization_id = c.organization_id AND s.email = c.email
        WHERE lc.list_id = '00000000-0000-0000-0000-000000000009'
    ) AS list9_suppressed_contacts; -- Expected: 200

-- 5. Verify Campaign 15 starting state and W27 expected insert count
SELECT
    (SELECT count(*) FROM campaign_recipients WHERE campaign_id = '00000000-0000-0000-0000-000000000015') AS campaign15_initial_recipients, -- Expected: 0
    (
        SELECT count(*)
        FROM campaigns c
        JOIN list_contacts lc ON lc.list_id = c.list_id
        JOIN contacts ct      ON ct.contact_id = lc.contact_id
        LEFT JOIN suppressions s ON s.organization_id = c.organization_id AND s.email = ct.email
        WHERE c.campaign_id = '00000000-0000-0000-0000-000000000015'
          AND s.suppression_id IS NULL
    ) AS w27_expected_insert_count; -- Expected: 4800

-- 6. Verify Campaign 12 recipient count and status distribution
SELECT
    count(*) AS c12_total_recipients,                                       -- Expected: 10000
    count(*) FILTER (WHERE status = 'QUEUED')    AS queued_count,            -- Expected: 500
    count(*) FILTER (WHERE status = 'SENT')      AS sent_count,              -- Expected: 1000
    count(*) FILTER (WHERE status = 'DELIVERED') AS delivered_count,         -- Expected: 4000
    count(*) FILTER (WHERE status = 'OPENED')    AS opened_count,            -- Expected: 2500
    count(*) FILTER (WHERE status = 'CLICKED')   AS clicked_count,           -- Expected: 1000
    count(*) FILTER (WHERE status = 'BOUNCED')   AS bounced_count,           -- Expected: 500
    count(*) FILTER (WHERE status = 'FAILED')    AS failed_count             -- Expected: 500
FROM campaign_recipients
WHERE campaign_id = '00000000-0000-0000-0000-000000000012';

-- 7. Verify Recipient 14 baseline state
SELECT recipient_id, campaign_id, status, provider_message_id, sent_at, delivered_at
FROM campaign_recipients
WHERE recipient_id = '00000000-0000-0000-0000-000000000014';
-- Expected: status = 'SENT', provider_message_id = 'msg_provider_abc123', delivered_at IS NULL

-- 8. Verify Contact 99 deletion safety (no recipient rows)
SELECT
    (SELECT count(*) FROM contacts WHERE contact_id = '00000000-0000-0000-0000-000000000099') AS contact99_exists,
    (SELECT count(*) FROM contact_custom_fields WHERE contact_id = '00000000-0000-0000-0000-000000000099') AS contact99_custom_fields,
    (SELECT count(*) FROM list_contacts WHERE contact_id = '00000000-0000-0000-0000-000000000099') AS contact99_list_memberships,
    (SELECT count(*) FROM campaign_recipients WHERE contact_id = '00000000-0000-0000-0000-000000000099') AS contact99_recipient_references; -- Expected: 0

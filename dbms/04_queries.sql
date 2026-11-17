-- Patra: SQL queries used by the application
-- Team T0066
--
-- Every query the Patra mail service executes, translated from the
-- Mongoose model operations to the PostgreSQL relational schema
-- defined in 03_schema.sql.
--
-- Each query is marked READ or WRITE and given an id (R1, R2, … W1, …).
-- JOINs are used where the relational schema replaces embedded documents.

SET search_path TO patra, public;

-- =====================================================================
-- AUTHENTICATION & USER MANAGEMENT
-- =====================================================================

-- R1  -- READ  Login: look up user by email
SELECT user_id, email, name, password_hash, is_platform_admin
FROM users
WHERE email = 'user@example.com';

-- R2  -- READ  Get user profile by ID
SELECT user_id, email, name, avatar_url, is_platform_admin, created_at
FROM users
WHERE user_id = '00000000-0000-0000-0000-000000000001';

-- R3  -- READ  Validate refresh token (check not expired, not revoked)
SELECT rt.refresh_token_id, rt.user_id, rt.expires_at, rt.revoked_at
FROM refresh_tokens rt
WHERE rt.token_hash = 'hashed_token_value'
  AND rt.revoked_at IS NULL
  AND rt.expires_at > now();

-- W1  -- WRITE  Register a new user
INSERT INTO users (email, name, password_hash)
VALUES ('newuser@example.com', 'New User', '$2b$12$hashedpassword');

-- W2  -- WRITE  Issue a refresh token
INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
VALUES ('00000000-0000-0000-0000-000000000001', 'hashed_token', now() + INTERVAL '30 days');

-- W3  -- WRITE  Revoke a refresh token (logout)
UPDATE refresh_tokens
SET revoked_at = now(), updated_at = now()
WHERE refresh_token_id = '00000000-0000-0000-0000-000000000002';

-- W4  -- WRITE  Update user profile
UPDATE users
SET name = 'Updated Name', avatar_url = 'https://cdn.example.com/avatar.png', updated_at = now()
WHERE user_id = '00000000-0000-0000-0000-000000000001';

-- =====================================================================
-- ORGANIZATION & MEMBERSHIP
-- =====================================================================

-- R4  -- READ  List organizations the user belongs to, with their role
SELECT o.organization_id, o.name, o.slug, o.timezone,
       r.name AS role_name, m.created_at AS joined_at
FROM memberships m
JOIN organizations o ON o.organization_id = m.organization_id
JOIN roles r         ON r.role_id = m.role_id
WHERE m.user_id = '00000000-0000-0000-0000-000000000001';

-- R5  -- READ  Get organization by slug
SELECT organization_id, name, slug, timezone, created_at
FROM organizations
WHERE slug = 'acme-corp';

-- R6  -- READ  List members of an organization with roles
SELECT u.user_id, u.email, u.name, u.avatar_url,
       r.name AS role_name, r.role_id, m.created_at AS joined_at
FROM memberships m
JOIN users u ON u.user_id = m.user_id
JOIN roles r ON r.role_id = m.role_id
WHERE m.organization_id = '00000000-0000-0000-0000-000000000003';

-- R7  -- READ  Get user permissions in an organization (role → permissions)
SELECT p.permission_code
FROM memberships m
JOIN role_permissions rp ON rp.role_id = m.role_id
JOIN permissions p       ON p.permission_code = rp.permission_code
WHERE m.user_id = '00000000-0000-0000-0000-000000000001'
  AND m.organization_id = '00000000-0000-0000-0000-000000000003';

-- W5  -- WRITE  Create a new organization
INSERT INTO organizations (name, slug, timezone)
VALUES ('Acme Corp', 'acme-corp', 'Asia/Kolkata');

-- W6  -- WRITE  Add a member to an organization with a role
INSERT INTO memberships (user_id, organization_id, role_id)
VALUES ('00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-000000000004');

-- W7  -- WRITE  Change a member's role
UPDATE memberships
SET role_id = '00000000-0000-0000-0000-000000000005', updated_at = now()
WHERE user_id = '00000000-0000-0000-0000-000000000001'
  AND organization_id = '00000000-0000-0000-0000-000000000003';

-- =====================================================================
-- ROLES & PERMISSIONS
-- =====================================================================

-- R8  -- READ  List all roles in an organization (including global roles)
SELECT role_id, name, description, is_system
FROM roles
WHERE organization_id = '00000000-0000-0000-0000-000000000003'
   OR organization_id IS NULL
ORDER BY is_system DESC, name;

-- R9  -- READ  Get permissions assigned to a role
SELECT rp.permission_code
FROM role_permissions rp
WHERE rp.role_id = '00000000-0000-0000-0000-000000000004';

-- W8  -- WRITE  Create a custom role
INSERT INTO roles (organization_id, name, description)
VALUES ('00000000-0000-0000-0000-000000000003', 'Campaign Manager', 'Can create and send campaigns');

-- W9  -- WRITE  Assign a permission to a role
INSERT INTO role_permissions (role_id, permission_code)
VALUES ('00000000-0000-0000-0000-000000000004', 'campaigns:send');

-- =====================================================================
-- MAIL TRANSPORTS & DOMAINS
-- =====================================================================

-- R10  -- READ  List mail transports for an organization
SELECT transport_id, name, transport_type, rate_per_second, daily_limit,
       is_default, status, last_tested_at
FROM mail_transports
WHERE organization_id = '00000000-0000-0000-0000-000000000003'
ORDER BY is_default DESC, name;

-- R11  -- READ  List verified domains for an organization with their transport
SELECT d.domain_id, d.domain_name, d.is_verified, d.dns_records,
       mt.name AS transport_name, mt.transport_type
FROM domains d
JOIN mail_transports mt ON mt.transport_id = d.transport_id
WHERE d.organization_id = '00000000-0000-0000-0000-000000000003'
ORDER BY d.domain_name;

-- W10  -- WRITE  Add a mail transport
INSERT INTO mail_transports (organization_id, name, transport_type, credentials_encrypted)
VALUES ('00000000-0000-0000-0000-000000000003', 'Primary Resend', 'RESEND', 'encrypted_api_key');

-- W11  -- WRITE  Add a domain linked to a transport
INSERT INTO domains (organization_id, transport_id, domain_name)
VALUES ('00000000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-000000000006',
        'mail.acme.com');

-- W12  -- WRITE  Mark a domain as verified
UPDATE domains
SET is_verified = true, updated_at = now()
WHERE domain_id = '00000000-0000-0000-0000-000000000007';

-- =====================================================================
-- SENDER IDENTITIES
-- =====================================================================

-- R12  -- READ  List sender identities for an organization
SELECT si.sender_identity_id, si.display_name, si.from_email, si.reply_to,
       si.is_default, d.domain_name
FROM sender_identities si
JOIN domains d ON d.domain_id = si.domain_id
WHERE si.organization_id = '00000000-0000-0000-0000-000000000003'
ORDER BY si.is_default DESC, si.display_name;

-- W13  -- WRITE  Create a sender identity
INSERT INTO sender_identities (organization_id, domain_id, display_name, from_email, reply_to)
VALUES ('00000000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-000000000007',
        'Acme Newsletters', 'news@mail.acme.com', 'support@acme.com');

-- =====================================================================
-- CONTACTS & CUSTOM FIELDS
-- =====================================================================

-- R13  -- READ  List contacts for an organization (paginated)
SELECT c.contact_id, c.email, c.name, c.created_at
FROM contacts c
WHERE c.organization_id = '00000000-0000-0000-0000-000000000003'
ORDER BY c.created_at DESC
LIMIT 50 OFFSET 0;

-- R14  -- READ  Get a contact with all custom fields
SELECT c.contact_id, c.email, c.name, c.created_at,
       cf.field_key, cf.field_value
FROM contacts c
LEFT JOIN contact_custom_fields cf ON cf.contact_id = c.contact_id
WHERE c.contact_id = '00000000-0000-0000-0000-000000000008';

-- R15  -- READ  Search contacts by email (prefix match)
SELECT contact_id, email, name
FROM contacts
WHERE organization_id = '00000000-0000-0000-0000-000000000003'
  AND email LIKE 'john%'
ORDER BY email
LIMIT 20;

-- W14  -- WRITE  Create a contact
INSERT INTO contacts (organization_id, email, name)
VALUES ('00000000-0000-0000-0000-000000000003', 'john@example.com', 'John Doe');

-- W15  -- WRITE  Upsert a custom field on a contact
INSERT INTO contact_custom_fields (contact_id, field_key, field_value)
VALUES ('00000000-0000-0000-0000-000000000008', 'company', 'Acme Inc')
ON CONFLICT (contact_id, field_key) DO UPDATE SET field_value = EXCLUDED.field_value;

-- W16  -- WRITE  Delete a contact (cascades to custom fields, list memberships, recipients)
DELETE FROM contacts
WHERE contact_id = '00000000-0000-0000-0000-000000000008';

-- =====================================================================
-- LISTS & LIST CONTACTS
-- =====================================================================

-- R16  -- READ  List all mailing lists for an organization with contact counts
SELECT l.list_id, l.name, l.created_at,
       count(lc.contact_id) AS contact_count
FROM lists l
LEFT JOIN list_contacts lc ON lc.list_id = l.list_id
WHERE l.organization_id = '00000000-0000-0000-0000-000000000003'
GROUP BY l.list_id, l.name, l.created_at
ORDER BY l.name;

-- R17  -- READ  Get contacts in a specific list (paginated)
SELECT c.contact_id, c.email, c.name
FROM list_contacts lc
JOIN contacts c ON c.contact_id = lc.contact_id
WHERE lc.list_id = '00000000-0000-0000-0000-000000000009'
ORDER BY c.email
LIMIT 50 OFFSET 0;

-- W17  -- WRITE  Create a mailing list
INSERT INTO lists (organization_id, name)
VALUES ('00000000-0000-0000-0000-000000000003', 'Newsletter Subscribers');

-- W18  -- WRITE  Add a contact to a list
INSERT INTO list_contacts (list_id, contact_id)
VALUES ('00000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000008');

-- W19  -- WRITE  Remove a contact from a list
DELETE FROM list_contacts
WHERE list_id = '00000000-0000-0000-0000-000000000009'
  AND contact_id = '00000000-0000-0000-0000-000000000008';

-- =====================================================================
-- SUPPRESSIONS
-- =====================================================================

-- R18  -- READ  Check if an email is suppressed in an organization
SELECT suppression_id, email, reason, created_at
FROM suppressions
WHERE organization_id = '00000000-0000-0000-0000-000000000003'
  AND email = 'bounced@example.com';

-- R19  -- READ  List all suppressions for an organization
SELECT suppression_id, email, reason, created_at
FROM suppressions
WHERE organization_id = '00000000-0000-0000-0000-000000000003'
ORDER BY created_at DESC;

-- W20  -- WRITE  Add a suppression (e.g. from a bounce or unsubscribe)
INSERT INTO suppressions (organization_id, email, reason)
VALUES ('00000000-0000-0000-0000-000000000003', 'bounced@example.com', 'HARD_BOUNCE')
ON CONFLICT (organization_id, email) DO NOTHING;

-- =====================================================================
-- TEMPLATES & VERSIONS
-- =====================================================================

-- R20  -- READ  List templates for an organization
SELECT template_id, name, status, created_at, updated_at
FROM templates
WHERE organization_id = '00000000-0000-0000-0000-000000000003'
ORDER BY updated_at DESC;

-- R21  -- READ  Get latest published template version for a template
SELECT tv.template_version_id, tv.version_number, tv.subject,
       tv.preview_text, tv.html, tv.plain_text, tv.blocks
FROM template_versions tv
WHERE tv.template_id = '00000000-0000-0000-0000-000000000010'
ORDER BY tv.version_number DESC
LIMIT 1;

-- R22  -- READ  Get template variables for campaign variable validation
SELECT tvv.variable_name
FROM template_version_variables tvv
WHERE tvv.template_version_id = '00000000-0000-0000-0000-000000000011';

-- W21  -- WRITE  Create a new template
INSERT INTO templates (organization_id, name, status)
VALUES ('00000000-0000-0000-0000-000000000003', 'Weekly Digest', 'DRAFT');

-- W22  -- WRITE  Publish a template version (creates an immutable snapshot)
INSERT INTO template_versions
    (template_id, organization_id, version_number, subject, preview_text, blocks, html, plain_text)
VALUES ('00000000-0000-0000-0000-000000000010',
        '00000000-0000-0000-0000-000000000003',
        1,
        'Your Weekly Digest',
        'This week at Acme',
        '[]'::jsonb,
        '<html>...</html>',
        'Plain text version');

-- W23  -- WRITE  Record template variables for a published version
INSERT INTO template_version_variables (template_version_id, variable_name)
VALUES ('00000000-0000-0000-0000-000000000011', 'first_name'),
       ('00000000-0000-0000-0000-000000000011', 'company');

-- W24  -- WRITE  Update template status (DRAFT → PUBLISHED → ARCHIVED)
UPDATE templates
SET status = 'PUBLISHED', updated_at = now()
WHERE template_id = '00000000-0000-0000-0000-000000000010';

-- =====================================================================
-- CAMPAIGNS
-- =====================================================================

-- R23  -- READ  List campaigns for an organization with sender and template info
SELECT c.campaign_id, c.name, c.status, c.priority,
       c.scheduled_at, c.started_at, c.completed_at,
       c.total_recipients, c.sent_count, c.delivered_count,
       c.bounced_count, c.failed_count,
       si.display_name AS sender_name, si.from_email,
       tv.subject AS template_subject,
       l.name AS list_name
FROM campaigns c
JOIN sender_identities si  ON si.sender_identity_id = c.sender_identity_id
JOIN template_versions tv  ON tv.template_version_id = c.template_version_id
JOIN lists l               ON l.list_id = c.list_id
WHERE c.organization_id = '00000000-0000-0000-0000-000000000003'
ORDER BY c.created_at DESC;

-- R24  -- READ  Get campaign details by ID (full data for campaign view)
SELECT c.campaign_id, c.name, c.status, c.priority,
       c.scheduled_at, c.started_at, c.completed_at,
       c.total_recipients, c.sent_count, c.delivered_count,
       c.bounced_count, c.failed_count,
       c.created_at, c.updated_at,
       si.display_name AS sender_name, si.from_email, si.reply_to,
       tv.subject, tv.preview_text, tv.html,
       l.name AS list_name,
       u.name AS created_by_name
FROM campaigns c
JOIN sender_identities si  ON si.sender_identity_id = c.sender_identity_id
JOIN template_versions tv  ON tv.template_version_id = c.template_version_id
JOIN lists l               ON l.list_id = c.list_id
LEFT JOIN users u          ON u.user_id = c.created_by_id
WHERE c.campaign_id = '00000000-0000-0000-0000-000000000012';

-- R25  -- READ  Campaign analytics: delivery breakdown
SELECT status, count(*) AS recipient_count
FROM campaign_recipients
WHERE campaign_id = '00000000-0000-0000-0000-000000000012'
GROUP BY status
ORDER BY recipient_count DESC;

-- W25  -- WRITE  Create a campaign
INSERT INTO campaigns
    (organization_id, name, template_version_id, sender_identity_id, list_id, created_by_id)
VALUES ('00000000-0000-0000-0000-000000000003',
        'November Newsletter',
        '00000000-0000-0000-0000-000000000011',
        '00000000-0000-0000-0000-000000000013',
        '00000000-0000-0000-0000-000000000009',
        '00000000-0000-0000-0000-000000000001');

-- W26  -- WRITE  Schedule a campaign
UPDATE campaigns
SET status = 'SCHEDULED',
    scheduled_at = '2026-11-20 09:00:00+05:30',
    updated_at = now()
WHERE campaign_id = '00000000-0000-0000-0000-000000000012';

-- W27  -- WRITE  Queue campaign recipients (from list contacts, skipping suppressed)
INSERT INTO campaign_recipients (organization_id, campaign_id, contact_id, email)
SELECT c.organization_id, c.campaign_id, ct.contact_id, ct.email
FROM campaigns c
JOIN list_contacts lc ON lc.list_id = c.list_id
JOIN contacts ct      ON ct.contact_id = lc.contact_id
LEFT JOIN suppressions s ON s.organization_id = c.organization_id
                        AND s.email = ct.email
WHERE c.campaign_id = '00000000-0000-0000-0000-000000000012'
  AND s.suppression_id IS NULL;

-- W28  -- WRITE  Update campaign counters after sending
UPDATE campaigns
SET total_recipients = (SELECT count(*) FROM campaign_recipients WHERE campaign_id = campaigns.campaign_id),
    sent_count = (SELECT count(*) FROM campaign_recipients WHERE campaign_id = campaigns.campaign_id AND status IN ('SENT', 'DELIVERED', 'OPENED', 'CLICKED')),
    delivered_count = (SELECT count(*) FROM campaign_recipients WHERE campaign_id = campaigns.campaign_id AND status IN ('DELIVERED', 'OPENED', 'CLICKED')),
    bounced_count = (SELECT count(*) FROM campaign_recipients WHERE campaign_id = campaigns.campaign_id AND status = 'BOUNCED'),
    failed_count = (SELECT count(*) FROM campaign_recipients WHERE campaign_id = campaigns.campaign_id AND status = 'FAILED'),
    updated_at = now()
WHERE campaign_id = '00000000-0000-0000-0000-000000000012';

-- W29  -- WRITE  Mark campaign as completed
UPDATE campaigns
SET status = 'COMPLETED', completed_at = now(), updated_at = now()
WHERE campaign_id = '00000000-0000-0000-0000-000000000012';

-- =====================================================================
-- CAMPAIGN RECIPIENTS (send worker & webhooks)
-- =====================================================================

-- R26  -- READ  Fetch next batch of queued recipients to send
SELECT cr.recipient_id, cr.email, cr.contact_id
FROM campaign_recipients cr
WHERE cr.campaign_id = '00000000-0000-0000-0000-000000000012'
  AND cr.status = 'QUEUED'
ORDER BY cr.created_at
LIMIT 100;

-- R27  -- READ  Look up recipient by provider message ID (for webhook processing)
SELECT cr.recipient_id, cr.campaign_id, cr.contact_id, cr.email, cr.status
FROM campaign_recipients cr
WHERE cr.provider_message_id = 'msg_provider_abc123';

-- W30  -- WRITE  Mark a recipient as sent
UPDATE campaign_recipients
SET status = 'SENT',
    provider_message_id = 'msg_provider_abc123',
    sent_at = now(),
    updated_at = now()
WHERE recipient_id = '00000000-0000-0000-0000-000000000014';

-- W31  -- WRITE  Mark a recipient as delivered (webhook)
UPDATE campaign_recipients
SET status = 'DELIVERED', delivered_at = now(), updated_at = now()
WHERE provider_message_id = 'msg_provider_abc123';

-- W32  -- WRITE  Mark a recipient as bounced (webhook + auto-suppress)
UPDATE campaign_recipients
SET status = 'BOUNCED', bounced_at = now(), error = 'Mailbox not found', updated_at = now()
WHERE provider_message_id = 'msg_provider_abc123';

-- W33  -- WRITE  Record an open event (webhook)
UPDATE campaign_recipients
SET status = 'OPENED', opened_at = COALESCE(opened_at, now()), updated_at = now()
WHERE provider_message_id = 'msg_provider_abc123'
  AND status NOT IN ('BOUNCED', 'FAILED', 'COMPLAINED');

-- W34  -- WRITE  Record a click event (webhook)
UPDATE campaign_recipients
SET status = 'CLICKED', clicked_at = COALESCE(clicked_at, now()), updated_at = now()
WHERE provider_message_id = 'msg_provider_abc123'
  AND status NOT IN ('BOUNCED', 'FAILED', 'COMPLAINED');

-- =====================================================================
-- WEBHOOK EVENTS (idempotent ingestion)
-- =====================================================================

-- R28  -- READ  Check if a webhook event was already processed (deduplication)
SELECT webhook_event_id
FROM webhook_events
WHERE provider_event_id = 'evt_resend_xyz789';

-- W35  -- WRITE  Record an incoming webhook event
INSERT INTO webhook_events (provider, provider_event_id, event_type, payload)
VALUES ('RESEND', 'evt_resend_xyz789', 'email.delivered', '{"email": "john@example.com"}'::jsonb)
ON CONFLICT (provider_event_id) DO NOTHING;

-- =====================================================================
-- AUDIT LOGS
-- =====================================================================

-- R29  -- READ  List audit logs for an organization (paginated, newest first)
SELECT al.audit_log_id, al.action, al.target_type, al.target_id,
       al.metadata, al.created_at,
       u.name AS user_name, u.email AS user_email
FROM audit_logs al
LEFT JOIN users u ON u.user_id = al.user_id
WHERE al.organization_id = '00000000-0000-0000-0000-000000000003'
ORDER BY al.created_at DESC
LIMIT 50 OFFSET 0;

-- W36  -- WRITE  Create an audit log entry
INSERT INTO audit_logs (organization_id, user_id, action, target_type, target_id, metadata)
VALUES ('00000000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-000000000001',
        'campaign.created',
        'campaign',
        '00000000-0000-0000-0000-000000000012',
        '{"name": "November Newsletter"}'::jsonb);

-- =====================================================================
-- DASHBOARD & ANALYTICS
-- =====================================================================

-- R30  -- READ  Organization dashboard: campaign summary stats
SELECT count(*) AS total_campaigns,
       count(*) FILTER (WHERE status = 'COMPLETED') AS completed,
       count(*) FILTER (WHERE status = 'SENDING')   AS active,
       count(*) FILTER (WHERE status = 'SCHEDULED')  AS scheduled,
       sum(sent_count)      AS total_sent,
       sum(delivered_count) AS total_delivered,
       sum(bounced_count)   AS total_bounced
FROM campaigns
WHERE organization_id = '00000000-0000-0000-0000-000000000003';

-- R31  -- READ  Campaign recipient timeline: recent events
SELECT cr.email, cr.status, cr.sent_at, cr.delivered_at,
       cr.opened_at, cr.clicked_at, cr.bounced_at
FROM campaign_recipients cr
WHERE cr.campaign_id = '00000000-0000-0000-0000-000000000012'
ORDER BY GREATEST(cr.sent_at, cr.delivered_at, cr.opened_at, cr.clicked_at, cr.bounced_at) DESC NULLS LAST
LIMIT 20;

-- R32  -- READ  Contact engagement: campaigns a contact has received
SELECT c.campaign_id, ca.name AS campaign_name, c.status,
       c.sent_at, c.opened_at, c.clicked_at
FROM campaign_recipients c
JOIN campaigns ca ON ca.campaign_id = c.campaign_id
WHERE c.contact_id = '00000000-0000-0000-0000-000000000008'
ORDER BY c.created_at DESC;

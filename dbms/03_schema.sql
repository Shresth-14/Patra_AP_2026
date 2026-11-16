-- Patra relational schema for PostgreSQL 15+
-- Derived from the current Mongoose models in apps/server/src/models.
-- Mongo ObjectIds map to UUIDs in this PostgreSQL design.
-- No performance indexes are created here; PK/UNIQUE constraints create only
-- their required backing indexes. Composite tenant FKs protect linked assets,
-- campaigns, and recipients. The application checks role/list tenant scope
-- and updates updated_at values.
-- organization_id on domains, sender_identities, template_versions, campaigns,
-- and campaign_recipients is the documented tenant-query copy from CP1.
-- sender_identities.transport_id is intentionally omitted; resolve it through
-- domains. The sender From-address/domain match is an application rule.

CREATE SCHEMA IF NOT EXISTS patra;
SET search_path TO patra, public;

CREATE TABLE organizations (
    organization_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name            text NOT NULL,
    slug            varchar(80) NOT NULL,
    timezone        varchar(64) NOT NULL DEFAULT 'UTC',
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_organizations_slug UNIQUE (slug),
    CONSTRAINT ck_organizations_name CHECK (btrim(name) <> ''),
    CONSTRAINT ck_organizations_slug CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT ck_organizations_timezone CHECK (btrim(timezone) <> '')
);

CREATE TABLE users (
    user_id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email               varchar(254) NOT NULL,
    name                text,
    password_hash       text NOT NULL,
    avatar_url          text NOT NULL DEFAULT '',
    is_platform_admin   boolean NOT NULL DEFAULT false,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT ck_users_email_normalized CHECK (
        email = lower(btrim(email))
        AND email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    ),
    CONSTRAINT ck_users_name CHECK (name IS NULL OR btrim(name) <> '')
);

CREATE TABLE permissions (
    permission_code varchar(100) PRIMARY KEY,
    CONSTRAINT ck_permissions_code CHECK (btrim(permission_code) <> '')
);

CREATE TABLE roles (
    role_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid REFERENCES organizations (organization_id) ON DELETE CASCADE,
    name            varchar(80) NOT NULL,
    description     text,
    is_system       boolean NOT NULL DEFAULT false,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_roles_org_name UNIQUE NULLS NOT DISTINCT (organization_id, name),
    CONSTRAINT ck_roles_name CHECK (btrim(name) <> ''),
    CONSTRAINT ck_roles_description CHECK (description IS NULL OR btrim(description) <> '')
);

CREATE TABLE role_permissions (
    role_id         uuid NOT NULL REFERENCES roles (role_id) ON DELETE CASCADE,
    permission_code varchar(100) NOT NULL REFERENCES permissions (permission_code) ON DELETE RESTRICT,
    PRIMARY KEY (role_id, permission_code)
);

CREATE TABLE memberships (
    user_id         uuid NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
    organization_id uuid NOT NULL REFERENCES organizations (organization_id) ON DELETE CASCADE,
    role_id         uuid NOT NULL REFERENCES roles (role_id) ON DELETE RESTRICT,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, organization_id)
);
-- The application must ensure that an organization-scoped role belongs to
-- this membership's organization; global roles (organization_id IS NULL) may
-- be assigned to any organization.

CREATE TABLE refresh_tokens (
    refresh_token_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          uuid NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
    token_hash       text NOT NULL,
    expires_at       timestamptz NOT NULL,
    revoked_at       timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_refresh_tokens_hash UNIQUE (token_hash),
    CONSTRAINT ck_refresh_tokens_hash CHECK (btrim(token_hash) <> '')
);

CREATE TABLE mail_transports (
    transport_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id      uuid NOT NULL REFERENCES organizations (organization_id) ON DELETE CASCADE,
    name                 varchar(100) NOT NULL,
    transport_type       varchar(16) NOT NULL,
    credentials_encrypted text NOT NULL,
    rate_per_second      numeric(10, 3) NOT NULL DEFAULT 2,
    daily_limit          integer,
    is_default           boolean NOT NULL DEFAULT false,
    status               varchar(16) NOT NULL DEFAULT 'UNVERIFIED',
    last_tested_at       timestamptz,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_mail_transports_id_org UNIQUE (transport_id, organization_id),
    CONSTRAINT ck_mail_transports_name CHECK (btrim(name) <> ''),
    CONSTRAINT ck_mail_transports_type CHECK (transport_type IN ('RESEND', 'SMTP', 'SES')),
    CONSTRAINT ck_mail_transports_credentials CHECK (btrim(credentials_encrypted) <> ''),
    CONSTRAINT ck_mail_transports_rate CHECK (rate_per_second > 0),
    CONSTRAINT ck_mail_transports_daily_limit CHECK (daily_limit IS NULL OR daily_limit > 0),
    CONSTRAINT ck_mail_transports_status CHECK (status IN ('UNVERIFIED', 'VERIFIED', 'FAILED'))
);

CREATE TABLE domains (
    domain_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id    uuid NOT NULL REFERENCES organizations (organization_id) ON DELETE CASCADE,
    transport_id       uuid NOT NULL,
    domain_name        varchar(253) NOT NULL,
    is_verified        boolean NOT NULL DEFAULT false,
    provider_domain_id text,
    dns_records        jsonb,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_domains_org_name UNIQUE (organization_id, domain_name),
    CONSTRAINT uq_domains_id_org UNIQUE (domain_id, organization_id),
    CONSTRAINT fk_domains_transport_org FOREIGN KEY (transport_id, organization_id)
        REFERENCES mail_transports (transport_id, organization_id) ON DELETE CASCADE,
    CONSTRAINT ck_domains_name CHECK (
        domain_name = lower(btrim(domain_name))
        AND domain_name ~ '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$'
    )
);

CREATE TABLE sender_identities (
    sender_identity_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id    uuid NOT NULL REFERENCES organizations (organization_id) ON DELETE CASCADE,
    domain_id          uuid NOT NULL,
    display_name       varchar(150) NOT NULL,
    from_email         varchar(254) NOT NULL,
    reply_to           varchar(254),
    is_default         boolean NOT NULL DEFAULT false,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_sender_identities_id_org UNIQUE (sender_identity_id, organization_id),
    CONSTRAINT fk_sender_identities_domain_org FOREIGN KEY (domain_id, organization_id)
        REFERENCES domains (domain_id, organization_id) ON DELETE CASCADE,
    CONSTRAINT ck_sender_identities_display_name CHECK (btrim(display_name) <> ''),
    CONSTRAINT ck_sender_identities_from_email CHECK (
        from_email = lower(btrim(from_email))
        AND from_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    ),
    CONSTRAINT ck_sender_identities_reply_to CHECK (
        reply_to IS NULL OR (
            reply_to = lower(btrim(reply_to))
            AND reply_to ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
        )
    )
);

CREATE TABLE contacts (
    contact_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations (organization_id) ON DELETE CASCADE,
    email           varchar(254) NOT NULL,
    name            text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_contacts_org_email UNIQUE (organization_id, email),
    CONSTRAINT uq_contacts_id_org UNIQUE (contact_id, organization_id),
    CONSTRAINT ck_contacts_email CHECK (
        email = lower(btrim(email))
        AND email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    ),
    CONSTRAINT ck_contacts_name CHECK (name IS NULL OR btrim(name) <> '')
);

CREATE TABLE contact_custom_fields (
    contact_id  uuid NOT NULL REFERENCES contacts (contact_id) ON DELETE CASCADE,
    field_key   varchar(150) NOT NULL,
    field_value text NOT NULL,
    PRIMARY KEY (contact_id, field_key),
    CONSTRAINT ck_contact_custom_fields_key CHECK (btrim(field_key) <> '')
);

CREATE TABLE lists (
    list_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations (organization_id) ON DELETE CASCADE,
    name            varchar(150) NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_lists_id_org UNIQUE (list_id, organization_id),
    CONSTRAINT ck_lists_name CHECK (btrim(name) <> '')
);

CREATE TABLE list_contacts (
    list_id    uuid NOT NULL REFERENCES lists (list_id) ON DELETE CASCADE,
    contact_id uuid NOT NULL REFERENCES contacts (contact_id) ON DELETE CASCADE,
    PRIMARY KEY (list_id, contact_id)
);
-- Before inserting, the application must verify that list and contact belong
-- to the same organization. Keeping organization_id out of this junction
-- avoids storing a value derivable from list_id/contact_id.

CREATE TABLE suppressions (
    suppression_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations (organization_id) ON DELETE CASCADE,
    email           varchar(254) NOT NULL,
    reason          varchar(20) NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_suppressions_org_email UNIQUE (organization_id, email),
    CONSTRAINT ck_suppressions_email CHECK (
        email = lower(btrim(email))
        AND email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    ),
    CONSTRAINT ck_suppressions_reason CHECK (reason IN ('UNSUBSCRIBED', 'HARD_BOUNCE', 'COMPLAINT', 'MANUAL'))
);

CREATE TABLE templates (
    template_id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations (organization_id) ON DELETE CASCADE,
    name            varchar(150) NOT NULL,
    status          varchar(16) NOT NULL DEFAULT 'DRAFT',
    draft_blocks    jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_templates_id_org UNIQUE (template_id, organization_id),
    CONSTRAINT ck_templates_name CHECK (btrim(name) <> ''),
    CONSTRAINT ck_templates_status CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED'))
);

CREATE TABLE template_versions (
    template_version_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id         uuid NOT NULL,
    organization_id     uuid NOT NULL,
    version_number      integer NOT NULL,
    subject             text NOT NULL,
    preview_text        text,
    blocks              jsonb NOT NULL,
    html                text NOT NULL,
    plain_text          text NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_template_versions_template_version UNIQUE (template_id, version_number),
    CONSTRAINT uq_template_versions_id_org UNIQUE (template_version_id, organization_id),
    CONSTRAINT fk_template_versions_template_org FOREIGN KEY (template_id, organization_id)
        REFERENCES templates (template_id, organization_id) ON DELETE CASCADE,
    CONSTRAINT ck_template_versions_version CHECK (version_number >= 1),
    CONSTRAINT ck_template_versions_subject CHECK (btrim(subject) <> '')
);

CREATE TABLE template_version_variables (
    template_version_id uuid NOT NULL REFERENCES template_versions (template_version_id) ON DELETE CASCADE,
    variable_name       varchar(150) NOT NULL,
    PRIMARY KEY (template_version_id, variable_name),
    CONSTRAINT ck_template_version_variables_name CHECK (btrim(variable_name) <> '')
);

CREATE TABLE campaigns (
    campaign_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     uuid NOT NULL REFERENCES organizations (organization_id) ON DELETE CASCADE,
    name                varchar(150) NOT NULL,
    status              varchar(16) NOT NULL DEFAULT 'DRAFT',
    priority            varchar(10) NOT NULL DEFAULT 'NORMAL',
    template_version_id uuid NOT NULL,
    sender_identity_id  uuid NOT NULL,
    list_id             uuid NOT NULL,
    created_by_id       uuid REFERENCES users (user_id) ON DELETE SET NULL,
    scheduled_at        timestamptz,
    started_at          timestamptz,
    completed_at        timestamptz,
    total_recipients    integer NOT NULL DEFAULT 0,
    sent_count          integer NOT NULL DEFAULT 0,
    delivered_count     integer NOT NULL DEFAULT 0,
    bounced_count       integer NOT NULL DEFAULT 0,
    failed_count        integer NOT NULL DEFAULT 0,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_campaigns_id_org UNIQUE (campaign_id, organization_id),
    CONSTRAINT fk_campaigns_template_version_org FOREIGN KEY (template_version_id, organization_id)
        REFERENCES template_versions (template_version_id, organization_id) ON DELETE RESTRICT,
    CONSTRAINT fk_campaigns_sender_org FOREIGN KEY (sender_identity_id, organization_id)
        REFERENCES sender_identities (sender_identity_id, organization_id) ON DELETE RESTRICT,
    CONSTRAINT fk_campaigns_list_org FOREIGN KEY (list_id, organization_id)
        REFERENCES lists (list_id, organization_id) ON DELETE RESTRICT,
    CONSTRAINT ck_campaigns_name CHECK (btrim(name) <> ''),
    CONSTRAINT ck_campaigns_status CHECK (status IN ('DRAFT', 'SCHEDULED', 'QUEUED', 'SENDING', 'PAUSED', 'COMPLETED', 'CANCELLED', 'FAILED')),
    CONSTRAINT ck_campaigns_priority CHECK (priority IN ('NORMAL', 'URGENT')),
    CONSTRAINT ck_campaigns_scheduled_at CHECK (status <> 'SCHEDULED' OR scheduled_at IS NOT NULL),
    CONSTRAINT ck_campaigns_counters CHECK (
        total_recipients >= 0 AND sent_count >= 0 AND delivered_count >= 0
        AND bounced_count >= 0 AND failed_count >= 0
    )
);

CREATE TABLE campaign_recipients (
    recipient_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     uuid NOT NULL,
    campaign_id         uuid NOT NULL,
    contact_id          uuid NOT NULL,
    email               varchar(254) NOT NULL,
    status              varchar(16) NOT NULL DEFAULT 'QUEUED',
    provider_message_id text,
    error               text,
    sent_at             timestamptz,
    delivered_at        timestamptz,
    bounced_at          timestamptz,
    opened_at           timestamptz,
    clicked_at          timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_campaign_recipients_org_email_campaign UNIQUE (organization_id, email, campaign_id),
    CONSTRAINT fk_campaign_recipients_campaign_org FOREIGN KEY (campaign_id, organization_id)
        REFERENCES campaigns (campaign_id, organization_id) ON DELETE CASCADE,
    CONSTRAINT fk_campaign_recipients_contact_org FOREIGN KEY (contact_id, organization_id)
        REFERENCES contacts (contact_id, organization_id) ON DELETE RESTRICT,
    CONSTRAINT ck_campaign_recipients_email CHECK (
        email = lower(btrim(email))
        AND email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    ),
    CONSTRAINT ck_campaign_recipients_status CHECK (status IN ('QUEUED', 'SENT', 'DELIVERED', 'BOUNCED', 'FAILED', 'OPENED', 'CLICKED', 'COMPLAINED', 'SKIPPED'))
);

CREATE TABLE webhook_events (
    webhook_event_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider          varchar(40) NOT NULL,
    provider_event_id varchar(255) NOT NULL,
    event_type        varchar(100) NOT NULL,
    payload           jsonb,
    received_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_webhook_events_provider_event UNIQUE (provider_event_id),
    CONSTRAINT ck_webhook_events_provider CHECK (btrim(provider) <> ''),
    CONSTRAINT ck_webhook_events_event_id CHECK (btrim(provider_event_id) <> ''),
    CONSTRAINT ck_webhook_events_type CHECK (btrim(event_type) <> '')
);

CREATE TABLE audit_logs (
    audit_log_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations (organization_id) ON DELETE RESTRICT,
    user_id         uuid REFERENCES users (user_id) ON DELETE SET NULL,
    action          varchar(100) NOT NULL,
    target_type     varchar(100) NOT NULL,
    target_id       text,
    metadata        jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_audit_logs_action CHECK (btrim(action) <> ''),
    CONSTRAINT ck_audit_logs_target_type CHECK (btrim(target_type) <> '')
);

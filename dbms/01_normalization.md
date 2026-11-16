# Normalization in Patra: Applying 1NF, 2NF, and 3NF to the Data Model

**Project:** Patra, a multi-tenant mail service platform
**Source model:** MongoDB documents through Mongoose; the AP checkpoint requires the relational target schema in PostgreSQL.
**Topic:** Database Management Systems, Unit 1: Normalization

---

## 1. Introduction

Normalization is the process of organizing data so that each fact is stored in one place. Doing this well prevents three problems:

- **Update anomaly:** a change has to be made in several places, and one is missed.
- **Insert anomaly:** a fact cannot be stored until unrelated data exists.
- **Delete anomaly:** removing one record also erases a fact that should have survived.

Normalization was designed for relational databases, which store data in tables with enforced keys. Patra uses MongoDB, a document database, so the normal forms are not enforced by the database. They are still useful as a checklist. For each collection, this report asks whether a field is in the right place, and when a field is copied on purpose, it records why.

The report covers 1NF, 2NF, and 3NF. BCNF is optional for this checkpoint; the candidate keys and functional dependencies are listed in Section 7. The source model is the current [Patra backend Mongoose models](https://github.com/gusainyashaswi/patra/tree/main/apps/server/src/models). The checkpoint's PostgreSQL schema is a relational translation of that model, so arrays and document payloads are called out explicitly rather than treated as ordinary scalar columns.

**Repository consistency note:** `Patra-PRD.md` describes PostgreSQL/Prisma, while the current model files import Mongoose. This report uses the checked-in model definitions for fields and relationships, then maps them to PostgreSQL for the AP checkpoint.

## 2. Summary

The source is a document model, so several fields are not 1NF relations as stored. The target relational design decomposes true repeating sets (permissions, custom fields, list membership, and template variables) into child tables. It keeps editor block trees and provider/audit payloads as opaque JSON values because the application stores and retrieves those documents as complete snapshots.

| Model area | Current model issue | Relational target |
|---|---|---|
| User, refresh token, organization, membership, transport, suppression | Scalar attributes; keys are documented below | 3NF tables |
| Role permissions | `permissions` is an array | `permissions` and `role_permissions` tables |
| Domain and sender identity | Tenant and transport IDs repeat facts reachable through parent records | Keep the domain's transport link; omit sender `transportId`; document any copied tenant ID |
| Contacts | `customFields` is a key-value object | `contact_custom_fields(contact_id, field_key, field_value)` |
| Lists | `contactIds` is an array | `list_contacts(list_id, contact_id)` |
| Templates and template versions | Draft/published block trees are opaque snapshots; `variables` is a set; `organizationId` depends on `templateId` alone | JSON block snapshot plus `template_version_variables`; tenant copy is an intentional 2NF/3NF exception |
| Campaigns | Tenant ID is derivable from linked tenant-owned assets; counters are derived totals | Tenant ID and counters are documented denormalizations |
| Campaign recipients | `email` is a send-time snapshot; tenant ID is prime in the compound unique key | Preserve email history; tenant copy is a documented BCNF exception |
| Webhook events and audit logs | Payload/metadata are opaque JSON; audit target is polymorphic | Keep JSON snapshots; document that a polymorphic target cannot have one FK |

## 3. First Normal Form (1NF)

**Definition.** A table is in 1NF when every field holds a single atomic value, and there are no repeating groups.

### 3.1 Fields that pass

Most fields are simple: `email`, `name`, `status`, `fromEmail`, `version`. Each holds one value. Each document also has its own `_id`, so every record can be told apart.

### 3.2 Fields that break the strict rule

In a relational design, these fields would be split out. In Patra they are kept, for the reasons below.

**`roles.permissions` (array of strings).** This is a repeating set in the source document. The PostgreSQL target represents permission codes in `permissions` and assignments in `role_permissions`, so a role can be queried and changed without rewriting an array.

**`contacts.customFields` (key-value object).** The keys come from CSV imports and are not known in advance. The target uses `contact_custom_fields(contact_id, field_key, field_value)`; values remain strings without requiring a new column for each import.

**`templates.draftBlocks` and `templateversions.blocks` (nested tree).** The email canvas is a tree of blocks. It is kept as one opaque JSON value because the editor loads and saves it as a complete versioned document.

### 3.3 Multi-valued list

**`lists.contactIds` (array of ObjectIds).** This is a repeating group in the source document. The PostgreSQL target uses one `list_contacts` row per list-contact pair.

### 3.4 Polymorphic reference

**`auditlogs.targetType` and `targetId`.** The target can be any collection, so there is no single foreign key. This is a standard pattern for logs. It means `targetId` may point to a record that no longer exists. That is acceptable, because the audit trail has to outlive the things it records.

## 4. Second Normal Form (2NF)

**Definition.** A table is in 2NF when it is in 1NF and every non-key field depends on the whole key. This matters only when the key has more than one field.

The following are the compound candidate keys represented by the current Mongoose unique indexes. Surrogate `_id` keys also exist on the corresponding documents.

| Collection | Candidate key / unique key | Result |
|---|---|---|
| memberships | (userId, organizationId) | Pass. `roleId` depends on the whole key. |
| suppressions | (organizationId, email) | Pass. `reason` depends on the whole key. |
| contacts | (organizationId, email) | Pass. |
| roles | (organizationId, name) | Pass. |
| domains | (organizationId, name) | Pass. `organizationId` is a prime attribute of this candidate key. |
| campaignrecipients | (organizationId, email, campaignId) | Pass. Recipient status and timestamps depend on the whole key. |
| templateversions | (templateId, version) | **Fails:** `organizationId` depends on `templateId` alone, a proper subset of the key. |

**Recipient key correction.** The Mongoose model has its generated `_id` primary key and a unique index on `(organizationId, email, campaignId)`. It does not declare `(campaignId, contactId)` as a key. The earlier claim that `contactId → email` violated 2NF was therefore based on a key the application does not have. The recipient key has no partial dependencies; the email is also intentionally captured as the address used for that campaign send.

**Why it is kept.** After a campaign is queued, the address it was sent to should not change, even if the contact later corrects their address. The bounce and complaint webhooks also refer to the address that was used. Copying the email at send time keeps that history accurate.

**Trade-off.** If a contact's address is corrected, old recipient rows still show the old address. This is intended behavior. The interface labels the field "address at send time."

## 5. Third Normal Form (3NF)

**Definition.** A table is in 3NF when it is in 2NF and, for every non-trivial dependency `X → A`, either `X` is a superkey or `A` is a prime attribute (part of some candidate key). The simpler rule is to move transitive dependencies on non-key fields into their own relation.

### 5.1 3NF violation: `senderidentities.transportId`

A sender identity has `domainId`, `transportId`, and `organizationId`. Each domain belongs to exactly one transport and organization, so the sender's transport and tenant can be derived from its domain:

```
senderidentities.domainId → domains.transportId, domains.organizationId
senderidentities._id → domainId → transportId, organizationId
```

This is a transitive dependency, and it causes a real update anomaly. If a domain is moved to a different transport, every sender on that domain still points at the old transport. The worker could then send mail with the wrong credentials.

**Normalized target.** Remove `transportId` from the sender identity and get the transport through the domain. Keep `organizationId` only as a documented tenant-query copy; otherwise derive it through the domain as well. The current app code still stores both fields, so this is a CP2 schema correction rather than a fix already present in the application.

```ts
// SenderIdentity, after removing the transitive transport dependency
export interface ISenderIdentity {
  organizationId: Types.ObjectId;
  domainId: Types.ObjectId;     // transport is resolved through the domain
  displayName: string;
  fromEmail: string;
  replyTo?: string;
  isDefault: boolean;
}
```

The worker resolves the transport through the domain and can cache it for the duration of a campaign. The rule that `fromEmail` must belong to the domain is enforced in the service layer, because MongoDB validators cannot easily check it.

### 5.2 Intentional 2NF/3NF violation: `templateversions.organizationId`

Here `templateId` determines `organizationId`, through the `templates` collection. Since `(templateId, version)` is a candidate key, `organizationId` also depends on only part of that key, so this is a 2NF violation as well as a 3NF violation. The organization ID is copied so that tenant-scoped queries and the campaign send check do not need a join. The cost is that a template could not move between organizations without updating every version. Patra does not allow that move, so the risk is low.

### 5.3 Intentional denormalization: campaign tenant key and counters

The counters are derived from the recipient rows:

```
counters.sentCount = number of recipients whose status is SENT, DELIVERED, and so on
```

Storing the totals means the dashboard and the live status stream do not have to count recipient rows on every update. The worker and webhook handler update the counters with `$inc` in the same step that changes a recipient; a recount can repair drift. This is a derived aggregate denormalization, rather than a transitive dependency inside the campaign row.

`campaigns.organizationId` is also derivable from the selected list, sender identity, and template version because all three belong to one organization. The direct field is retained for tenant-scoped campaign reads. The service must verify that all referenced resources belong to that same organization.

### 5.4 Intentional BCNF exception: `campaignrecipients.organizationId`

Here `campaignId` determines `organizationId`, through `campaigns`. The field is copied so the recipient table can be filtered by organization directly. Because `organizationId` is part of the candidate key `(organizationId, email, campaignId)`, this dependency does not break 3NF, but its determinant is not a superkey, so it is a BCNF exception.

### 5.5 Intentional BCNF exception: `domains.organizationId`

Each mail transport belongs to one organization, and each domain references one transport. Therefore `transportId → organizationId`. Since `organizationId` is part of the candidate key `(organizationId, name)`, this is allowed in 3NF but violates BCNF because `transportId` is not a superkey. Keeping the tenant ID supports direct tenant-scoped reads; the write path must verify that both IDs belong together.

## 6. Denormalization Summary

Every copied field is listed here with its reason and how it is kept correct.

| Field | Collection | Reason | Risk | How it stays correct |
|---|---|---|---|---|
| email | campaignrecipients | Record of the address actually used | Differs from current contact | Written once at send time |
| organizationId | domains, senderidentities, templateversions, campaigns, campaignrecipients | Tenant filter without a join | Must match its parent and linked resources | Set on creation from the parent; validate tenant consistency |
| counters | campaigns | Fast dashboard reads | Can drift | `$inc` in worker and webhook; recount job as repair |
| html, text | templateversions | Pinned output, no re-render at send time | Duplicates blocks | Written once on publish |
| variables | templateversions | Validation without parsing HTML | Duplicates blocks | Computed on publish; relational target stores one variable per row |
| name | contacts (and customFields, if import maps both) | Display without reading the bag | Values may diverge | Import should derive both from one parsed value |

## 7. Functional dependencies and normalization steps

The source collections use generated `_id` keys; the relational target uses one row per entity and the candidate keys below. Mongoose adds `createdAt` and `updatedAt` to every model except `WebhookEvent`, which has its own `receivedAt` timestamp and disables automatic timestamps.

### 7.1 First normal form: make repeating values rows

For the relational target, the following multivalued attributes are decomposed. Their values are not stored as comma-separated strings or arrays:

| Source attribute | 1NF relation | Key and dependency |
|---|---|---|
| `roles.permissions` | `permissions(permission_code)` and `role_permissions(role_id, permission_code)` | `(role_id, permission_code)` is the key; no non-key attribute |
| `contacts.customFields` | `contact_custom_fields(contact_id, field_key, field_value)` | `(contact_id, field_key) → field_value` |
| `lists.contactIds` | `list_contacts(list_id, contact_id)` | `(list_id, contact_id)` is the key; no non-key attribute |
| `templateversions.variables` | `template_version_variables(template_version_id, variable_name)` | `(template_version_id, variable_name)` is the key; no non-key attribute |

The template editor's block tree, webhook event payload, and audit metadata remain a single opaque JSON value. They are versioned or retained as documents and are not queried as relational attributes. If the application later needs to filter or update their internal fields, those structures should be decomposed into child rows.

### 7.2 Second normal form: remove partial dependencies

This analysis applies after the 1NF decompositions in Section 7.1. Each composite-key relation is checked against every candidate key:

| Relation | Candidate key | Functional dependency |
|---|---|---|
| `memberships` | `(user_id, organization_id)` | `(user_id, organization_id) → role_id` |
| `template_versions` | `(template_id, version_number)` | **2NF exception:** `template_id → organization_id`; all other version content depends on the complete key |
| `role_permissions` | `(role_id, permission_code)` | No non-key attributes |
| `contact_custom_fields` | `(contact_id, field_key)` | `(contact_id, field_key) → field_value` |
| `list_contacts` | `(list_id, contact_id)` | No non-key attributes |
| `template_version_variables` | `(template_version_id, variable_name)` | No non-key attributes |

Relations with only single-column candidate keys have no partial dependency. The compound unique keys in Section 4 are also candidate keys and were checked; `template_versions.organization_id` remains an intentional 2NF exception for tenant-scoped reads.

### 7.3 Third normal form: remove transitive dependencies

| Relation | Functional dependencies | 3NF result / action |
|---|---|---|
| `users` | `user_id → email, name, password, refreshToken, avatar, isPlatformAdmin`; `email → user_id` | 3NF; email is an alternate key. Relational target stores refresh sessions in `refresh_tokens` |
| `refresh_tokens` | `refresh_token_id → user_id, tokenHash, expiresAt, revokedAt`; `tokenHash → refresh_token_id` | 3NF; token hash is an alternate key |
| `organizations` | `organization_id → name, slug, timezone`; `slug → organization_id` | 3NF; slug is an alternate key |
| `roles` | `role_id → organization_id, name, description, isSystem`; `(organization_id, name) → role_id` | 3NF after permissions are moved to the junction table |
| `permissions` / `role_permissions` | `permission_code` is the key; `(role_id, permission_code)` is the assignment key | No non-key attributes in either relation; 3NF |
| `memberships` | `(user_id, organization_id) → role_id` | 3NF; role is specific to the user-organization pair |
| `mail_transports` | `transport_id → organization_id, name, type, credentialsEncrypted, ratePerSecond, dailyLimit, isDefault, status, lastTestedAt` | 3NF |
| `domains` | `domain_id → organization_id, transport_id, name, verified, providerDomainId, dnsRecords`; `transport_id → organization_id` | 3NF; `organization_id` is prime in `(organization_id, name)`. This is a documented BCNF exception |
| `sender_identities` | `sender_id → organization_id, transport_id, domain_id, displayName, fromEmail, replyTo, isDefault`; `domain_id → transport_id, organization_id` | Current app stores both derived IDs; remove `transport_id` in the relational target. Tenant ID is an optional documented copy |
| `contacts` | `contact_id → organization_id, email, name`; `(organization_id, email) → contact_id` | 3NF after custom fields move to their child table |
| `contact_custom_fields` | `(contact_id, field_key) → field_value` | 3NF |
| `lists` / `list_contacts` | `list_id → organization_id, name`; `(list_id, contact_id)` is the membership key | 3NF after members move to `list_contacts` |
| `suppressions` | `suppression_id → organization_id, email, reason`; `(organization_id, email) → suppression_id` | 3NF |
| `templates` | `template_id → organization_id, name, status, draftBlocks` | 3NF; draft block tree is an opaque document value |
| `template_versions` | `version_id → template_id, organization_id, version, subject, previewText, blocks, html, text`; `(template_id, version) → version_id`; `template_id → organization_id` | Tenant copy intentionally violates 2NF/3NF; HTML/text are immutable publish snapshots |
| `template_version_variables` | `(template_version_id, variable_name)` is the key | 3NF |
| `campaigns` | `campaign_id → organization_id, name, status, priority, templateVersionId, senderIdentityId, listId, createdById, scheduledAt, startedAt, completedAt, counters` | Tenant ID and counters are documented copies; verify linked resources share one tenant |
| `campaign_recipients` | `recipient_id → organization_id, campaign_id, contact_id, email, status, providerMessageId, error, event timestamps`; `(organization_id, email, campaign_id) → recipient_id`; `campaign_id → organization_id` | 3NF; copied tenant ID is a documented BCNF exception. Email is the send-time address snapshot |
| `webhook_events` | `event_id → providerEventId, provider, type, payload, receivedAt`; `providerEventId → event_id` | 3NF; payload is retained as an opaque event snapshot |
| `audit_logs` | `audit_log_id → organization_id, user_id, action, targetType, targetId, metadata, timestamps` | 3NF; `targetType/targetId` is a polymorphic audit reference, not a relational FK |

The target schema keeps the intentional exceptions from Sections 5–6 visible and enforces their parent/tenant consistency in the write path. The normalized relations otherwise have no non-key determinants of non-key attributes.

## 8. Guidelines for future changes

1. If a value can be read from a document that is already linked by an ID, read it instead of copying it.
2. Copy a value only when it must stay fixed over time, or when a query must avoid a join. Note the reason next to the field.
3. Store a derived total only when it is read often, and update it in the same place that changes its source.
4. For each composite unique index, check that every other field depends on the whole key.
5. Keep an array only while it is bounded and always read as a whole. Move it to its own collection once it grows or needs its own attributes.

## 9. Conclusion

Patra's source model contains several intentional document-model exceptions, and the relational target decomposes the repeating sets into junction and key-value tables. The main current 3NF error is the sender's duplicate transport reference; the target schema removes it and resolves the transport through the domain. The remaining copied tenant IDs, counters, and immutable send/publish snapshots are documented trade-offs with explicit consistency rules.

The main lesson is that normalization is a decision about trade-offs, not a rule to follow blindly. Patra stores data in its normalized form where correctness depends on it, and it denormalizes only where there is a clear reason.

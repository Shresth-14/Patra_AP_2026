# Normalization in Patra: Applying 1NF, 2NF, and 3NF to the Data Model

**Project:** Patra, a multi-tenant mail service platform
**Database:** MongoDB (accessed through Mongoose)
**Topic:** Database Management Systems, Unit 1: Normalization

---

## 1. Introduction

Normalization is the process of organizing data so that each fact is stored in one place. Doing this well prevents three problems:

- **Update anomaly:** a change has to be made in several places, and one is missed.
- **Insert anomaly:** a fact cannot be stored until unrelated data exists.
- **Delete anomaly:** removing one record also erases a fact that should have survived.

Normalization was designed for relational databases, which store data in tables with enforced keys. Patra uses MongoDB, a document database, so the normal forms are not enforced by the database. They are still useful as a checklist. For each collection, this report asks whether a field is in the right place, and when a field is copied on purpose, it records why.

The report covers 1NF, 2NF, and 3NF. BCNF and higher are not covered, because Patra's keys are simple enough that they never come into play.

## 2. Summary

| Collection | 1NF | 2NF | 3NF | Comment |
|---|---|---|---|---|
| users, refreshtokens, organizations, memberships | Yes | Yes | Yes | No issues |
| roles | Yes | Yes | Yes | `permissions` is an array, discussed in 3.1 |
| mailtransports, domains | Yes | Yes | Yes | No issues |
| senderidentities | Yes | Yes | **No** | `transportId` depends on `domainId`. Fixed in 5.1 |
| contacts | Yes | Yes | Yes | `customFields` is a flexible bag, discussed in 3.2 |
| lists | Yes | Yes | Yes | `contactIds` is an array, discussed in 3.3 |
| suppressions | Yes | Yes | Yes | No issues |
| templates | Yes | Yes | Yes | No issues |
| templateversions | Yes | Yes | No (intentional) | `organizationId` copied for tenant queries |
| campaigns | Yes | Yes | No (intentional) | `counters` are derived totals |
| campaignrecipients | Yes | No (intentional) | No (intentional) | `email` is a send-time snapshot; `organizationId` copied |
| webhookevents, auditlogs | Yes | Yes | Yes | Polymorphic reference in auditlogs, discussed in 3.4 |

## 3. First Normal Form (1NF)

**Definition.** A table is in 1NF when every field holds a single atomic value, and there are no repeating groups.

### 3.1 Fields that pass

Most fields are simple: `email`, `name`, `status`, `fromEmail`, `version`. Each holds one value. Each document also has its own `_id`, so every record can be told apart.

### 3.2 Fields that break the strict rule

In a relational design, these fields would be split out. In Patra they are kept, for the reasons below.

**`roles.permissions` (array of strings).** Relational 1NF would require a `RolePermission` join table. Patra keeps the list inside the role. The set of permissions is small and bounded, and it is always read together with its role. If permissions ever need their own attributes, such as a grant date, the list should become a separate collection.

**`contacts.customFields` (key-value object).** The keys come from the column headers of each import, so they are not known in advance. A fixed set of columns would require a schema change for every new import. Values are stored as strings.

**`templates.draft.blocks` and `templateversions.blocks` (nested tree).** The email canvas is a tree of blocks. Splitting it into rows would make a single template take many queries to load. Storing it as one document keeps the structure intact.

### 3.3 Multi-valued list

**`lists.contactIds` (array of ObjectIds).** This is a repeating group. It is acceptable for the MVP, because a list is small in practice. When lists grow to thousands of members, the array should move to a `listcontacts` collection with one row per list-contact pair. A MongoDB document is also limited to 16 MB, which sets a hard ceiling.

### 3.4 Polymorphic reference

**`auditlogs.targetType` and `targetId`.** The target can be any collection, so there is no single foreign key. This is a standard pattern for logs. It means `targetId` may point to a record that no longer exists. That is acceptable, because the audit trail has to outlive the things it records.

## 4. Second Normal Form (2NF)

**Definition.** A table is in 2NF when it is in 1NF and every non-key field depends on the whole key. This matters only when the key has more than one field.

Patra's composite keys are the unique indexes made from two or more fields. Each one was checked.

| Collection | Composite key | Result |
|---|---|---|
| memberships | (userId, organizationId) | Pass. `roleId` depends on the whole key. |
| suppressions | (organizationId, email) | Pass. `reason` depends on the whole key. |
| contacts | (organizationId, email) | Pass. |
| templateversions | (templateId, version) | Pass. `html`, `text`, and `blocks` depend on both. |
| roles | (organizationId, name) | Pass. |
| campaignrecipients | (campaignId, contactId) | **Fails for `email`** |

### 4.1 The 2NF example: recipient email

Look at `campaignrecipients`, which is keyed by (campaignId, contactId). The field `email` is decided by `contactId` alone. It is a property of the contact, not of the pairing:

```
(campaignId, contactId) → status, sentAt, providerMessageId    (depends on the whole key)
(contactId)            → email                                 (depends on part of the key)
```

Strictly, this is a partial dependency, and 2NF says to remove it: `email` should be read from `contacts` through `contactId`.

**Why it is kept.** After a campaign is queued, the address it was sent to should not change, even if the contact later corrects their address. The bounce and complaint webhooks also refer to the address that was used. Copying the email at send time keeps that history accurate.

**Trade-off.** If a contact's address is corrected, old recipient rows still show the old address. This is intended behavior. The interface labels the field "address at send time."

## 5. Third Normal Form (3NF)

**Definition.** A table is in 3NF when it is in 2NF and no non-key field depends on another non-key field. In short: if A determines B and B is not a key, B belongs in its own table.

### 5.1 Error found and fixed: `senderidentities.transportId`

A sender identity has both a `domainId` and a `transportId`. But each domain already belongs to exactly one transport, so the `transportId` on the sender can be derived from the domain:

```
senderidentities.domainId → domains.transportId
senderidentities.transportId depends on domainId, not on the sender's own key
```

This is a transitive dependency, and it causes a real update anomaly. If a domain is moved to a different transport, every sender on that domain still points at the old transport. The worker could then send mail with the wrong credentials.

**Fix.** Remove `transportId` from the sender identity and get the transport through the domain.

```ts
// SenderIdentity, after the 3NF fix
export interface ISenderIdentity {
  organizationId: Types.ObjectId;
  domainId: Types.ObjectId;     // transport is resolved through the domain
  displayName: string;
  fromEmail: string;
  replyTo?: string;
  isDefault: boolean;
}
```

The worker resolves the transport in two lookups: sender, then domain, then transport. It caches the result for the duration of a campaign, so the extra lookup happens once rather than once per recipient. The rule that `fromEmail` must belong to the domain is enforced in the service layer, because MongoDB validators cannot easily check it.

### 5.2 Intentional violation: `templateversions.organizationId`

Here `templateId` determines `organizationId`, through the `templates` collection. The organization ID is copied so that tenant-scoped queries and the campaign send check do not need a join. The cost is that a template could not move between organizations without updating every version. Patra does not allow that move, so the risk is low.

### 5.3 Intentional violation: `campaigns.counters`

The counters are derived from the recipient rows:

```
counters.sentCount = number of recipients whose status is SENT, DELIVERED, and so on
```

Storing the totals means the dashboard and the live status stream do not have to count thousands of rows on every update. The worker and the webhook handler update the counters with `$inc` in the same step that changes a recipient, so they stay correct. If they ever drift, a recount job can rebuild them from the recipient rows.

### 5.4 Intentional violation: `campaignrecipients.organizationId`

Here `campaignId` determines `organizationId`, through `campaigns`. The field is copied so the recipient table can be filtered by organization directly. This matters most for this collection, because it is the largest in the system.

## 6. Denormalization Summary

Every copied field is listed here with its reason and how it is kept correct.

| Field | Collection | Reason | Risk | How it stays correct |
|---|---|---|---|---|
| email | campaignrecipients | Record of the address actually used | Differs from current contact | Written once at send time |
| organizationId | templateversions, campaignrecipients, campaigns | Tenant filter without a join | Must match its parent | Set on creation from the parent |
| counters | campaigns | Fast dashboard reads | Can drift | `$inc` in worker and webhook; recount job as repair |
| html, text | templateversions | Pinned output, no re-render at send time | Duplicates blocks | Written once on publish |
| variables | templateversions | Validation without parsing HTML | Duplicates blocks | Computed on publish |
| name | contacts (and customFields) | Display without reading the bag | Mismatch possible | Import sets both from one value |

## 7. Guidelines for future changes

1. If a value can be read from a document that is already linked by an ID, read it instead of copying it.
2. Copy a value only when it must stay fixed over time, or when a query must avoid a join. Note the reason next to the field.
3. Store a derived total only when it is read often, and update it in the same place that changes its source.
4. For each composite unique index, check that every other field depends on the whole key.
5. Keep an array only while it is bounded and always read as a whole. Move it to its own collection once it grows or needs its own attributes.

## 8. Conclusion

Patra's data model is largely normalized. Most collections meet 1NF, 2NF, and 3NF without any change. The model contains one real design error, a transitive dependency in sender identities, which is fixed by removing the duplicate transport reference. The remaining violations are deliberate. Each one trades a small amount of redundancy for a simpler or faster query, and each is documented with its cost and the mechanism that keeps it correct.

The main lesson is that normalization is a decision about trade-offs, not a rule to follow blindly. Patra stores data in its normalized form where correctness depends on it, and it denormalizes only where there is a clear reason.

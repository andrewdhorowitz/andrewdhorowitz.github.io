# Inbox Hygiene — Architecture

The inbox hygiene automation as it is today: every day, two
passes keep the inbox down to mail that needs a human. The first
pass files the school report mail the moment it lands — it makes
sure the label exists, applies it, and archives those messages
out of the inbox, then verifies none are left. It never deletes
anything. The second pass is the disposal step: for every sender
on an approved list of digest and notification senders, it moves
mail older than five days to the trash — recoverable for 30
days, never permanently deleted — including the school reports
the first pass filed. The sender list is fixed in the job
itself, so widening it is a deliberate edit, never a drift.
Bills and all other mail are untouched, and both passes stay
silent unless something fails or a batch looks abnormally
large. Generic labels only: no real email addresses, sender
addresses, or account identifiers.

This file is the canonical source for the Inbox Hygiene diagram
on the showcase site: the diagrams below render on
andrewdhorowitz.com (the Inbox hygiene card, on the Automations
tab) from this same Mermaid source — never a second,
hand-maintained copy. The automation has no repo of its own, so
its canonical source lives here, in the showcase repo. Approved
by Andrew, Oct 31, 2026.

## Views included, and why

- **System Context (L1)** — the automation, its owner, and the
  outside services it depends on. This is the primary view for a
  batch-2 automation.
- **Container (L2)** — included because a real split exists
  inside the system: two daily jobs with opposite safety
  postures (one files and never deletes; the other trashes, but
  only recoverably) plus the run logs they share.
- **Deployment / host view — omitted, deliberately.** Everything
  in this system runs in one place (the assistant side, on a
  schedule) and its only outside call is the email service
  already shown. A deployment view would be a single boundary
  box repeating the Container view's assistant boundary, so it
  would add paper, not information. If the automation ever
  gains a second host, the view gets added then.

## System Context view

```mermaid
C4Context
    title Inbox Hygiene - System Context

    Person(dad, "Dad", "Inbox owner. What is left in the inbox after the daily passes is mail that needs a human.")

    System(ih, "Inbox Hygiene Automation", "Files school report mail under a label and out of the inbox on arrival, and trashes stale digest mail from an approved sender list once it is more than five days old.")

    System_Ext(senders, "Digest Senders", "Automated digest, report, and notification senders on the approved list — school reports, app digests, shipping and deal notices.")
    System_Ext(gmail, "Email Inbox", "The email account. Source mail arrives here, and the automation labels, archives, and trashes within it.")

    Rel(senders, gmail, "Send digests, reports, and notifications")
    Rel(ih, gmail, "Labels and archives school mail on arrival; trashes stale digests past five days")
    Rel(dad, gmail, "Reads what is left — mail that needs a human")
    Rel(ih, dad, "Silent unless a pass fails or a batch looks abnormal")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Container view

```mermaid
C4Container
    title Inbox Hygiene - Container View

    Person(dad, "Dad", "Inbox owner.")

    System_Ext(gmail, "Email Inbox", "The email account both passes work on.")

    System_Boundary(ih, "Inbox Hygiene Automation") {

        Boundary(assistant, "Assistant side", "Scheduled automation") {
            Container(sweep, "Label and Archive Sweep", "Email connector - worker", "Daily pass over the school report mail: makes sure the school label exists, applies it to everything from that sender still in the inbox, and archives it out. Verifies zero remain afterwards and logs the count. Never trashes or deletes anything — disposal is the other pass's job, five days later.")
            Container(trash, "Stale Digest Trash", "Shell script - worker", "Daily pass over the approved sender list (digest, report, and notification senders, fixed in the script — widening it is a deliberate edit). Moves mail older than five days to the trash, recoverable for 30 days and never permanently deleted, including the school reports the sweep filed. Logs per-sender counts and surfaces only on an error or an abnormally large batch.")
            ContainerDb(logs, "Run Logs", "Local files", "One log per day: how many messages each pass swept or trashed, per sender, plus the sweep's verification result. Holds counts only — no mail contents.")
        }
    }

    Rel(sweep, gmail, "Labels and archives school report mail; re-checks the inbox is clear")
    Rel(trash, gmail, "Trashes approved-sender mail older than five days")
    Rel(sweep, logs, "Writes the daily sweep count and verification")
    Rel(trash, logs, "Writes per-sender trash counts")
    Rel(sweep, dad, "Reports only if the sweep fails or the inbox does not verify clear")
    Rel(trash, dad, "Reports only on an error or an abnormally large batch")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Containers

| Container | Shape | Technology | What it does |
|---|---|---|---|
| Label and Archive Sweep | Gear | Email connector, scheduled | Labels school report mail and archives it out of the inbox on arrival; verifies none remain; never deletes |
| Stale Digest Trash | Gear | Shell script, scheduled | Trashes approved-sender mail older than five days — recoverable for 30 days, never permanent |
| Run Logs | Cylinder | Local files | Daily per-sender counts and the sweep verification result; holds no mail contents |

## Shape and host legend

| Visual | Means | Inbox Hygiene examples |
|---|---|---|
| Person figure | A human user | Dad |
| Browser window | A user screen / UI | Not used — this automation has no UI; its output is a tidy inbox |
| Server rack | A server / server-side function | Not used — the automation calls the email service instead of running a server |
| Gear | A worker / background or scheduled job | Label and Archive Sweep, Stale Digest Trash |
| Cylinder | A database / data store | Run Logs |
| Cloud | An external hosted service | Email Inbox, Digest Senders |
| Repository | A source / code store | Not used — no repository of its own; the sender list lives inside the trash job's script |

Hosts: there is exactly one host boundary in these views,
**Assistant side** (the scheduled automation runtime). People and
external services stand outside it.

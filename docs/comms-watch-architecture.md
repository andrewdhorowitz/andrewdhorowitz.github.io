# Priority Comms Watch — Architecture

The priority comms watch as it is today: every 15 minutes during
waking hours (7 AM to 10 PM), a watch checks three channels — texts,
email, and the call log — for anything new from one priority
contact, and the moment something appears it alerts Dad in his
assistant chat, in full, so a time-sensitive family request never
sits unseen. A light overnight pass covers email and retained
notifications. The watch records what it has already alerted, by
timestamp and channel, so the same item never pings twice, and it
stays completely silent when there is nothing new. It is honest
about its evidence: the email channel is live, while the phone's
message store is a synced copy that can lag — anything seen only
in a notification is labeled as exactly that, never described as
real-time. Some alerts carry a next step: when a message confirms
or changes a pending family arrangement, it is surfaced for
action, not just noted. Public-safe, strictly: generic labels
only — no real names, no phone numbers, no email addresses, and
no message content. The watched person appears only as "Priority
Contact", exactly as the public showcase card presents the system.

This file is the canonical source for the Priority Comms Watch
diagram on the showcase site: the diagrams below render on
andrewdhorowitz.com (the Priority comms watch card, on the
Automations tab) from this same Mermaid source — never a second,
hand-maintained copy. The automation has no repo of its own, so
its canonical source lives here, in the showcase repo. Approved
by Andrew, Oct 31, 2026.

## Views included, and why

- **System Context (L1)** — the automation, its owner, the
  watched contact, and the outside services it reads. This is
  the primary view for a batch-2 automation.
- **Container (L2)** — included because a real split exists
  inside the one job: three channel checks that read different
  sources and carry different evidence quality (one channel is
  live, one source lags, one lands in between), sharing a single
  alert state that keeps the whole watch duplicate-free.
- **Deployment / host view — omitted, deliberately.** Everything
  in this system runs in one place (the assistant side, on a
  schedule) and its only outside reads are the phone and the
  email service already shown. A deployment view would be a
  single boundary box repeating the Container view's assistant
  boundary, so it would add paper, not information. If the
  automation ever gains a second host, the view gets added then.

## System Context view

```mermaid
C4Context
    title Priority Comms Watch - System Context

    Person(dad, "Dad", "The alert recipient. Anything new from the priority contact reaches him immediately, in full, in his assistant chat.")
    Person(contact, "Priority Contact", "The one watched contact, named by Dad. Their texts, emails, and calls are what the watch listens for; time-sensitive family requests usually arrive this way.")

    System(watch, "Priority Comms Watch", "Polls three channels every 15 minutes during waking hours for anything new from the priority contact, and alerts the moment something appears. Silent when there is nothing new.")

    System_Ext(phone, "Phone", "Dad's phone. Its synced message store and its call log are two of the three checked channels.")
    System_Ext(gmail, "Gmail", "Dad's email. The third checked channel, and the one that is live rather than a synced copy.")

    Rel(contact, phone, "Texts and calls arrive on the phone")
    Rel(contact, gmail, "Email arrives in the inbox")
    Rel(watch, phone, "Checks the message store and call log for the contact's activity")
    Rel(watch, gmail, "Searches for new email from the contact")
    Rel(watch, dad, "Alerts immediately, in full, on anything new")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Container view

```mermaid
C4Container
    title Priority Comms Watch - Container View

    Person(dad, "Dad", "The alert recipient.")
    Person(contact, "Priority Contact", "The one watched contact.")

    System_Ext(phone, "Phone", "Dad's phone: synced message store plus call log.")
    System_Ext(gmail, "Gmail", "Dad's email (the live channel).")

    System_Boundary(watch, "Priority Comms Watch") {

        Boundary(assistant, "Assistant side", "Scheduled automation") {
            Container(texts, "Texts Check", "Device bridge - worker", "Every 15 minutes in waking hours, looks for new texts from the priority contact in the last 20 minutes, reading the phone's synced message store. That store is a copy that can lag by hours, so anything seen only in a notification is labeled as exactly that, never as real-time. In the overnight light pass, live device reads are skipped and retained notifications stand in.")
            Container(email, "Email Check", "Email search - worker", "Every 15 minutes in waking hours, searches email for new messages from the priority contact in the last 20 minutes. This channel is live. It is also the one full channel in the overnight light pass, which checks for anything new since the last pass.")
            Container(calls, "Calls Check", "Device bridge - worker", "Every 15 minutes in waking hours, checks the phone's call log for missed calls from the priority contact in the last 20 minutes. The call log catches up within minutes, so this channel's evidence is fresher than the message store's.")
            ContainerDb(state, "Alert State", "Local file", "Records what has already been alerted, by timestamp and channel, so the same text, email, or call never pings twice. Holds no message content.")
        }
    }

    Rel(contact, phone, "Texts and calls arrive on the phone")
    Rel(contact, gmail, "Email arrives in the inbox")
    Rel(texts, phone, "Reads the synced message store")
    Rel(email, gmail, "Searches for the contact's new email")
    Rel(calls, phone, "Reads the call log")
    BiRel(texts, state, "Checks and records alerted texts")
    BiRel(email, state, "Checks and records alerted emails")
    BiRel(calls, state, "Checks and records alerted calls")
    Rel(texts, dad, "Alerts immediately on a new text")
    Rel(email, dad, "Alerts immediately on a new email")
    Rel(calls, dad, "Alerts immediately on a missed call")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Containers

| Container | Shape | Technology | What it does |
|---|---|---|---|
| Texts Check | Gear | Device bridge, scheduled | Reads the phone's synced message store for the contact's new texts; labels notification-only sightings as such |
| Email Check | Gear | Email search, scheduled | Searches email for the contact's new messages; the live channel, and the overnight pass's full channel |
| Calls Check | Gear | Device bridge, scheduled | Reads the phone's call log for the contact's missed calls |
| Alert State | Cylinder | Local file | Timestamp-and-channel record of what has already been alerted; the duplicate guard |

## Shape and host legend

| Visual | Means | Priority Comms Watch examples |
|---|---|---|
| Person figure | A human user | Dad, Priority Contact |
| Browser window | A user screen / UI | Not used — this automation has no UI; its output is alerts in the assistant chat |
| Server rack | A server / server-side function | Not used — the automation reads hosted services and the phone instead of running a server |
| Gear | A worker / background or scheduled job | Texts Check, Email Check, Calls Check |
| Cylinder | A database / data store | Alert State |
| Cloud | An external hosted service | Gmail, Phone |
| Repository | A source / code store | Not used — no repository of its own |

Hosts: there is exactly one host boundary in these views,
**Assistant side** (the scheduled automation runtime). People and
external services stand outside it.

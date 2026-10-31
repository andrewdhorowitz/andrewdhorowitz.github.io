# Band Monitor — Architecture

The band monitor as it is today: every morning, two checks keep
Dad current on a school band program he volunteers for. The first
reads the program's own channels — the crew lead's texts, the pit
crew group texts, group messages, the weekly schedule emails, and
the program's weekly schedule document, diffed against yesterday's
saved copy — and reports only material changes (call times,
departures, locations, packing, crew needs), in one message, and
only when something actually changed. The second mirrors the
program's calendar onto Dad's own calendar as private reference
copies, so band days sit alongside family planning without ever
being mistaken for his attendance: he is always *possibly* on pit
crew, and possibility is not attendance. When a source states a
pit crew call time, the monitor asks Dad once — are you going? —
and only a yes puts a call event on his calendar; a decline is
remembered and never re-asked. When a source gives a start time
but no report time, the brief works from a derived be-there time;
an explicit report time always wins. On a pit crew day, the
morning message leads with the call time and the crew sign-up
link. Generic labels only: no student or crew names, no phone
numbers, no email addresses, and no document or calendar IDs.

This file is the canonical source for the Band Monitor diagram
on the showcase site: the diagrams below render on
andrewdhorowitz.com (the Band schedule monitor card, on the
Automations tab) from this same Mermaid source — never a second,
hand-maintained copy. The automation has no repo of its own, so
its canonical source lives here, in the showcase repo. Approved
by Andrew, Oct 31, 2026.

## Views included, and why

- **System Context (L1)** — the monitor, its owner, and the
  outside sources it reads. This is the primary view for a
  batch-2 automation.
- **Container (L2)** — included because real splits exist: two
  separate daily jobs (the source check and the calendar mirror
  sync), the ask-first decision flow inside the check, and the
  small local state they share.
- **Deployment / host view — omitted, deliberately.** Everything
  in this system runs in one place (the assistant side, on a
  schedule) and its only outside reads are the sources already
  shown. A deployment view would be a single boundary box
  repeating the Container view's assistant boundary, so it would
  add paper, not information. If the automation ever gains a
  second host, the view gets added then.

## System Context view

```mermaid
C4Context
    title Band Monitor - System Context

    Person(dad, "Dad", "Calendar owner and occasional pit crew volunteer. Band events on his calendar are reference for the program, not his attendance; he answers the occasional are-you-going question.")
    Person(lead, "Crew Lead", "The pit crew coordinator. Sends call times and logistics updates by text.")

    System(bandmon, "Band Monitor", "Watches the band program's schedule sources and its calendar, reports what changed each morning, and keeps Dad's calendar mirrored with the program's events as reference.")

    System_Ext(doc, "Schedule Document", "The program's weekly schedule document, shared with families. Edited in place, so silent edits are possible.")
    System_Ext(email, "Program Emails", "The program's weekly schedule emails.")
    System_Ext(phone, "Phone", "Dad's phone. Crew lead texts, pit crew group texts, and group schedule messages arrive here.")
    System_Ext(cal, "Google Calendar", "Three calendars: the program's own calendar (the mirror source), Dad's calendar (mirrors and confirmed pit crew calls), and a season calendar holding a few confirmed entries watched against their sources.")

    Rel(lead, phone, "Texts call times and logistics updates")
    Rel(bandmon, doc, "Diffs the document against the saved snapshot")
    Rel(bandmon, email, "Reads the weekly schedule emails")
    Rel(bandmon, phone, "Checks crew texts and group messages")
    Rel(bandmon, cal, "Mirrors program events; writes a pit crew call only after a yes")
    Rel(bandmon, dad, "Reports changes; asks about each new pit crew call")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Container view

```mermaid
C4Container
    title Band Monitor - Container View

    Person(dad, "Dad", "Calendar owner and occasional pit crew volunteer.")
    Person(lead, "Crew Lead", "Sends call times and logistics by text.")

    System_Ext(doc, "Schedule Document", "The program's weekly schedule document.")
    System_Ext(email, "Program Emails", "The program's weekly schedule emails.")
    System_Ext(phone, "Phone", "Crew texts, group texts, and group messages.")
    System_Ext(cal, "Google Calendar", "The program calendar, Dad's calendar, and the season calendar.")

    System_Boundary(bandmon, "Band Monitor") {

        Boundary(assistant, "Assistant side", "Scheduled automation") {
            Container(check, "Schedule Check", "Assistant job - worker", "Each morning, checks the crew lead's texts, the pit crew group texts, group messages, and the weekly schedule email since the last check, and diffs the schedule document against the saved snapshot. Reports material changes only — call times, departures, locations, packing, crew needs — in a single morning message, and stays silent when nothing material changed. Report-only: it never edits the calendar from a source. When today is a pit crew day, the message leads with the call time and the crew sign-up link.")
            Container(pit, "Pit Crew Decisions", "Assistant job - worker", "The ask-first flow inside the check. When any source states a pit crew call time for a specific event, it asks Dad once — are you going? A yes creates or updates his short call event on his calendar, named with its source. A decline is recorded and never re-asked, and an unanswered call never becomes an event on its own; a later time change earns one updated question.")
            Container(sync, "Calendar Mirror Sync", "Script - worker", "Each morning, mirrors the program calendar's guard, ensemble, and competition events onto Dad's calendar as private reference copies — timed when the source publishes a time, visibly tentative placeholders when it has not. Patches mirrors when a source changes, removes them when a source moves or disappears, and deletes the mirror plus alerts Dad when a source is cancelled. Concert and choir entries are alert-only, never mirrored. Also watches the season calendar's confirmed entries against their program-calendar sources, and alerts on brand-new season entries without adding them.")
            ContainerDb(state, "Watch State", "Local files", "Per-source watermarks so each check reads only what is new, the saved snapshot of the schedule document, the pit crew decision record (asked, going, declined per event), and the concert watch list. Holds no message content.")
        }
    }

    Rel(lead, phone, "Texts call times and logistics updates")
    Rel(check, doc, "Diffs against the snapshot")
    Rel(check, email, "Reads new schedule emails")
    Rel(check, phone, "Reads new crew texts and group messages")
    BiRel(check, state, "Reads and advances watermarks and the snapshot")
    Rel(check, pit, "Hands new or changed call times to the decision flow")
    BiRel(pit, dad, "Asks once per event; records the answer")
    Rel(pit, cal, "Creates or updates the call event, only on a yes")
    Rel(check, dad, "Sends the single morning report, only when something changed")
    Rel(sync, cal, "Reads the program calendar; writes and maintains mirrors and season copies")
    Rel(sync, dad, "Alerts on cancellations and new season entries")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Containers

| Container | Shape | Technology | What it does |
|---|---|---|---|
| Schedule Check | Gear | Assistant job, scheduled | Checks texts, messages, and schedule emails; diffs the schedule document; reports material changes in one morning message, silent otherwise |
| Pit Crew Decisions | Gear | Assistant job, scheduled | Asks once per pit crew call; calendars only a yes; remembers declines and never re-asks |
| Calendar Mirror Sync | Gear | Script, scheduled | Mirrors program events onto Dad's calendar as reference copies; maintains them; alerts on cancellations and new season entries |
| Watch State | Cylinder | Local files | Source watermarks, schedule-document snapshot, pit crew decisions, concert watch list |

## Shape and host legend

| Visual | Means | Band Monitor examples |
|---|---|---|
| Person figure | A human user | Dad, Crew Lead |
| Browser window | A user screen / UI | Not used — this automation has no UI; its output is a morning message and calendar copies |
| Server rack | A server / server-side function | Not used — the automation reads hosted services and the phone instead of running a server |
| Gear | A worker / background or scheduled job | Schedule Check, Pit Crew Decisions, Calendar Mirror Sync |
| Cylinder | A database / data store | Watch State |
| Cloud | An external hosted service | Schedule Document, Program Emails, Phone, Google Calendar |
| Repository | A source / code store | Not used — no repository of its own |

Hosts: there is exactly one host boundary in these views,
**Assistant side** (the scheduled automation runtime). People and
external services stand outside it.

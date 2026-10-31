# PARA/GTD — Architecture

One filing system across two Google services. Documents live in
a Drive folder tree organized by PARA — Projects, Areas,
Resources, Archives, ordered by how actionable they are — and
every document the assistant creates is filed into its matching
folder. Tasks live in GTD lists in Google Tasks, and the filing
rule gives each task exactly one home: its project list if it
has one, else Next Actions if it is due this week, Waiting For
if it is blocked on a person, the shared Areas list for ongoing
responsibilities. The two halves are stitched together: each
task's notes carry links to its project or area folder plus a
shared token, and every folder holds a short Links doc naming
its task list and the same token, so a task and its paperwork
are always one search apart from either side. Captures arrive
in conversation and from the assistant's other automations,
which drop them into the Inbox list; a Friday job then sets up
the weekly review that walks the whole system and moves
whatever drifted back to its home.
Public-safe: generic labels only — no real folder or list IDs,
emails, or private project names beyond what the public
showcase cards already use.

This file is the canonical source for the PARA/GTD diagram
on the showcase site: the diagrams below render on
andrewdhorowitz.com (the PARA + GTD filing system card, on the
Automations tab) from this same Mermaid source — never a second,
hand-maintained copy. The automation has no repo of its own, so
its canonical source lives here, in the showcase repo. Approved
by Andrew, Oct 31, 2026.

## Views included, and why

- **System Context (L1)** — the system, its owner, and the
  services it depends on. This is the primary view for a
  batch-2 automation.
- **Container (L2)** — included because a real split exists
  inside the assistant's side of the system: the filing that
  happens at capture time, the link-keeping that stitches tasks
  to folders, the scheduled Friday review setup, and the
  backlog filing pass over the Drive.
- **Deployment / host view — omitted, deliberately.** Everything
  here runs in one place (the assistant side, in conversation and
  on a Friday schedule) and its only outside calls are the
  services already shown. A deployment view would be a single
  boundary box repeating the Container view's assistant boundary,
  so it would add paper, not information. If the system ever
  gains a second host, the view gets added then.

## System Context view

```mermaid
C4Context
    title PARA/GTD - System Context

    Person(dad, "Dad", "System owner. Raises tasks, concerns, and new documents in conversation, works the task lists, and walks the weekly review.")

    System(para, "PARA/GTD System", "One filing system across Drive and Tasks: every document filed by PARA, every task in exactly one GTD list, and the two halves linked so they find each other by search.")

    System_Ext(drive, "Document Drive", "Google Drive. The PARA folder tree: 1. Projects, 2. Areas, 3. Resources, 4. Archives, plus a guide doc and a Links doc in every project and area folder.")
    System_Ext(tasks, "Task Lists", "Google Tasks. The GTD lists: Inbox, Next Actions, Waiting For, Someday / Maybe, one list per project, and one shared Areas list.")
    System_Ext(autos, "Assistant Automations", "Companion watches and jobs. When one spots something that needs a task, it drops the captured item into the Inbox list.")

    Rel(dad, para, "Raises everything in conversation; approves how things are filed")
    Rel(autos, tasks, "Drop captured items into the Inbox list")
    Rel(para, tasks, "Files every task into exactly one list; keeps the task notes' resource links current")
    Rel(para, drive, "Files every created document into its PARA folder; keeps each folder's Links doc current")
    Rel(para, dad, "Friday: sets up the weekly review and flags anything notable, like an Inbox backlog")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Container view

```mermaid
C4Container
    title PARA/GTD - Container View

    Person(dad, "Dad", "System owner.")

    System_Ext(drive, "Document Drive", "Google Drive: the PARA folder tree (generic labels).")
    System_Ext(tasks, "Task Lists", "Google Tasks: the GTD lists (generic labels).")
    System_Ext(autos, "Assistant Automations", "Companion watches and jobs; drop captures into the Inbox list.")

    System_Boundary(para, "PARA/GTD System") {

        Boundary(assistant, "Assistant side", "Conversation + scheduled automation") {
            Container(filing, "Capture & Filing", "Assistant worker", "Runs at capture time, in conversation. Files each new task into exactly one list by the filing rule - its project list if it has one, else Next Actions if it is due this week, Waiting For if it is blocked on a person, the Areas list for ongoing responsibilities (area-prefixed titles) - and files every document the assistant creates into the matching PARA folder. Anything raised that is not tracked yet becomes a task in the matching project list, or Next Actions when it carries a date.")
            Container(linking, "Link Keeper", "Assistant worker", "Maintains the stitching between the two halves. Adds a Resources block to a task's notes with links to its project or area folder and a shared PARA-LINK token; keeps a Links doc in every project and area folder naming its task list and the same token. The token is the search key that finds both sides at once - the two services offer no native cross-link.")
            Container(review, "Weekly Review", "Scheduled job - Fridays", "Runs every Friday afternoon. Checks Next Actions for an open Weekly review task and creates it if missing - never a duplicate - carrying the review checklist: empty the Inbox into Next Actions, Waiting For, or Someday / Maybe; confirm every project's next step is on a list; move finished project folders to Archives; nudge anything stale in Waiting For; glance at Areas. Reports to Dad that the review is ready, with anything notable.")
            Container(pass, "Drive Filing Pass", "Script - on demand", "The backlog half of the system: a rule-based pass over loose files sitting outside the structure, moving each into its PARA folder (media to an Archives media folder, documents to their project or area) and logging every move. Built for the one-time migration of a large existing drive; it sits paused part-way and runs only when told to resume.")
        }
    }

    Rel(dad, filing, "Raises tasks, concerns, and documents in conversation")
    Rel(dad, tasks, "Works the lists; walks the Friday review")
    Rel(autos, tasks, "Drop captured items into the Inbox list")
    Rel(filing, tasks, "Creates each task in exactly one list")
    Rel(filing, drive, "Files created documents into the matching PARA folder")
    Rel(linking, tasks, "Writes the Resources block and token into task notes")
    Rel(linking, drive, "Keeps each folder's Links doc naming its list and token")
    Rel(review, tasks, "Ensures the Weekly review task exists on Next Actions")
    Rel(review, dad, "Reports the review is ready, with anything notable")
    Rel(pass, drive, "Sorts loose files into their PARA folders; logs every move")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Containers

| Container | Shape | Technology | What it does |
|---|---|---|---|
| Capture & Filing | Gear | Assistant worker, in conversation | Files each new task into exactly one list by the filing rule, and each created document into its PARA folder |
| Link Keeper | Gear | Assistant worker | Writes the Resources block + shared token into task notes and keeps a Links doc in every project/area folder |
| Weekly Review | Gear | Scheduled job, Fridays | Ensures the self-creating Weekly review task exists on Next Actions, carrying the review checklist |
| Drive Filing Pass | Gear | Script, on demand | Sorts loose files outside the structure into their PARA folders, logging every move; paused part-way, resumes only when told |

## Shape and host legend

| Visual | Means | PARA/GTD examples |
|---|---|---|
| Person figure | A human user | Dad |
| Browser window | A user screen / UI | Not used — this system has no UI of its own; its surfaces are the Drive and Tasks apps themselves |
| Server rack | A server / server-side function | Not used — the system works through hosted services instead of running a server |
| Gear | A worker / background or scheduled job | Capture & Filing, Link Keeper, Weekly Review, Drive Filing Pass |
| Cylinder | A database / data store | Not used — the data lives in the two Google services; nothing extra is stored on the assistant side |
| Cloud | An external hosted service | Document Drive, Task Lists, Assistant Automations |
| Repository | A source / code store | Not used — no repository of its own |

Hosts: there is exactly one host boundary in these views,
**Assistant side** (conversation plus the scheduled automation
runtime). People and external services stand outside it.

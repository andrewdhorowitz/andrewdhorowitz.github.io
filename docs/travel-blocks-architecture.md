# Travel Blocks — Architecture

The self-maintaining calendar's travel-block automation as it is
today: every morning, a scan reads the next 7 days of calendar
events and keeps the calendar drive-ready. Each in-person event
with an address gets a private travel block sized from the real
drive (drive time × 1.2 plus a cushion, larger for family trips,
rounded up to the next 5 minutes) from home or from the previous
event's location. Days also get one get-ready block, and pickup
legs get a pickup block when Dad is the driver — decided by a
single precedence list, with undecided legs asked about, never
assumed. Blocks are derived state: they mirror their event's
tentative or confirmed status and are reconciled every scan, so a
moved or deleted event never leaves a stale block behind.
Public-safe: generic labels only — no real addresses, calendar
IDs, emails, or family names beyond what the public showcase
cards already use.

This file is the canonical source for the Travel Blocks diagram
on the showcase site: the diagrams below render on
andrewdhorowitz.com (the self-maintaining calendar card, on the
Automations tab) from this same Mermaid source — never a second,
hand-maintained copy. The automation has no repo of its own, so
its canonical source lives here, in the showcase repo. Approved
by Andrew, Oct 31, 2026.

## Views included, and why

- **System Context (L1)** — the automation, its owner, and the
  outside services it depends on. This is the primary view for a
  batch-2 automation.
- **Container (L2)** — included because a real split exists inside
  the one program: the scan that writes blocks, the read-only
  sufficiency check, and the small local state they share.
- **Deployment / host view — omitted, deliberately.** Everything
  in this system runs in one place (the assistant side, on a
  schedule) and its only outside calls are the two external
  services already shown. A deployment view would be a single
  boundary box repeating the Container view's assistant boundary,
  so it would add paper, not information. If the automation ever
  gains a second host, the view gets added then.

## System Context view

```mermaid
C4Context
    title Travel Blocks - System Context

    Person(dad, "Dad", "Calendar owner. The blocks appear on his own calendar; he answers the occasional confirm-with-me question.")

    System(tb, "Travel Blocks Automation", "Keeps the calendar drive-ready: a sized travel block before every in-person event, one get-ready block per day, and pickup blocks where Dad is the driver.")

    System_Ext(cal, "Google Calendar", "The personal and family calendars. Source events live here, and the automation writes its blocks back to the same calendars.")
    System_Ext(osrm, "Routing Service", "Open routing services (geocoding plus OSRM). Turns addresses into coordinates and returns free-flow drive times.")
    System_Ext(ttl, "Time-to-Leave Alerts", "Companion automation. Combines the scan's event pairs with live phone location and traffic to say when to leave.")

    Rel(dad, cal, "Plans and reads events")
    Rel(tb, cal, "Reads the next 7 days of events; writes travel, pickup, get-ready, and warning blocks")
    Rel(tb, osrm, "Geocodes addresses; fetches drive times")
    Rel(tb, dad, "Asks about undecided family pickups (confirm-with-me list)")
    Rel(ttl, tb, "Reads today's event pairs, read-only")
    Rel(ttl, dad, "Alerts when it is time to leave")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Container view

```mermaid
C4Container
    title Travel Blocks - Container View

    Person(dad, "Dad", "Calendar owner.")

    System_Ext(cal, "Google Calendar", "Personal and family calendars (generic labels).")
    System_Ext(osrm, "Routing Service", "Open geocoding and OSRM routing.")
    System_Ext(ttl, "Time-to-Leave Alerts", "Companion automation; reads the pair export.")

    System_Boundary(tb, "Travel Blocks Automation") {

        Boundary(assistant, "Assistant side", "Scheduled automation") {
            Container(scan, "Travel Scan", "Python - worker", "Morning full scan of the next 7 days. Sizes each travel block from home or the previous event location (drive time x 1.2 plus a cushion, larger for family trips, rounded up to 5 minutes), creates pickup blocks where Dad is the decided driver, and adds one get-ready block per day. Ends with dedupe and reconcile sweeps: duplicates are removed, blocks convert when their event's status changes, and blocks whose event moved or was deleted are cleared. Only blocks stamped as the scan's own are ever touched.")
            Container(check, "Travel Check", "Python - worker", "Read-only sufficiency pass, also run on demand. For each pair of back-to-back same-day events, verifies the gap fits the drive between the two addresses; when it does not, pins a short-travel warning block on the calendar, and clears warnings it pinned once the gap is fixed.")
            ContainerDb(state, "Planner State", "Local files", "Geocode cache so address lookups are reused, the check skip-list for pairs known to be fine, and a small adaptive buffer setting. Holds no calendar contents.")
        }
    }

    Rel(scan, cal, "Reads events; writes travel, pickup, and get-ready blocks")
    Rel(scan, osrm, "Geocodes addresses; fetches drive times")
    BiRel(scan, state, "Reads and updates cache and settings")
    Rel(scan, dad, "Sends the confirm-with-me list for undecided pickups")
    Rel(check, cal, "Reads event pairs; pins or clears warning blocks")
    Rel(check, osrm, "Fetches drive times for pair gaps")
    Rel(check, state, "Reads the skip-list")
    Rel(ttl, scan, "Reads today's event pairs (read-only export)")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Containers

| Container | Shape | Technology | What it does |
|---|---|---|---|
| Travel Scan | Gear | Python, scheduled | Creates and maintains the travel, pickup, and get-ready blocks; reconciles them against their events every run |
| Travel Check | Gear | Python, on-demand pass | Verifies back-to-back gaps fit the drive; pins and clears short-travel warnings |
| Planner State | Cylinder | Local files | Geocode cache, check skip-list, adaptive buffer setting |

## Shape and host legend

| Visual | Means | Travel Blocks examples |
|---|---|---|
| Person figure | A human user | Dad |
| Browser window | A user screen / UI | Not used — this automation has no UI; its output is calendar blocks |
| Server rack | A server / server-side function | Not used — the automation calls hosted services instead of running a server |
| Gear | A worker / background or scheduled job | Travel Scan, Travel Check |
| Cylinder | A database / data store | Planner State |
| Cloud | An external hosted service | Google Calendar, Routing Service |
| Repository | A source / code store | Not used — no repository of its own |

Hosts: there is exactly one host boundary in these views,
**Assistant side** (the scheduled automation runtime). People and
external services stand outside it.

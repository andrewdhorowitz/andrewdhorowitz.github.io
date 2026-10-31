# Time-to-Leave Alerts — Architecture

Every 15 minutes between 7 AM and
9 PM, the watch works out the day's next transition — the event
Dad is at (or just left) and the next event after it — from the
event pairs the travel scan already computes, read through a
read-only export. It takes the phone's current GPS position and
fetches the live drive time with traffic to the next event's
location, then computes leave-by: the next event's start, minus
5 minutes (the aim is to arrive 5 early), minus the live drive
scaled by 1.2 plus the pair's cushion, a small buffer, and an
adaptive extra learned from how trips actually go. When the
moment comes it sends exactly one alert for that transition and
records it, so it never repeats. Pairs are filtered first:
placeholder mirrors with no real arrival deadline, tentative or
optional markers, and legs that are someone else's drive never
trigger anything. If a fresh fix says Dad is home when the alert
fires, the home lights run a prism show at full brightness —
their state snapshotted first, restored by a timer minutes
later. A GPS fix older than 30 minutes counts as unknown: the
run does nothing rather than act on stale location.
Public-safe: generic labels only — no real addresses or
coordinates, calendar IDs, emails, family names beyond what the
public showcase cards already use, or light and device IDs.

This file is the canonical source for the Time-to-Leave Alerts
diagram on the showcase site: the diagrams below render on
andrewdhorowitz.com (the time-to-leave alerts card, on the
Automations tab) from this same Mermaid source — never a
second, hand-maintained copy. The automation has no repo of its
own, so its canonical source lives here, in the showcase repo.
Approved by Andrew, Oct 31, 2026.

## Views included, and why

- **System Context (L1)** — the automation, its owner, and the
  outside services it depends on. This is the primary view for a
  batch-2 automation.
- **Container (L2)** — included because a real split exists inside
  the one repeating run: choosing the next transition, the leave-by
  math that decides whether to fire, the light show that can
  accompany an at-home alert, and the small shared state that
  keeps each alert a one-time event.
- **Deployment / host view — omitted, deliberately.** Everything
  in this system runs in one place (the assistant side, on a
  schedule) and its only outside calls are the services already
  shown. A deployment view would be a single boundary box repeating
  the Container view's assistant boundary, so it would add paper,
  not information. If the automation ever gains a second host, the
  view gets added then.

## System Context view

```mermaid
C4Context
    title Time-to-Leave Alerts - System Context

    Person(dad, "Dad", "Calendar owner and driver. The alert targets his next event; the light show joins in only when he is home.")

    System(ttl, "Time-to-Leave Alerts", "Watches the day's next trip against live traffic from Dad's current position and pings the moment it is time to leave - once per transition, never twice.")

    System_Ext(tb, "Travel Blocks Automation", "Companion automation. Its scan computes the day's event pairs - current event, next event, both locations, and the gap between them - and this watch reads them through a read-only export.")
    System_Ext(phone, "Phone Location", "The phone Dad carries. Supplies the current GPS position; the watch only trusts a fresh fix.")
    System_Ext(traffic, "Live Traffic", "A live directions service. Returns the drive time with current traffic between two places.")
    System_Ext(lights, "Home Lights", "The home's smart lights. On an at-home alert they run a prism show at full brightness, then restore their previous state on a short timer.")

    Rel(ttl, tb, "Reads today's event pairs (read-only export)")
    Rel(ttl, phone, "Reads the current position; a fix older than 30 minutes counts as unknown")
    Rel(ttl, traffic, "Fetches the live drive time to the next event's location")
    Rel(ttl, dad, "Sends one time-to-leave alert per transition, never a repeat")
    Rel(ttl, lights, "When he is home, runs the prism show; the lights restore themselves minutes later")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Container view

```mermaid
C4Container
    title Time-to-Leave Alerts - Container View

    Person(dad, "Dad", "Calendar owner and driver.")

    System_Ext(tb, "Travel Blocks Automation", "Companion automation; provides the pair export.")
    System_Ext(phone, "Phone Location", "The phone's GPS fix and its age.")
    System_Ext(traffic, "Live Traffic", "Drive times with current traffic.")
    System_Ext(lights, "Home Lights", "The home's smart lights.")

    System_Boundary(ttl, "Time-to-Leave Alerts") {

        Boundary(assistant, "Assistant side", "Scheduled automation") {
            Container(watch, "Transition Watch", "Scheduled job - worker", "Runs every 15 minutes, 7 AM to 9 PM. Pulls today's remaining event pairs from the travel scan's read-only export and applies the exclusion rules before anything else: pairs whose next event already started or is still hours away, placeholder mirrors with no real arrival deadline, legs that are someone else's drive, and tentative or optional markers that are not commitments. What survives is the single next transition: the event Dad is at (or just left) and the one after it.")
            Container(check, "Leave-By Check", "Scheduled job - worker", "For the chosen transition, takes the phone's current GPS fix - a fix older than 30 minutes counts as unknown and ends the run quietly - and fetches the live drive time with traffic from that position to the next event's location (with no fresh fix it works from the current event's location instead; a failed lookup skips the run). Leave-by is the next event's start, minus 5 minutes because the aim is to arrive 5 early, minus the live drive scaled by 1.2 plus the pair's cushion, a small buffer, and the adaptive extra from Alert State. When the moment comes, it fires the alert and records the transition so it can never fire twice.")
            Container(show, "Light Show", "Scheduled job - worker", "Runs only when an alert fires and the fresh fix says Dad is home. Snapshots the home lights' current state first - never overwriting a snapshot that has not been restored yet - then sets the lights to a prism effect at full brightness and starts a 3-minute timer that restores the snapshot. A separate lights job is the backstop if the timer is missed. Away from home, or with location unknown, the alert goes out alone.")
            ContainerDb(state, "Alert State", "Local files", "State shared with the travel planner. The transitions already alerted today, kept by day, so each departure pings exactly once; and the adaptive buffer - an extra-minutes setting learned from how trips actually go, which the leave-by math adds on top of its fixed cushion.")
        }
    }

    Rel(watch, tb, "Reads today's event pairs (read-only export)")
    Rel(watch, check, "Passes the single next transition")
    Rel(check, phone, "Reads the current GPS fix and its age")
    Rel(check, traffic, "Fetches live drive time with traffic to the next event")
    BiRel(check, state, "Reads the adaptive buffer; records each fired alert")
    Rel(check, dad, "Sends the one time-to-leave alert for the transition")
    Rel(check, show, "Triggers the show when the alert fires and the fix says home")
    Rel(show, lights, "Snapshots the lights, runs the prism show, starts the restore timer")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Containers

| Container | Shape | Technology | What it does |
|---|---|---|---|
| Transition Watch | Gear | Scheduled job | Reads the day's event pairs and applies the exclusion rules to pick the single next transition |
| Leave-By Check | Gear | Scheduled job | Works out leave-by from the fresh GPS fix, live traffic, and the adaptive buffer; fires and records the one alert |
| Light Show | Gear | Scheduled job | On an at-home alert, snapshots the home lights, runs the prism show, and starts the timed restore |
| Alert State | Cylinder | Local files | Already-alerted transitions by day, plus the adaptive buffer setting shared with the travel planner |

## Shape and host legend

| Visual | Means | Time-to-Leave examples |
|---|---|---|
| Person figure | A human user | Dad |
| Browser window | A user screen / UI | Not used — this automation has no UI; its output is a chat alert |
| Server rack | A server / server-side function | Not used — the automation calls hosted services instead of running a server |
| Gear | A worker / background or scheduled job | Transition Watch, Leave-By Check, Light Show |
| Cylinder | A database / data store | Alert State |
| Cloud | An external hosted service | Travel Blocks Automation (companion), Phone Location, Live Traffic, Home Lights |
| Repository | A source / code store | Not used — no repository of its own |

Hosts: there is exactly one host boundary in these views,
**Assistant side** (the scheduled automation runtime). People and
external services stand outside it.

# Gas Tracker — Architecture

Every morning, an estimate pass
works out how much fuel the car has burned since its last fill-up
by adding up the miles in the calendar's planned drives, converts
that to a tank level, and projects the day the level crosses one
quarter. When the crossing is close, a single "Get gas" stop is
placed on the calendar — never as a trip of its own, always
attached to a drive already planned that day, added as extra time
so the drive's travel block starts earlier and get-ready shifts
with it, arrivals untouched. The station is chosen by price among
the convenient options on or near the route. Fill-ups Dad reports
(a gauge level, a miles-to-empty reading, an odometer reading)
reset the estimate, and settled card charges later reconcile each
fill's gallons and cost — never the pump's temporary hold.
Public-safe: generic labels only — no real addresses, station
addresses, card or account identifiers, emails, or family names
beyond what the public showcase cards already use.

This file is the canonical source for the Gas Tracker diagram
on the showcase site: the diagrams below render on
andrewdhorowitz.com (the gas tracker card, on the
Automations tab) from this same Mermaid source — never a second,
hand-maintained copy. The automation has no repo of its own, so
its canonical source lives here, in the showcase repo. Approved
by Andrew, Oct 31, 2026.

## Views included, and why

- **System Context (L1)** — the automation, its owner, and the
  outside services it depends on. This is the primary view for a
  batch-2 automation.
- **Container (L2)** — included because a real split exists inside
  the one program: the estimator that projects the tank level, the
  planner that places the single stop, and the state file they
  share.
- **Deployment / host view — omitted, deliberately.** Everything
  in this system runs in one place (the assistant side, on a
  schedule) and its only outside calls are the external services
  already shown. A deployment view would be a single boundary box
  repeating the Container view's assistant boundary, so it would
  add paper, not information. If the automation ever gains a
  second host, the view gets added then.

## System Context view

```mermaid
C4Context
    title Gas Tracker - System Context

    Person(dad, "Dad", "Car owner and driver. Reports each fill-up afterwards: the gauge level, the miles-to-empty reading, and the odometer.")

    System(gt, "Gas Tracker Automation", "Estimates the tank level from planned driving, projects the quarter-tank crossing, and keeps one price-chosen 'Get gas' stop attached to a drive already on the calendar.")

    System_Ext(cal, "Google Calendar", "The personal calendar. Its travel blocks and driven events are the mileage source, and the 'Get gas' stop is placed here.")
    System_Ext(card, "Card Transactions", "Settled charges from a linked card account. Final fuel amounts reconcile each fill; temporary pump holds are ignored.")
    System_Ext(prices, "Gas Price Listings", "Public station price listings (GasBuddy or similar). Current regular prices near a drive's route.")

    Rel(dad, gt, "Reports fill-ups and gauge readings")
    Rel(gt, cal, "Sums miles in planned drives; places, moves, or removes the 'Get gas' stop")
    Rel(gt, card, "Reads settled fuel charges to reconcile fills")
    Rel(gt, prices, "Compares prices near the chosen drive's route")
    Rel(gt, dad, "One-line note only when a stop is created or moved; silent otherwise")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Container view

```mermaid
C4Container
    title Gas Tracker - Container View

    Person(dad, "Dad", "Car owner and driver.")

    System_Ext(cal, "Google Calendar", "Personal calendar (generic label).")
    System_Ext(card, "Card Transactions", "Settled charges from a linked card account.")
    System_Ext(prices, "Gas Price Listings", "Public station price listings.")

    System_Boundary(gt, "Gas Tracker Automation") {

        Boundary(assistant, "Assistant side", "Scheduled automation") {
            Container(estimator, "Fuel Estimator", "Scheduled job - worker", "Daily pass. Sums the miles in travel blocks and events Dad drives since the last fill (skipping legs that are not his), converts them to a tank level — miles since fill against the car's MPG figure and tank size — and projects the day the level crosses one quarter from the next 48 hours of planned drives. Anchors on the gauge fraction Dad reports after a fill; the car's miles-to-empty readout swings with recent driving style, so it is only a cross-check, never the anchor. Reported odometer readings turn later fills into measured MPG.")
            Container(planner, "Stop Planner", "Scheduled job - worker", "Keeps exactly one future 'Get gas' event, on the crossing day (or the day before, if that day opens with a long drive). Attaches the 20-minute stop to a drive already planned — never a standalone trip — as extra time: the attached travel block starts earlier by the stop length and the day's get-ready block shifts earlier to match, so arrival targets never slip. Chooses the station by price among convenient options (on-route or up to about a 5-minute detour; a different same-day drive wins if it passes fuel at least 10c/gal cheaper), and applies learned local price patterns. Deletes a stop a newer fill-up supersedes, restoring any blocks it had extended.")
            ContainerDb(state, "Tracker State", "Local file", "The last fill and gauge anchor, settled fill history reconciled from card charges, the current level estimate and projected crossing date, the placed stop's event record, and bookkeeping for any travel/get-ready blocks extended (so they can be restored). Holds no card numbers.")
        }
    }

    Rel(dad, estimator, "Reports fill-ups: gauge level, miles-to-empty, odometer")
    Rel(estimator, cal, "Reads travel blocks and driven events; sums miles driven and planned")
    BiRel(estimator, state, "Reads the last fill; writes the level estimate and crossing projection")
    Rel(estimator, card, "Reads settled fuel charges; reconciles each reported fill")
    Rel(planner, cal, "Creates, moves, or deletes the 'Get gas' event; extends the attached travel block and shifts get-ready")
    Rel(planner, prices, "Compares current prices near candidate drives")
    Rel(planner, state, "Reads the projection; records the placed stop and block extensions")
    Rel(planner, dad, "One-line note when a stop is created or moved")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Containers

| Container | Shape | Technology | What it does |
|---|---|---|---|
| Fuel Estimator | Gear | Scheduled job | Sums planned miles since the last fill, converts them to a tank level, and projects the quarter-tank crossing day |
| Stop Planner | Gear | Scheduled job | Places, moves, and removes the single price-chosen "Get gas" stop, attached to an existing drive as extra time |
| Tracker State | Cylinder | Local file | Last fill and gauge anchor, settled fill history, level estimate and projection, placed-stop record and extension bookkeeping |

## Shape and host legend

| Visual | Means | Gas Tracker examples |
|---|---|---|
| Person figure | A human user | Dad |
| Browser window | A user screen / UI | Not used — this automation has no UI; its output is one calendar event |
| Server rack | A server / server-side function | Not used — the automation calls hosted services instead of running a server |
| Gear | A worker / background or scheduled job | Fuel Estimator, Stop Planner |
| Cylinder | A database / data store | Tracker State |
| Cloud | An external hosted service | Google Calendar, Card Transactions, Gas Price Listings |
| Repository | A source / code store | Not used — no repository of its own |

Hosts: there is exactly one host boundary in these views,
**Assistant side** (the scheduled automation runtime). People and
external services stand outside it.

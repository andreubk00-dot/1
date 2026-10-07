# OSTATOK 1.26.0-dev2 — Crisis Season Lifecycle

- Manual start from `ЭФИР / ПОЛЕВАЯ ХРОНИКА`.
- Requires Regional Stability readiness 100% and no active supply SOS.
- Duration: 21 in-game days.
- Persistent phases: `dormant`, `crisis_season`, `season_complete`.
- Start/end days and compact lifecycle history survive faction-state sanitize/load.
- Completed season cannot be restarted.
- Save schema remains 122; state is nested under `faction_state.regional_endgame`.

This slice intentionally adds lifecycle only. Resource pressure and final consequence scoring are layered separately.

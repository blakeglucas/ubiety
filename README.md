# Ubiety

> **ubiety** (noun): the state of being in a definite place or position

## About

Be definitively present.
Ubiety is an ADHD-friendly screen-time reduction tool based on cooldowns.
Instead of budgeting *x* hours per-day per-app, you create groups of apps and set an active-time accumulation window (e.g. 30 minutes).
After the active window expires, Ubiety enforces a cooldown period for every app in the group.
Optionally, the group's active duration can recharge after a period of inactivity (when no app in the group is used).
The groundwork is also laid for bedtime/wake-up guards, but I need to flush them out more completely.

## Requirements

There are no external dependencies.
The only technical requirements beyond a good enough Mac computer are access to a real iOS device (FamilyControls does not work on a simulator) and paid Apple Developer Program membership (FamilyControls is paywalled for some godforsaken reason).

## TODO
- [ ] App icon
- [ ] Better UI
- [ ] Streaks
- [ ] Time reduction report?
- [ ] Bedtime/Wakeup guards
- [ ] App signing with FamilyControls entitlement
- [ ] Improve cooldown handling if an app is in multiple groups (prevent apps being in multiple groups?)

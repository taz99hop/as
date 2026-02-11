# qb-fbi

Advanced FBI roleplay job for QBCore + qb-target.

## Features
- Secret identity toggle: `/fbi undercover`.
- FBI-only classified case management (NUI).
- Surveillance requests: phone tracing and vehicle bugging with cooldowns.
- Multi-stage cinematic raid flow with command approval stage control.
- Specialized internal roles:
  - Intelligence Analyst
  - Field Agent
  - HRT Operator
  - Regional Lead
- Federal-level NPC threat files for live events.
- Agent count balance cap, operation logs, and restricted access gates.

## Dependencies
- `qb-core`
- `qb-target`
- `oxmysql`

## Installation
1. Put the folder in your resources directory.
2. Ensure dependency order in `server.cfg`:
   ```cfg
   ensure qb-core
   ensure qb-target
   ensure qb-fbi
   ```
3. Add FBI job in your QBCore jobs table with 4 grades (0-3).
4. Restart server.

## Notes
- Cases are persisted to `server/cases.json` in the resource.
- This package is a production-ready foundation and can be expanded with real MDT, camera feeds, and judge integrations.

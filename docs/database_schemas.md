# iClash Database Schemas

To effectively present information about players, clans, and wars, we need to collect data from the Clash of Clans API and store it in our own database. Since the Clash API only provides real-time data and does not maintain historical records, we must implement a system that regularly pulls data from the API and tracks the specific information we want to preserve over time.

iClash periodically fetches data from the Clash of Clans API and, for now, stores only the latest snapshot per entity. Since full record versioning is not yet implemented, the current solution uses composite primary keys to handle insertion conflicts. When a conflict occurs, the record is updated based on custom resolution logic defined in the domain layer for each entity type.

There are 3 main context in our database as shown in the ERDs below.

## Player Context

![erd-player-context](/docs/erd_player_context.png "ERD Player Context")

## Clan Context

![erd-clan-context](/docs/erd_clan_context.png "ERD Clan Context")

## Clan War Context

![erd-clan-war-context](/docs/erd_clan_war_context.png "ERD Clan War Context")

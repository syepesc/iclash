# Iclash

Clash of Clans is a widely popular mobile strategy game where players build and upgrade their villages by collecting resources—primarily through attacking other players. While the game features many mechanics, iClash focuses on a selected subset that provides rich, structured data:

- Player Profiles.
- Player Legend League Statistics.
- ~~Player Legend League Attacks (TBD)~~.
- Clans.
- Clan Wars.
- ~~Clan War Leagues (CWL) (TBD)~~.

All tracked data is updated **daily** (every 24 hours) to maintain accuracy and support historical insights.

The goal of this project is to develop a web application that empowers Clash of Clans players and clan managers with access to rich historical data and valuable insights. By visualizing player performance, clan war history, and Clan War League statistics.

## Docs

### [About Clash of Clans API](./docs/clash_of_clans_api.md)

### [About iClash Database](./docs/database_schemas.md)

### [About iClash Data Throughput](./docs/data_throughput.md)

### [About iClash Data Processing Pipeline](./docs/data_processing_pipeline.png)

### Domain Types

WIP

### Tests

WIP

### Boundaries

WIP

### Lifecycle

WIP

### Environment

WIP

### Frontend

WIP
💭 Design the UI views.

### Deployment

WIP.
💭 I guess a cloudformation template that defines a private VPC + EC2 + RDS.

### Monitoring

WIP.
💭 Probably DataDog or any other third-party software that offer metrics out of the box.

### CI/CD

WIP.
💭 CI GitHub Actions (mix format, credo, tests, package)
💭 CD Phase III + Bash script.

## How To Run The Project

To start your Phoenix server:

- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

# Iclash

## 🏁 The Goal

The goal of this project is to develop a web application that empowers Clash of Clans players and clan managers with access to rich historical data and valuable insights. By visualizing player performance, clan war history, and Clan War League statistics.

## 👷🏻‍♂️ Development Plan

### Phase I: Backend

These are the building blocks of the app, the project was design following the methodology of the book [Designing Elixir Systems with OTP](https://pragprog.com/titles/jgotp/designing-elixir-systems-with-otp/) _(Do Fun Things With Big Loud Workers Bees)_ - Worth to read!

![project-design-overview](/docs/project_design_overview.drawio.png "Project Design Overview")

#### 1. (Do) Data

To effectively present information about players, clans, and wars, we need to collect data from the Clash of Clans API and store it in our own database. Since the Clash API only provides real-time data and does not maintain historical records, we must implement a system that regularly pulls data from the API and tracks the specific information we want to preserve over time.

To communicate with Clash API you must create and account with them [Clash API](https://developer.clashofclans.com/#/) and then create a key, use the token from the created key and use it under the env variable `CLASH_API_TOKEN` also add `CLASH_API_BASE_URL` the default value is `https://api.clashofclans.com/v1`.

> For now, is unknown how to reauthenticate and rate limit of the Clash API.

![iclash-data-fetching](/docs/iclash_data_fetching.drawio.png "Iclash Data Fetching")

There are 3 main context in our database as shown in the ERDs below. **Each table (migration) must be represented as an Ecto Schema and must reflect every detail from one to another.**

##### Player Context

![erd-player-context](/docs/erd_player_context.png "ERD Player Context")

##### Clan Context

![erd-clan-context](/docs/erd_clan_context.png "ERD Clan Context")

##### Clan War Context

![erd-clan-war-context](/docs/erd_clan_war_context.png "ERD Clan War Context")

#### 2. (Fun) Functions

WIP

#### 3. (Things) Tests

WIP

#### 4. (Big) Boundaries

WIP

#### 5. (Loud) Lifecycle

WIP

#### 6. (Worker Bees) Pools and Dependencies

WIP

#### 7. UI

WIP

#### 8. Environment

WIP

### Phase II: Frontend

WIP
💭 Design the UI views.

### Phase III: Deployment

WIP.
💭 I guess a cloudformation template that defines a private VPC + EC2 + RDS.

### Phase IV: Monitoring

WIP.
💭 Probably DataDog or any other third-party software that offer metrics out of the box.

### Phase V: CI/CD

WIP.
💭 CI GitHub Actions (mix format, credo, tests, package)
💭 CD Phase III + Bash script.

## How To Run The Project

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

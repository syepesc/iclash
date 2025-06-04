# 📊 iClash Data Throughput Overview

This document outlines the expected **data throughput** of the iClash application, both in terms of **API requests** and **database persistence**, to help understand the system’s scale and performance boundaries.

## 👀 About the Data Gathered and Persisted

The following calculation represents the **initial seed data strategy** implemented by iClash.

It’s important to understand that the calculations presented here are based on **theoretical maximums**, not typical or average gameplay behavior. The goal is to estimate the upper bounds of resource usage and capacity required for iClash’s daily operations. For example:

- We assume 50 top-ranked clans per country, even though the actual number may vary between 1 and 200 depending on leaderboard dynamics and country activity.
We assume 50 players per clan, but in practice, some clans may have fewer active members.
- Each player’s data includes troops, heroes, spells, and other stats, all of which vary in quantity and depth depending on the player’s level and progression.
- Clan war frequency also varies, some clans may not participate in any wars for days, while others may engage in a war every 2 days. Samewise, each player is allows to attack twice per clan war, however, they may execute both or none.

These upper-bound estimates ensure iClash is designed with enough headroom to handle peak usage, even if actual daily operations require fewer resources in practice.

## 🔁 API Request Throughput

To maintain comprehensive coverage, iClash fetches data from the Clash of Clans API according to the following breakdown:

- **Clans**:
  - 50 top clans in each of 253 countries, plus 200 international clans.
  - → **Total**: 12,850 clans.

- **Players**:
  - Each clan can have at most 50 members (players).
  - → **Total**: 642,500 players.

- **Clan Wars**:
  - Each clan can have 1 clan war every 2 days (1 prep day + 1 war day).
  - → **Total**: 6,425 wars/day.

- **Total API Requests per Day**:
  - One request per player, clan, and clan war.
  - → **Total**: 661,775 requests/day.

- **Request Timing**:
  - **Rate limit**: 40 requests/second.
  - **Assumed response time**: < 1 second (validated experimentally).
  - **Time to complete all daily requests**: 4.6 hours at full capacity.

## 🧮 Database Throughput

While estimating the number of HTTP requests is fairly straightforward, database throughput is more nuanced and highly dependent on the underlying schema design. For a deeper dive into the database structure and data retention strategy, see the [iClash Database Documentation](./database_schemas.md).

- **Clans**:
  - 1 record per clan, 2500 bytes per record for every new clan insertion.
  - → **Total**: 12,850 records, 32,125,000 bytes (32.12mb).

- **Players**:
  - 1 record per player, 105 bytes per record.
  - 7 heroes records at most per player, 87 bytes per record.
  - 15 spells records at most per player, 83 bytes per record.
  - 78 troops records at most per player, 82 bytes per record.
  - 1 legend statistic at most per player, 72 bytes per record.
  - → **Subtotal**: 102 records, and 429 bytes at most for every new player insertion.
  - → **Total**: 65,535,000 records, 275,632,500 bytes (275.63mb).

- **Clan Wars**:
  - 1 record per clan war, 104 bytes per record.
  - 200 clan war attacks records at most per clan war, 112 bytes per record.
  - → **Subtotal**: 201 records, and 216 bytes at most for every new clan war.
  - → **Total**: 1,291,425 records, 1,387,800 bytes (1.38mb).

- **Total Database Load**:
  - → 66,839,275 records, 309,144,500 bytes (309.14mb) per day.
  - → 774 records, 3,580 bytes per second.

It's important to note that while the app will consistently send a large number of API requests each day, this does **not** translate to the same **database growth**.

- Even if data does not change, the app still needs to issue and process all requests to detect updates.
- This means query volume and system load remain consistent, even if the volume of persisted data does not.

As a result, the database will grow incrementally based on:

- New players entering the tracked clan ecosystem.
- New clans reaching the top rankings per country.
- New clan wars taking place.

> Document updated on Jun 2, 2025. Please update this if iClash logic change accordingly.

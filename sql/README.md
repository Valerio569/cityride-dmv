# SQL (PostgreSQL) – Star Schema

This folder contains the SQL scripts used to implement the analytical database in PostgreSQL.

## Main file
- `cityride_star_schema.sql`

## What it does
- Creates the star schema with one fact table (`Rides`) and four dimensions (`Drivers`, `Dim_City`, `Dim_Promo`, `Dim_Date`).
- Populates the dimensions from the cleaned staging tables.
- Populates the `Rides` fact table and recomputes derived measures in SQL to ensure consistency.

## How to run (suggested order)
1. Import the cleaned CSVs into PostgreSQL as staging tables (e.g., `drivers_df` and `rides_df`).
2. Run `cityride_star_schema.sql`.

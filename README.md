# cityride-dmv

End-to-end pipeline for CityRide ride-hailing analytics: **R-based data cleaning & feature engineering**, **PostgreSQL star schema** implementation, and a **Tableau dashboard** built on top of a consolidated analytics view.

## Project overview
CityRide operates a ride-hailing service in five U.S. metropolitan areas (Los Angeles, San Francisco, New York, Chicago, Miami).  
This project transforms raw operational data into an analysis-ready database and a visualization layer to support insights on **revenue**, **promotions**, **ride characteristics**, and **driver performance**.

## Repository structure
- `r/` — R scripts for data cleaning, quality checks, feature engineering, and first exploratory analysis (EDA).
- `sql/` — PostgreSQL scripts to create staging tables, build the star schema (fact + dimensions), and create the analytics view used in Tableau.

## Data sources
The analysis is based on two CSV files (not included in this repository):
- `Rides_Data.csv` — one row per completed ride (IDs, city/date, distance, duration, fare, rating, promo code).
- `Drivers_Data.csv` — one row per driver (demographics, experience, average rating, active status).

## R pipeline (data cleaning & feature engineering)
The R workflow:
- Imports raw CSVs with explicit column types
- Standardizes column names (snake_case) and converts `date` to a proper `Date` type
- Checks duplicates and key consistency (`ride_id`, `driver_id`)
- Handles missing promo codes by converting `NA` to `NO_PROMO`
- Creates engineered variables used in analysis:
  - `speed_kmh`
  - `revenue_per_min`
  - `long_ride` (distance > 40 km)
  - `discount_amount` (rule-based estimate from promo code)
  - `weekday`, `week_number`
- Exports cleaned datasets used for database loading:
  - `drivers_df.csv`
  - `rides_df.csv`

Main script: `r/cityride_cleaning_eda.R`

## PostgreSQL star schema
The database is designed as a **star schema**:
- Fact table: `Rides`
- Dimensions:
  - `Drivers`
  - `Dim_City`
  - `Dim_Promo`
  - `Dim_Date`

The SQL script also creates a Tableau-friendly view:
- `v_rides_analytics` (single analytics layer joining fact + dimensions)

Main script: `sql/cityride_star_schema.sql`

## How to run (suggested order)

### 1) Run the R script
1. Place `Rides_Data.csv` and `Drivers_Data.csv` in your working directory
2. Run `r/cityride_cleaning_eda.R`
3. Confirm that the exported files are created:
   - `drivers_df.csv`
   - `rides_df.csv`

### 2) Load data into PostgreSQL
1. Create a database (e.g., `cityride_dmv_assignment`)
2. Import `drivers_df.csv` and `rides_df.csv` into PostgreSQL as staging tables:
   - `drivers_df`
   - `rides_df`

### 3) Run the SQL script
Execute `sql/cityride_star_schema.sql` to:
- Create dimension + fact tables
- Populate all tables from staging
- Create `v_rides_analytics`

### 4) Connect Tableau
In Tableau, connect to PostgreSQL and use:
- `v_rides_analytics` as the main source for dashboards (recommended)

## Notes
- `discount_amount` is an estimated value derived from promo-code rules (percentage or fixed discount). It is used consistently across R and SQL for comparability.
- The dataset is synthetic / simulated (course project), so results should be interpreted as illustrative.

## Authors
MSc Business Administration and Data Science — Data Management and Visualization  
Group members: Giorgio Imbò, Valerio Gatti, Jannik Matthiesen, Giada Salvato

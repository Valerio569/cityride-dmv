# R scripts (Data Cleaning & EDA)

This folder contains the R script used to clean and standardize the raw CityRide datasets and to run a first exploratory data analysis (EDA).

## Main script
- `cityride_cleaning_eda.R`

## What the script does
- Imports `Rides_Data.csv` and `Drivers_Data.csv` with explicit column types.
- Standardizes column names (snake_case) and converts the `date` field to a proper Date type.
- Checks for duplicate IDs and validates the relationship between rides and drivers.
- Handles missing promo codes by recoding them to `NO_PROMO`.
- Creates derived variables for analysis: `speed_kmh`, `revenue_per_min`, `long_ride`, `discount_amount`, `weekday`, `week_number`.
- Produces summary tables and basic plots (distributions, city-based metrics, promo-based metrics, driver-based metrics).

## Outputs
The cleaned datasets are exported as:
- `drivers_df.csv`
- `rides_df.csv`

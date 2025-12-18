
#################################################################################################################################
--CREATING TABLES TO IMPORT THE CLEAN CSV DATAFRAME--
#################################################################################################################################

CREATE TABLE drivers_df (
    driver_id        BIGINT PRIMARY KEY,
    name             TEXT,
    age              NUMERIC,
    city             TEXT,
    experience_years NUMERIC,
    average_rating   NUMERIC,
    active_status    TEXT
);

CREATE TABLE rides_df (
    ride_id        BIGINT PRIMARY KEY,
    driver_id      BIGINT NOT NULL,
    city           TEXT,
    date           DATE,
    distance_km    NUMERIC,
    duration_min   NUMERIC,
    fare           NUMERIC,
    rating         NUMERIC,
    promo_code     TEXT
);


#################################################################################################################################
--CREATING DIMENSION AND FACT TABLES--
#################################################################################################################################

CREATE TABLE Drivers (
    driver_id        BIGINT PRIMARY KEY,
    name             TEXT NOT NULL,
    age              NUMERIC,
    city             TEXT,
    experience_years NUMERIC,
    average_rating   NUMERIC,
    active_status    TEXT
);

CREATE TABLE Dim_City (
    city    TEXT PRIMARY KEY,
    state   TEXT,
    country TEXT,
    region  TEXT
);

CREATE TABLE Dim_Promo (
    promo_code            TEXT PRIMARY KEY,
    promo_type            TEXT,
    discount_percent      NUMERIC,
    discount_fixed_amount NUMERIC
);

CREATE TABLE Dim_Date (
    date          DATE PRIMARY KEY,
    day           SMALLINT,
    month         SMALLINT,
    month_name    TEXT,
    year          INTEGER,
    quarter       SMALLINT,
    week_number   SMALLINT,
    weekday_name  TEXT,
    is_weekend    BOOLEAN
);

CREATE TABLE Rides (
    ride_id         BIGINT PRIMARY KEY,
    driver_id       BIGINT NOT NULL,
    city            TEXT   NOT NULL,
    promo_code      TEXT   NOT NULL,
    date            DATE   NOT NULL,
    
    distance_km     NUMERIC,
    duration_min    NUMERIC,
    fare            NUMERIC,
    rating          NUMERIC,
    speed_kmh       NUMERIC(10,2),
    revenue_per_min NUMERIC(10,4),
    long_ride       BOOLEAN,
    discount_amount NUMERIC(10,2),
    
    CONSTRAINT fk_rides_driver
        FOREIGN KEY (driver_id)  REFERENCES Drivers(driver_id),
    CONSTRAINT fk_rides_city
        FOREIGN KEY (city)       REFERENCES Dim_City(city),
    CONSTRAINT fk_rides_promo
        FOREIGN KEY (promo_code) REFERENCES Dim_Promo(promo_code),
    CONSTRAINT fk_rides_date
        FOREIGN KEY (date)       REFERENCES Dim_Date(date)
);


#################################################################################################################################
--POPULATING THE TABLES--
#################################################################################################################################

INSERT INTO Drivers (driver_id, name, age, city, experience_years, average_rating, active_status)
SELECT DISTINCT
    driver_id,
    name,
    age,
    city,
    experience_years,
    average_rating,
    active_status
FROM drivers_df;


INSERT INTO Dim_City (city, state, country, region)
SELECT DISTINCT
    city,
    CASE city
        WHEN 'Los Angeles'   THEN 'California'
        WHEN 'San Francisco' THEN 'California'
        WHEN 'Chicago'       THEN 'Illinois'
        WHEN 'New York'      THEN 'New York'
        WHEN 'Miami'         THEN 'Florida'
    END AS state,
    'United States' AS country,
    CASE city
        WHEN 'Los Angeles'   THEN 'West Coast'
        WHEN 'San Francisco' THEN 'West Coast'
        WHEN 'Chicago'       THEN 'Midwest'
        WHEN 'New York'      THEN 'East Coast'
        WHEN 'Miami'         THEN 'East Coast'
    END AS region
FROM rides_df 
WHERE city IS NOT NULL;


INSERT INTO Dim_Promo (promo_code, promo_type, discount_percent, discount_fixed_amount)
SELECT DISTINCT
    promo_code,
    CASE
        WHEN promo_code = 'DISCOUNT10' THEN 'PERCENTAGE'
        WHEN promo_code = 'SAVE20'     THEN 'PERCENTAGE'
        WHEN promo_code = 'WELCOME5'   THEN 'FIXED'
        ELSE 'NONE'
    END AS promo_type,
    CASE
        WHEN promo_code = 'DISCOUNT10' THEN 0.10
        WHEN promo_code = 'SAVE20'     THEN 0.20
        ELSE 0.0
    END AS discount_percent,
    CASE
        WHEN promo_code = 'WELCOME5'   THEN 5.0
        ELSE 0.0
    END AS discount_fixed_amount
FROM rides_df;


INSERT INTO Dim_Date (date, day, month, month_name, year, quarter, week_number, weekday_name, is_weekend)
SELECT DISTINCT
    date,
    EXTRACT(DAY   FROM date)::SMALLINT      AS day,
    EXTRACT(MONTH FROM date)::SMALLINT      AS month,
    TO_CHAR(date, 'Mon')                    AS month_name,
    EXTRACT(YEAR  FROM date)::INT           AS year,
    EXTRACT(QUARTER FROM date)::SMALLINT    AS quarter,
    EXTRACT(WEEK FROM date)::SMALLINT       AS week_number,
    TO_CHAR(date, 'Dy')                     AS weekday_name,
    CASE
        WHEN EXTRACT(ISODOW FROM date) IN (6, 7) THEN TRUE
        ELSE FALSE
    END AS is_weekend
FROM rides_df
WHERE date IS NOT NULL;


INSERT INTO Rides (
    ride_id,
    driver_id,
    city,
    promo_code,
    date,
    distance_km,
    duration_min,
    fare,
    rating,
    speed_kmh,
    revenue_per_min,
    long_ride,
    discount_amount
)
SELECT
    ride_id,
    driver_id,
    city,
    promo_code,
    date,
    distance_km,
    duration_min,
    fare,
    rating,
    -- speed_kmh: distance / duration
    CASE
        WHEN duration_min IS NOT NULL AND duration_min <> 0
            THEN distance_km / (duration_min / 60.0)
        ELSE NULL
    END AS speed_kmh,
    -- revenue_per_min: fare / duration
    CASE
        WHEN duration_min IS NOT NULL AND duration_min <> 0
            THEN fare / duration_min
        ELSE NULL
    END AS revenue_per_min,
    -- long_ride: TRUE if distance > 40km
    CASE
        WHEN distance_km > 40 THEN TRUE
        ELSE FALSE
    END AS long_ride,
    -- discount_amount: as in r
   CASE
        WHEN r.promo_code = 'DISCOUNT10' THEN ROUND(r.fare / 0.90 - r.fare, 2)
        WHEN r.promo_code = 'SAVE20'     THEN ROUND(r.fare / 0.80 - r.fare, 2)
        WHEN r.promo_code = 'WELCOME5'   THEN 5.00
        ELSE 0.00
    END AS discount_amount
FROM rides_df r;


#################################################################################################################################
--CREATING VIEW TO BUILD VISUALIZATIONS--
#################################################################################################################################

CREATE OR REPLACE VIEW v_rides_analytics AS
SELECT
    r.ride_id,
    r.driver_id,
    d.name              AS driver_name,
    d.age               AS driver_age,
    d.city              AS driver_city,
    d.experience_years,
    d.average_rating    AS driver_avg_rating,
    d.active_status,

    r.city              AS ride_city,
    c.state,
    c.country,
    c.region,

    r.promo_code,
    p.promo_type,
    p.discount_percent,
    p.discount_fixed_amount,

    r.date,
    dd.day,
    dd.month,
    dd.month_name,
    dd.year,
    dd.quarter,
    dd.week_number,
    dd.weekday_name,
    dd.is_weekend,

    r.distance_km,
    r.duration_min,
    r.fare,
    r.rating           AS ride_rating,
    r.speed_kmh,
    r.revenue_per_min,
    r.long_ride,
    r.discount_amount
FROM Rides     r
JOIN Drivers   d  ON r.driver_id  = d.driver_id
JOIN Dim_City  c  ON r.city       = c.city
JOIN Dim_Promo p  ON r.promo_code = p.promo_code
JOIN Dim_Date  dd ON r.date       = dd.date;

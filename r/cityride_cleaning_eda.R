########################################################################################################
#DATA CLEANING
########################################################################################################

install.packages(c("tidyverse", "janitor", "skimr", "lubridate"))
library(tidyverse)
library(janitor)
library(skimr)
library(lubridate)

# importing the data specifying col_types in order to avoid misinterpretations regarding the data type, converting ride_ID and driver_ID into integers

rides_raw <- read_csv("Rides_Data.csv",
                        col_types = cols(
                          Ride_ID      = col_integer(),
                          Driver_ID    = col_integer(),
                          City         = col_character(),
                          Date         = col_character(),
                          Distance_km  = col_double(),
                          Duration_min = col_double(),
                          Fare         = col_double(),
                          Rating       = col_double(),
                          Promo_Code   = col_character()
                        ))

drivers_raw <- read_csv("Drivers_Data.csv",
                        col_types = cols(
                          Driver_ID        = col_integer(),
                          Name             = col_character(),
                          Age              = col_double(),
                          City             = col_character(),
                          Experience_Years = col_double(),
                          Average_Rating   = col_double(),
                          Active_Status    = col_character()
                        ))

# first check  

glimpse(rides_raw) # to have a compact view of the dataset and understand if types are correct
summary(rides_raw) # to identify impossible values or suspect ranges
skimr::skim(rides_raw) # to count N/A, distributions etc... in general used to check the data quality and possible outliers

glimpse(drivers_raw)
summary(drivers_raw)
skimr::skim(drivers_raw)

# cleaning names of the columns for better readability

df_drivers <- drivers_raw %>% clean_names()
df_rides <- rides_raw %>% clean_names()

# creating tables that identify clearly the number of N/A of both the datasets for exploratory reasons

rides_na <- df_rides %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "n_na") %>%
  arrange(desc(n_na))

drivers_na <- df_drivers %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "n_na") %>%
  arrange(desc(n_na))

# turning date from string to date object

df_rides$date <- as.Date(df_rides$date, format = "%m/%d/%Y")

# duplicates check regarding the main IDs

any(duplicated(df_rides$ride_id))   
any(duplicated(df_drivers$driver_id))

# verifying correspondence driver ID between tables

setdiff(df_rides$driver_id, df_drivers$driver_id)
setdiff(df_drivers$driver_id, df_rides$driver_id)

# let's mutate the N/A as NO_PROMO

df_rides <- df_rides %>%
  mutate(promo_code = fct_na_value_to_level(promo_code, level = "NO_PROMO"))

# left join on driver ID to get more info, creating rides_drivers

rides_drivers <- df_rides %>%
  left_join(df_drivers, by = "driver_id")

glimpse(rides_drivers) # checking on rides_drivers

sum(is.na(rides_drivers$name)) # check on the join, if 0 all the rides have a known driver

# creating variables for further analysis

rides_drivers <- rides_drivers %>%
  mutate(
    # average speed km/h
    speed_kmh = distance_km / (duration_min / 60),
    # revenue per minute
    revenue_per_min = fare / duration_min,
    # specifying long rides
    long_ride = distance_km > 40,
    # discount in USD (estimate) based on promo_code
    discount_amount = case_when(
      promo_code == "DISCOUNT10" ~ fare / 0.90 - fare,  # 10% discount
      promo_code == "SAVE20"     ~ fare / 0.80 - fare,  # 20% discount
      promo_code == "WELCOME5"   ~ 5,                   # fixed 5 USD
      TRUE                       ~ 0                    # NO_PROMO or other
    ),
    # differentiating weekdays 
    weekday          = wday(date, label = TRUE, abbr = TRUE),
    week_number      = isoweek(date)
  )

# saving the new dataframes

write_csv(df_drivers, "drivers_df.csv")
write_csv(df_rides, "rides_df.csv")


########################################################################################################
# EXPLORATORY DATA ANALYSIS
########################################################################################################

rides_drivers <- rides_drivers %>%
  rename(
    city_ride   = city.x,  # city of the ride
    city_driver = city.y   # city associated to the driver
  )

# looking for distribution of the rides for city and plotting it

rides_by_city <- rides_drivers %>%
  count(city_ride, name = "n_rides") %>%
  arrange(desc(n_rides))

ggplot(rides_by_city, aes(x = city_ride, y = n_rides)) +
  geom_col(fill = "steelblue") +
  labs(
    title = "Number of rides per city",
    x = "City (ride)",
    y = "Number of rides"
  )


##########################################################################
# basic histograms to see the distributions of various values

# Distance

ggplot(rides_drivers, aes(x = distance_km)) +
  geom_histogram(bins = 30, fill = "steelblue", color = "white") +
  labs(title = "Distance distribution (km)",
       x = "Distance (km)", y = "Count")


# Duration

ggplot(rides_drivers, aes(x = duration_min)) +
  geom_histogram(bins = 30, fill = "darkseagreen3", color = "white") +
  labs(title = "Duration distribution (minutes)",
       x = "Duration (min)", y = "Count")


# Fare

ggplot(rides_drivers, aes(x = fare)) +
  geom_histogram(bins = 30, fill = "goldenrod2", color = "white") +
  labs(title = "Fare distribution (USD)",
       x = "Fare (USD)", y = "Count")


# Rating

ggplot(rides_drivers, aes(x = factor(rating))) +
  geom_bar(fill = "mediumorchid", color = "white") +
  labs(title = "Rating distribution",
       x = "Rating", y = "Count")


##########################################################################
# Relationships between distance duration and fare

# Scatter plot Distance vs Fare

ggplot(rides_drivers, aes(x = distance_km, y = fare)) +
  geom_point(alpha = 0.4) +
  geom_smooth(method = "lm", se = FALSE) +
  labs(title = "Relationship between Distance and Fare",
       x = "Distance (km)", y = "Fare (USD)")


# Scatter plot Duration vs Fare

ggplot(rides_drivers, aes(x = duration_min, y = fare)) +
  geom_point(alpha = 0.4) +
  geom_smooth(method = "lm", se = FALSE) +
  labs(title = "Relationship between Duration and Fare",
       x = "Duration (min)", y = "Fare (USD)")


##########################################################################
# City-based analysis

city_summary <- rides_drivers %>%
  group_by(city_ride) %>%
  summarise(
    n_rides         = n(),
    avg_distance    = mean(distance_km),
    avg_duration    = mean(duration_min),
    avg_fare        = mean(fare),
    avg_rating      = mean(rating),
    avg_speed       = mean(speed_kmh),
    avg_rev_per_min = mean(revenue_per_min),
    long_ride_share = mean(long_ride)
  ) %>%
  arrange(desc(n_rides))


ggplot(city_summary, aes(x = reorder(city_ride, avg_fare),
                         y = avg_fare,
                         fill = city_ride)) + 
  geom_col(color = "white") +
  labs(
    title = "Mean fare per city",
    x = "City (ride)",
    y = "Mean fare (USD)"
  )


ggplot(city_summary, aes(x = reorder(city_ride, avg_rating),
                         y = avg_rating,
                         fill = city_ride)) +
  geom_col(color = "white") +
  labs(
    title = "Mean customer rating per city",
    x = "City (ride)",
    y = "Mean rating"
  ) 


ggplot(city_summary, aes(x = reorder(city_ride, avg_speed),
                         y = avg_speed,
                         fill = city_ride)) +
  geom_col(color = "white") +
  labs(
    title = "Mean speed per city",
    x = "City (ride)",
    y = "Mean speed (km/h)"
  )


ggplot(city_summary, aes(x = reorder(city_ride, avg_rev_per_min),
                         y = avg_rev_per_min,
                         fill = city_ride)) +
  geom_col(color = "white") +
  labs(
    title = "Mean revenue per minute per city",
    x = "City (ride)",
    y = "Mean revenue per minute (USD/min)"
  ) 


ggplot(city_summary, aes(x = reorder(city_ride, long_ride_share),
                         y = long_ride_share,
                         fill = city_ride)) +
  geom_col(color = "white") +
  labs(
    title = "Share of long rides per city",
    x = "City (ride)",
    y = "Long ride share"
  )


##########################################################################
# Promocodes-based analysis

promo_summary <- rides_drivers %>%
  group_by(promo_code) %>%
  summarise(
    n_rides      = n(),
    avg_distance = mean(distance_km),
    avg_fare     = mean(fare),
    avg_rating   = mean(rating),
    total_discount = sum(discount_amount)
  ) %>%
  arrange(desc(n_rides))


ggplot(promo_summary, aes(x = reorder(promo_code, n_rides),
                          y = n_rides,
                          fill = promo_code)) +
  geom_col(color = "white") +
  labs(
    title = "Number of rides per promo code",
    x = "Promo code",
    y = "Number of rides"
  )


ggplot(promo_summary, aes(x = reorder(promo_code, avg_fare),
                          y = avg_fare,
                          fill = promo_code)) +
  geom_col(color = "white") +
  labs(
    title = "Mean fare per promo code",
    x = "Promo code",
    y = "Mean fare (USD)"
  )


ggplot(promo_summary, aes(x = reorder(promo_code, avg_rating),
                          y = avg_rating,
                          fill = promo_code)) +
  geom_col(color = "white") +
  labs(
    title = "Mean customer rating per promo code",
    x = "Promo code",
    y = "Mean rating"
  )


ggplot(promo_summary, aes(x = reorder(promo_code, total_discount),
                          y = total_discount,
                          fill = promo_code)) +
  geom_col(color = "white") +
  labs(
    title = "Total discount amount by promo code",
    x = "Promo code",
    y = "Total discount (USD)"
  )


##########################################################################
# Driver-based analysis

driver_summary <- rides_drivers %>%
  group_by(driver_id, name, age, city_driver,
           experience_years, average_rating, active_status) %>%
  summarise(
    n_rides         = n(),
    avg_fare        = mean(fare),
    avg_rating_rides = mean(rating),
    avg_distance    = mean(distance_km),
    .groups = "drop"
  )


ggplot(driver_summary, aes(x = n_rides)) +
  geom_histogram(bins = 15, fill = "steelblue", color = "white") +
  labs(
    title = "Distribution of number of rides per driver",
    x = "Number of rides",
    y = "Count of drivers"
  )


ggplot(driver_summary, aes(x = experience_years, y = avg_rating_rides, color = active_status)) +
  geom_point(alpha = 0.7) +
  geom_smooth(method = "lm", se = FALSE) +
  labs(
    title = "Driver experience vs average customer rating",
    x = "Experience (years)",
    y = "Average rating from rides"
  )


top10_fare <- driver_summary %>%
  arrange(desc(avg_fare)) %>%
  slice_head(n = 10)

ggplot(top10_fare, aes(x = reorder(name, avg_fare), y = avg_fare, fill = name)) +
  geom_col(color = "white") +
  coord_flip() +
  labs(
    title = "Top 10 drivers by mean fare",
    x = "Driver",
    y = "Mean fare (USD)"
  )

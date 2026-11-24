-- =====================================================================
-- CP3: Queries for Rydely Automotive Rental Platform
-- File: dbms/04_queries.sql
-- Engine: PostgreSQL 14+
--
-- Every query is tagged "-- READ" (SELECT only) or "-- WRITE"
-- (INSERT / UPDATE / DELETE). JOINs are used wherever more than one
-- table is involved.
--
-- Sample parameters used below:
--   user_id  = 101   (renter)
--   owner_id = 50    (car owner)
--   car_id   = 1
--   booking_id = 1
--   city     = 'Delhi' / 'Sonipat'
-- =====================================================================


-- =====================================================================
-- Q1: Search available cars in a city with filters (SUV, Manual)
-- Purpose: Main car listing / search page.
-- =====================================================================
-- READ
SELECT c.car_id, c.brand, c.model, c.year, c.price_per_day, ci.name AS city_name
FROM   cars c
JOIN   cities ci ON ci.city_id = c.city_id
WHERE  ci.name         = 'Delhi'
  AND  c.is_available  = TRUE
  AND  c.category      = 'SUV'
  AND  c.transmission  = 'Manual'
ORDER BY c.price_per_day ASC;


-- =====================================================================
-- Q2: Strict date availability (cars NOT booked in a date range)
-- Purpose: Anti-join (LEFT JOIN ... IS NULL) instead of NOT IN subquery.
--          Overlap rule: existing.pickup <= new.return AND existing.return >= new.pickup
-- =====================================================================
-- READ
SELECT c.car_id, c.brand, c.model, c.price_per_day
FROM   cars c
JOIN   cities ci ON ci.city_id = c.city_id
LEFT JOIN bookings b
       ON  b.car_id      = c.car_id
       AND b.status     <> 'cancelled'
       AND b.pickup_date <= '2026-12-10'
       AND b.return_date >= '2026-12-05'
WHERE  ci.name        = 'Sonipat'
  AND  c.is_available = TRUE
  AND  b.booking_id IS NULL;


-- =====================================================================
-- Q3: Create a new booking (Pending)
-- Purpose: Renter requests a car.
-- =====================================================================
-- WRITE
INSERT INTO bookings (car_id, user_id, pickup_date, return_date, total_price, status)
VALUES (1, 101, '2026-12-05', '2026-12-10', 12500.00, 'pending')
RETURNING booking_id, status;


-- =====================================================================
-- Q4: A user's booking history with car details
-- =====================================================================
-- READ
SELECT b.booking_id, c.brand, c.model, b.pickup_date, b.return_date,
       b.total_price, b.status
FROM   bookings b
JOIN   cars c ON c.car_id = b.car_id
WHERE  b.user_id = 101
ORDER BY b.pickup_date DESC;


-- =====================================================================
-- Q5: Owner dashboard - each owned car with bookings and revenue
-- =====================================================================
-- READ
SELECT c.car_id, c.brand, c.model,
       COUNT(b.booking_id)             AS total_bookings,
       COALESCE(SUM(b.total_price), 0) AS total_revenue
FROM   cars c
LEFT JOIN bookings b
       ON  b.car_id = c.car_id
       AND b.status = 'confirmed'
WHERE  c.owner_id = 50
GROUP BY c.car_id, c.brand, c.model
ORDER BY total_revenue DESC;


-- =====================================================================
-- Q6: Owner confirms a pending booking (with ownership check via JOIN)
-- Purpose: UPDATE ... FROM joins cars so only the car's owner can confirm.
-- =====================================================================
-- WRITE
UPDATE bookings b
SET    status = 'confirmed'
FROM   cars c
WHERE  c.car_id     = b.car_id
  AND  c.owner_id   = 50
  AND  b.booking_id = 1
  AND  b.status     = 'pending'
RETURNING b.booking_id, b.status;


-- =====================================================================
-- Q7: Analytics - top 5 most booked car categories
-- =====================================================================
-- READ
SELECT c.category, COUNT(b.booking_id) AS booking_count
FROM   cars c
JOIN   bookings b ON b.car_id = c.car_id
WHERE  b.status = 'confirmed'
GROUP BY c.category
ORDER BY booking_count DESC
LIMIT 5;


-- =====================================================================
-- Q8: Analytics - total platform revenue grouped by city
-- =====================================================================
-- READ
SELECT ci.name AS city_name, SUM(b.total_price) AS total_city_revenue
FROM   bookings b
JOIN   cars c   ON c.car_id  = b.car_id
JOIN   cities ci ON ci.city_id = c.city_id
WHERE  b.status = 'confirmed'
GROUP BY ci.city_id, ci.name
ORDER BY total_city_revenue DESC;


-- =====================================================================
-- Q9: Owner takes a car offline (ownership validated inline)
-- =====================================================================
-- WRITE
UPDATE cars
SET    is_available = FALSE
WHERE  car_id   = 1
  AND  owner_id = 50
RETURNING car_id, is_available;


-- =====================================================================
-- Q10: Upcoming confirmed trips for a user
-- =====================================================================
-- READ
SELECT b.booking_id, c.brand, c.model, ci.name AS city_name,
       b.pickup_date, b.return_date
FROM   bookings b
JOIN   cars c    ON c.car_id   = b.car_id
JOIN   cities ci ON ci.city_id = c.city_id
WHERE  b.user_id     = 101
  AND  b.status      = 'confirmed'
  AND  b.pickup_date >= CURRENT_DATE
ORDER BY b.pickup_date ASC;


-- =====================================================================
-- Q11: Renter cancels their own booking
-- Purpose: Only the booking's renter, only before pickup, only if active.
-- =====================================================================
-- WRITE
UPDATE bookings
SET    status = 'cancelled'
WHERE  booking_id  = 1
  AND  user_id     = 101
  AND  status      IN ('pending', 'confirmed')
  AND  pickup_date > CURRENT_DATE
RETURNING booking_id, status;


-- =====================================================================
-- Q12: Owner's pending requests with renter and car details
-- NOTE: change users.name / users.user_id if your users table differs.
-- =====================================================================
-- READ
SELECT b.booking_id, u.name AS renter_name, c.brand, c.model,
       b.pickup_date, b.return_date, b.total_price
FROM   bookings b
JOIN   cars c  ON c.car_id  = b.car_id
JOIN   users u ON u.user_id = b.user_id
WHERE  c.owner_id = 50
  AND  b.status   = 'pending'
ORDER BY b.pickup_date ASC;


-- =====================================================================
-- Q13: Window function - rank cars by revenue within each city
-- =====================================================================
-- READ
SELECT ci.name AS city_name, c.car_id, c.brand, c.model,
       SUM(b.total_price) AS revenue,
       RANK() OVER (
           PARTITION BY ci.city_id
           ORDER BY SUM(b.total_price) DESC
       ) AS rank_in_city
FROM   bookings b
JOIN   cars c    ON c.car_id   = b.car_id
JOIN   cities ci ON ci.city_id = c.city_id
WHERE  b.status = 'confirmed'
GROUP BY ci.city_id, ci.name, c.car_id, c.brand, c.model
ORDER BY ci.name, rank_in_city;


-- =====================================================================
-- Q14: CTE - monthly revenue and month-over-month change
-- =====================================================================
-- READ
WITH monthly AS (
    SELECT DATE_TRUNC('month', b.pickup_date) AS month,
           SUM(b.total_price)                 AS revenue
    FROM   bookings b
    WHERE  b.status = 'confirmed'
    GROUP BY DATE_TRUNC('month', b.pickup_date)
)
SELECT month,
       revenue,
       revenue - LAG(revenue) OVER (ORDER BY month) AS change_vs_prev_month
FROM   monthly
ORDER BY month;
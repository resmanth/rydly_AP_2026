-- =====================================================================
-- CP3: Queries for Rydely Automotive Rental Platform
-- File: dbms/04_queries.sql
-- =====================================================================

-- 1. Search for available cars in a specific city with filters (e.g., Manual Transmission, SUV)
SELECT c.car_id, c.brand, c.model, c.year, c.price_per_day, ci.name AS city_name
FROM cars c
JOIN cities ci ON c.city_id = ci.city_id
WHERE ci.name = 'Delhi'
  AND c.is_available = TRUE
  AND c.category = 'SUV'
  AND c.transmission = 'Manual'
ORDER BY c.price_per_day ASC;

-- 2. Check strict date availability (Find cars NOT booked between specific dates)
SELECT c.car_id, c.brand, c.model, c.price_per_day
FROM cars c
JOIN cities ci ON c.city_id = ci.city_id
WHERE ci.name = 'Sonipat'
  AND c.is_available = TRUE
  AND c.car_id NOT IN (
      SELECT car_id 
      FROM bookings 
      WHERE status != 'cancelled'
        AND pickup_date <= '2026-12-10' 
        AND return_date >= '2026-12-05'
  );

-- 3. Insert a new booking (Pending Status)
INSERT INTO bookings (car_id, user_id, pickup_date, return_date, total_price, status)
VALUES (1, 101, '2026-12-05', '2026-12-10', 12500.00, 'pending');

-- 4. Get a specific user's booking history (with car details)
SELECT b.booking_id, c.brand, c.model, b.pickup_date, b.return_date, b.total_price, b.status
FROM bookings b
JOIN cars c ON b.car_id = c.car_id
WHERE b.user_id = 101
ORDER BY b.pickup_date DESC;

-- 5. Owner Dashboard: View all cars they own and their total revenue generated
SELECT c.car_id, c.brand, c.model, 
       COUNT(b.booking_id) AS total_bookings, 
       COALESCE(SUM(b.total_price), 0) AS total_revenue
FROM cars c
LEFT JOIN bookings b ON c.car_id = b.car_id AND b.status = 'confirmed'
WHERE c.owner_id = 50  -- Replace with specific owner ID
GROUP BY c.car_id, c.brand, c.model
ORDER BY total_revenue DESC;

-- 6. Update a booking status (e.g., Owner confirming a pending booking)
UPDATE bookings
SET status = 'confirmed'
WHERE booking_id = 1 AND status = 'pending';

-- 7. Analytics: Top 5 most booked car categories across the platform
SELECT c.category, COUNT(b.booking_id) AS booking_count
FROM cars c
JOIN bookings b ON c.car_id = b.car_id
WHERE b.status = 'confirmed'
GROUP BY c.category
ORDER BY booking_count DESC
LIMIT 5;

-- 8. Analytics: Total platform revenue grouped by city
SELECT ci.name AS city_name, SUM(b.total_price) AS total_city_revenue
FROM bookings b
JOIN cars c ON b.car_id = c.car_id
JOIN cities ci ON c.city_id = ci.city_id
WHERE b.status = 'confirmed'
GROUP BY ci.city_id, ci.name
ORDER BY total_city_revenue DESC;

-- 9. Toggle a car's availability (e.g., Owner takes car offline for maintenance)
UPDATE cars
SET is_available = FALSE
WHERE car_id = 1 AND owner_id = 50;

-- 10. Find upcoming confirmed trips for a specific user
SELECT b.booking_id, c.brand, c.model, ci.name AS city_name, b.pickup_date, b.return_date
FROM bookings b
JOIN cars c ON b.car_id = c.car_id
JOIN cities ci ON c.city_id = ci.city_id
WHERE b.user_id = 101 
  AND b.status = 'confirmed' 
  AND b.pickup_date >= CURRENT_DATE
ORDER BY b.pickup_date ASC;
-- CP2: schema for AP repo
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS cars CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS cities CASCADE;

CREATE TABLE cities (
city_id SERIAL PRIMARY KEY,
name VARCHAR(100) NOT NULL UNIQUE
);
CREATE TABLE users (
user_id SERIAL PRIMARY KEY,
name VARCHAR(100) NOT NULL,
email VARCHAR(255) NOT NULL UNIQUE,
password VARCHAR(255) NOT NULL, -- store a hash, never plain text
role VARCHAR(10) NOT NULL DEFAULT 'user'
CHECK (role IN ('user', 'owner')),
image_url TEXT,
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE cars (
car_id SERIAL PRIMARY KEY,
owner_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
city_id INTEGER NOT NULL REFERENCES cities(city_id),
brand VARCHAR(50) NOT NULL,
model VARCHAR(50) NOT NULL,
year INTEGER NOT NULL CHECK (year BETWEEN 1980 AND 2100),
category VARCHAR(30) NOT NULL, -- e.g. SUV, Sedan, Van
seating_capacity INTEGER NOT NULL CHECK (seating_capacity > 0),
fuel_type VARCHAR(20) NOT NULL, -- e.g. Petrol, Diesel, Electric
transmission VARCHAR(20) NOT NULL, -- e.g. Manual, Automatic
price_per_day NUMERIC(10,2) NOT NULL CHECK (price_per_day > 0),

description TEXT,

image_url TEXT,
is_available BOOLEAN NOT NULL DEFAULT TRUE,
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE bookings (
booking_id SERIAL PRIMARY KEY,
car_id INTEGER NOT NULL REFERENCES cars(car_id) ON DELETE CASCADE,
user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
pickup_date DATE NOT NULL,
return_date DATE NOT NULL,
total_price NUMERIC(10,2) NOT NULL CHECK (total_price >= 0),

status VARCHAR(10) NOT NULL DEFAULT 'pending'

CHECK (status IN ('pending', 'confirmed', 'cancelled')),

created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

CHECK (return_date >= pickup_date)

);


CREATE INDEX idx_cars_owner ON cars(owner_id);
CREATE INDEX idx_cars_city ON cars(city_id);
CREATE INDEX idx_bookings_car ON bookings(car_id);
CREATE INDEX idx_bookings_user ON bookings(user_id);
CREATE INDEX idx_bookings_dates ON bookings(pickup_date, return_date);
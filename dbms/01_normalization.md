# Normalization: Car Rental Application 

Application: a full stack car rental website. Users browse cars and book them for a date range. Any user can become an owner, list cars, and confirm or cancel bookings from an owner dashboard.

The data is stored in three MongoDB collections: `users`, `cars` and `bookings`. This document takes the data of the application through 1NF, 2NF and 3NF, and checks BCNF at the end. The functional dependencies (FDs) come from how the application works (which field identifies what). The sample values are illustrative and follow the demo of the application.

---

## 0. Data of the application

| Collection | Fields (as stored by the application) |
|---|---|
| users | _id, name, email (unique), password (hashed), role (`user` or `owner`, default `user`), image, createdAt, updatedAt |
| cars | _id, owner (reference to a user), brand, model, image, year, category, seating_capacity, fuel_type, transmission, pricePerDay, location, description, isAvailable (default true), createdAt, updatedAt |
| bookings | _id, car (reference), user (reference, the renter), owner (reference), pickupDate, returnDate, status (`pending`, `confirmed` or `cancelled`, default `pending`), price, createdAt, updatedAt |

Things the application shows but does not store as table data:

- Dashboard figures (total cars, total bookings, pending bookings, confirmed bookings, monthly revenue) are calculated from `cars` and `bookings` by queries.
- The booking price is calculated when the booking is created: `price = pricePerDay x number of days`.
- The list of cities, and the "Offline" payment label, are fixed values in the front end.
- The feature list on the Car Details page (360 camera, Bluetooth, GPS, heated seats, rear view mirror) is a fixed array in the front end. It is a many-valued attribute of a car, so it is included below as the repeating group that 1NF removes. It becomes a `car_features` table in the relational design.

Relational names used below: `_id` becomes `user_id`, `car_id`, `booking_id`; `pricePerDay` becomes `price_per_day`; `isAvailable` becomes `is_available`; `createdAt` becomes `created_at`.

---

## Part A: Cars, owners and features

### A.0 Unnormalized form (UNF)

The Car Details page shows one car together with its owner and its feature list:

```
CAR_PAGE(
  car_id, brand, model, image, year, category, seating_capacity, fuel_type, transmission,
  price_per_day, location, description, is_available,
  owner_id, owner_name, owner_email, owner_role, owner_image,
  { feature }                                  -- repeating group
)
```

Sample (two cars of the same owner):

| car_id | brand | model | year | category | seats | fuel_type | transmission | price_per_day | location | is_available | owner_id | owner_name | owner_email | { feature } |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| c1 | BMW | X5 | 2023 | SUV | 4 | Hybrid | Semi-Automatic | 300 | New York | true | u1 | Great Stack | test1@gmail.com | {360 Camera, Bluetooth, GPS, Heated Seats, Rear View Mirror} |
| c2 | Toyota | Camry | 2022 | Sedan | 5 | Petrol | Automatic | 120 | Los Angeles | true | u1 | Great Stack | test1@gmail.com | {360 Camera, Bluetooth, GPS, Heated Seats, Rear View Mirror} |

Problems:

- **Repeating group:** one car has several features in a single cell.
- **Redundancy:** the owner's name, email, role and image are repeated for every car the owner lists.
- **Update anomaly:** if the owner changes their profile image, every car row must change.
- **Insert anomaly:** a user who is an owner but has not listed a car yet cannot be stored.
- **Delete anomaly:** when the application removes an owner's last car, the owner's details go with it.

### A.1 First Normal Form (1NF)

Rules: every column holds one atomic value, there are no repeating groups, and every table has a key.

Change: the feature group becomes one row per (car, feature). The key of the flat table becomes **(car_id, feature)**.

```
CAR_PAGE_1NF(car_id, feature, brand, model, image, year, category, seating_capacity, fuel_type,
             transmission, price_per_day, location, description, is_available,
             owner_id, owner_name, owner_email, owner_role, owner_image)
KEY: (car_id, feature)
```

| car_id | feature | brand | model | price_per_day | owner_id | owner_name |
|---|---|---|---|---|---|---|
| c1 | 360 Camera | BMW | X5 | 300 | u1 | Great Stack |
| c1 | Bluetooth | BMW | X5 | 300 | u1 | Great Stack |
| c1 | GPS | BMW | X5 | 300 | u1 | Great Stack |
| c2 | 360 Camera | Toyota | Camry | 120 | u1 | Great Stack |

### A.2 Second Normal Form (2NF)

Rule: 1NF, and no non-key column depends on only part of a composite key.

FDs of `CAR_PAGE_1NF`:

- `car_id -> brand, model, image, year, category, seating_capacity, fuel_type, transmission, price_per_day, location, description, is_available, owner_id, owner_name, owner_email, owner_role, owner_image`. This depends on `car_id` only, which is part of the key: **partial dependency**.
- `(car_id, feature)` determines nothing else.

Decomposition:

```
CARS_2NF(car_id PK, brand, model, image, year, category, seating_capacity, fuel_type, transmission,
         price_per_day, location, description, is_available,
         owner_id, owner_name, owner_email, owner_role, owner_image)

CAR_FEATURES(car_id, feature)          KEY: (car_id, feature)
```

### A.3 Third Normal Form (3NF)

Rule: 2NF, and no non-key column depends on another non-key column (no transitive dependency).

In `CARS_2NF`:

- `car_id -> owner_id -> owner_name, owner_email, owner_role, owner_image`. The owner's details depend on the owner, not on the car: **transitive dependency**.

Decomposition:

```
users(user_id PK, name, email UNIQUE, password, role, image, created_at)
cars(car_id PK, owner_id FK -> users, brand, model, image, year, category, seating_capacity,
     fuel_type, transmission, price_per_day, location, description, is_available, created_at)
car_features(car_id FK -> cars, feature)       PK (car_id, feature)
```

Notes:

- An owner is a user whose `role = 'owner'`, so owners and renters are in the same `users` table.
- `cars.owner_id` can be NULL. When an owner removes a car, the application does not delete the row (past bookings still point to it). It sets `owner = null` and `is_available = false`.
- `category`, `fuel_type`, `transmission` and `location` have no dependency on each other in the application: owners choose each value freely from a drop-down. They stay as plain columns (with a CHECK constraint on the allowed values).

---

## Part B: Bookings

### B.0 Unnormalized form (UNF)

The My Bookings page (renter) and the Manage Bookings page (owner) show a booking together with the car and the people involved:

```
BOOKING_REPORT(
  booking_id, pickup_date, return_date, status, price, created_at,
  renter_id, renter_name, renter_email, renter_role, renter_image,
  car_id, brand, model, image, year, category, seating_capacity, fuel_type, transmission,
  price_per_day, location, description, is_available,
  owner_id, owner_name, owner_email, owner_role, owner_image
)
```

Sample:

| booking_id | pickup_date | return_date | status | price | renter_id | renter_name | car_id | brand | model | price_per_day | location | owner_id | owner_name |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| b1 | 2025-06-25 | 2025-06-27 | confirmed | 600 | u2 | Test Two | c1 | BMW | X5 | 300 | New York | u1 | Great Stack |
| b2 | 2025-07-01 | 2025-07-04 | pending | 360 | u2 | Test Two | c2 | Toyota | Camry | 120 | Los Angeles | u1 | Great Stack |

Problems: the renter, the car and the owner are copied into every booking. Changing a car's description or an owner's image means updating many rows. A car that nobody has booked yet cannot appear in this table.

### B.1 First Normal Form (1NF)

The table has no repeating groups. The rental period is stored as two atomic columns (`pickup_date`, `return_date`) and not as one text like "25 to 27 June". The key is `booking_id`.

### B.2 Second Normal Form (2NF)

The key is a single column, so no column can depend on part of it. The table is already in 2NF.

### B.3 Third Normal Form (3NF)

Transitive dependencies in `BOOKING_REPORT`:

| Chain | Meaning |
|---|---|
| `booking_id -> renter_id -> renter_name, renter_email, renter_role, renter_image` | renter details belong to the user |
| `booking_id -> car_id -> brand, model, image, year, category, seating_capacity, fuel_type, transmission, price_per_day, location, description, is_available` | car details belong to the car |
| `booking_id -> owner_id -> owner_name, owner_email, owner_role, owner_image` | owner details belong to the user |
| `car_id -> owner_id` | the owner of the car |

Decomposition (the user and car attributes go to `users` and `cars` from Part A):

```
bookings(booking_id PK, car_id FK -> cars, user_id FK -> users, owner_id FK -> users,
         pickup_date, return_date, status, price, created_at)
```

Two columns in `bookings` are deliberate exceptions to the pure 3NF rule:

- **`owner_id`:** `car_id -> owner_id` already gives the owner, so `bookings.owner_id` repeats it. It is kept because removing a car sets `cars.owner_id` to NULL. The booking would then lose the only link to the owner who must still see it on the dashboard.
- **`price`:** `price = price_per_day x (return_date - pickup_date)` can be calculated. It is kept as a snapshot, because an owner can change `price_per_day` later and old bookings must keep the price the renter agreed to. The monthly revenue on the dashboard is the sum of `price` of the confirmed bookings.

---

## Part C: BCNF check of the final tables

BCNF rule: for every non-trivial FD `X -> Y`, `X` must be a superkey.

| Table | Candidate keys | Non-trivial FDs | BCNF? |
|---|---|---|---|
| users | user_id, email | user_id -> all columns; email -> all columns | Yes |
| cars | car_id | car_id -> all columns | Yes |
| car_features | (car_id, feature) | none (all columns are the key) | Yes |
| bookings | booking_id | booking_id -> all columns; `car_id -> owner_id` is not an FD of this table's key, see B.3 | Yes, with the `owner_id` note in B.3 |

Business rules that are not FDs: the same car cannot have two overlapping bookings (checked by the "check availability" function before a booking is created), and `return_date` must be after `pickup_date`. These are enforced with constraints and application logic, not by normalization. In SQL: `CHECK (return_date > pickup_date)`.

One real-world dependency is not enforced: `(brand, model) -> category`. The application lets owners enter any brand, model and category, so this is not a dependency of the data, and a separate `car_models` table would add work without removing a real problem. If the business wanted a fixed catalogue of models, `car_models(brand, model, category)` would be the next step.

---

## Part D: Allowed values (domains)

| Column | Allowed values |
|---|---|
| users.role | `user`, `owner` (default `user`) |
| bookings.status | `pending`, `confirmed`, `cancelled` (default `pending`) |
| cars.category | Sedan, SUV, Van |
| cars.fuel_type | Gas, Diesel, Petrol, Electric, Hybrid |
| cars.transmission | Automatic, Manual, Semi-Automatic |
| cars.location | New York, Los Angeles, Houston, Chicago |

`role` and `status` are enums in the Mongoose schema. The other four are free strings in the schema and are limited only by the drop-downs of the Add Car form, so a CHECK constraint (or a lookup table) adds protection in the database.

---

## Part E: Final result

| Table | Primary key | Foreign keys | Normal form |
|---|---|---|---|
| users | user_id | none | BCNF |
| cars | car_id | owner_id -> users (nullable) | 3NF (BCNF: car_id is the only key) |
| car_features | (car_id, feature) | car_id -> cars | BCNF |
| bookings | booking_id | car_id -> cars, user_id -> users, owner_id -> users | 3NF, with `owner_id` and `price` kept on purpose |

Summary: the flat reports of the application (car page, booking report) were first converted to 1NF by removing the feature group and keeping the rental period as atomic dates. 2NF split the features away from the car, and 3NF removed the transitive dependencies through the owner, the renter and the car, which gives the four tables above. Dashboard figures are calculated from these tables and are not stored.

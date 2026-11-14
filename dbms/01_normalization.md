# Normalization: Google Maps Navigation Data

Source data: the 11 CSV files in `seed_data/` (cities, place_categories, places, opening_hours, users, place_reviews, saved_places, road_segments, traffic_readings, navigation_sessions, incident_reports).

Method: start from the wide, flat reports the product teams read (everything in one table), show the problems, then take the data through 1NF, 2NF, 3NF and BCNF. Every functional dependency (FD) below was checked against the seed data, not assumed.

---

## Part A: Navigation, users and places

### A.0 Unnormalized form (UNF)

One report row per navigation session, with everything the page needs:

```
NAV_REPORT(
  session_id, user_id, display_name, email, home_city_name, is_local_guide, guide_level,
  origin_place_id, origin_lat, origin_lng,
  dest_place_id, dest_name, dest_plus_code, dest_phone, dest_website, dest_address,
  dest_category_name, dest_city_name, dest_price_level, dest_avg_rating, dest_review_count,
  dest_is_permanently_closed,
  { weekday, opens, closes },                                   -- repeating group
  { review_id, reviewer_id, rating, review_text, photo_count, review_created_at },  -- repeating group
  travel_mode, started_at, distance_km, eta_minutes, actual_minutes, rerouted_count, status
)
```

Real data, session 1:

| Column | Value |
|---|---|
| session_id | 1 |
| user_id / display_name / email | 5997 / Tanvi S. / tanvi.shah5997@gmail.com |
| home_city_name / is_local_guide / guide_level | Chennai / f / NULL |
| origin_place_id / origin_lat, origin_lng | NULL / 18.536584, 73.917604 |
| dest_place_id / dest_name | 27324 / Coastal Kitchen 27324 |
| dest_plus_code / dest_address | 2222225C+86 / 25, Market Street, Pune 411024 |
| dest_category_name / dest_city_name | Restaurant / Pune |
| dest_avg_rating / dest_review_count | 5.0 / 1 |
| { weekday, opens, closes } | {(1, 11:00, 23:00), (2, 11:00, 23:00), (3, 11:00, 23:00), ... 7 entries} |
| travel_mode / started_at | DRIVE / 2025-01-01 00:00:00+05:30 |
| distance_km / eta_minutes / actual_minutes | 13.25 / 40 / 37 |
| rerouted_count / status | 0 / COMPLETED |

Problems with this design:

- **Redundancy:** 200,000 sessions repeat the full user and place details. Place 27324's name, address and category are copied into every session that goes there.
- **Update anomaly:** if a place's rating or address changes, every session row mentioning it must change.
- **Insert anomaly:** a place that nobody has navigated to yet cannot be stored. In the seed data 779 of 40,042 places are never a destination.
- **Delete anomaly:** deleting a user's only session deletes the user's name, email and Local Guide level too.
- **Repeating groups:** opening hours (up to 7 per place) and reviews (many per place) do not fit in one row.

### A.1 First Normal Form (1NF)

Rules: every column holds one atomic value, there are no repeating groups, and the table has a key.

Changes:

1. The opening-hours group becomes one row per (place, weekday). The row now repeats per weekday, so the key of the flat table becomes **(session_id, weekday)**.
2. The review group is moved out into its own relation (`place_reviews`), one row per review.
3. Saved lists (a user keeps a place in lists such as Favourites or Want to go) are also a many-valued attribute of user and place, so they get their own relation (`saved_places`).
4. `address` (e.g. `25, Market Street, Pune 411024`) contains house number, street, city and pincode. It is kept as one text value because the product only displays and searches it as a whole. This is the one deliberate exception to atomicity (see A.3).

```
NAV_1NF(session_id, weekday, user_id, display_name, email, home_city_name, is_local_guide, guide_level,
        origin_place_id, origin_lat, origin_lng,
        dest_place_id, dest_name, dest_plus_code, dest_phone, dest_website, dest_address,
        dest_category_name, dest_city_name, dest_price_level, dest_avg_rating, dest_review_count,
        dest_is_permanently_closed, opens, closes,
        travel_mode, started_at, distance_km, eta_minutes, actual_minutes, rerouted_count, status)
KEY: (session_id, weekday)

PLACE_REVIEWS_1NF(review_id, place_id, user_id, rating, review_text, photo_count, created_at)
KEY: review_id            candidate key: (place_id, user_id)

SAVED_PLACES_1NF(user_id, place_id, list_name, saved_at)
KEY: (user_id, place_id, list_name)
```

The key of `saved_places` needs all three columns: in the seed data one user saved the same place into two different lists.

### A.2 Second Normal Form (2NF)

Rule: 1NF, and no non-key column depends on only part of a composite key.

The only composite key is (session_id, weekday) in `NAV_1NF`. Functional dependencies:

- `session_id -> user_id, origin_*, dest_place_id, travel_mode, started_at, distance_km, eta_minutes, actual_minutes, rerouted_count, status` (and through them everything about the user and the destination place). Depends on part of the key only: **partial dependency**.
- `dest_place_id, weekday -> opens, closes` (the hours belong to a place and a weekday, not to a session). Depends on `weekday` plus a column that `session_id` determines: **partial dependency** on the key.

Decomposition:

```
SESSION_2NF(session_id, user_id, display_name, email, home_city_name, is_local_guide, guide_level,
            origin_place_id, origin_lat, origin_lng,
            dest_place_id, dest_name, dest_plus_code, dest_phone, dest_website, dest_address,
            dest_category_name, dest_city_name, dest_price_level, dest_avg_rating, dest_review_count,
            dest_is_permanently_closed,
            travel_mode, started_at, distance_km, eta_minutes, actual_minutes, rerouted_count, status)
KEY: session_id

OPENING_HOURS(place_id, weekday, opens, closes)
KEY: (place_id, weekday)
```

`place_reviews` and `saved_places` already have the key described in A.1 and no partial dependencies (`place_reviews` has the single-column key `review_id`; in `saved_places` the only non-key column `saved_at` depends on all three key columns).

### A.3 Third Normal Form (3NF)

Rule: 2NF, and no non-key column depends on another non-key column (no transitive dependency).

Transitive dependencies found in `SESSION_2NF`:

| Dependency chain | Evidence |
|---|---|
| `session_id -> user_id -> display_name, email, home_city, is_local_guide, guide_level, created_at` | email determines user (40,000 distinct) |
| `user_id -> home_city_id -> home_city_name` | city name belongs to the city |
| `session_id -> dest_place_id -> name, plus_code, phone, website, address, category_id, city_id, lat, lng, price_level, avg_rating, review_count, is_permanently_closed, created_at` | place data belongs to the place |
| `dest_place_id -> category_id -> category_name` | 12 categories |
| `dest_place_id -> city_id -> city_name` | 10 cities |
| `session_id -> origin_place_id -> origin_lat, origin_lng` (when an origin place is set) | for all 7,416 sessions that have an origin place, the origin coordinates equal that place's coordinates |

Decomposition into 3NF (these are the tables of the implemented schema in `sql/01_schema.sql`):

```
cities(city_id PK, city_name, center_lat, center_lng)
place_categories(category_id PK, category_name)
places(place_id PK, plus_code, name, category_id FK, city_id FK, latitude, longitude, address, phone,
       website, price_level, avg_rating, review_count, is_permanently_closed, created_at)
opening_hours(place_id FK, weekday, opens, closes)          PK (place_id, weekday)
users(user_id PK, display_name, email, home_city_id FK, is_local_guide, guide_level, created_at)
place_reviews(review_id PK, place_id FK, user_id FK, rating, review_text, photo_count, created_at)
saved_places(user_id FK, place_id FK, list_name, saved_at)  PK (user_id, place_id, list_name)
navigation_sessions(session_id PK, user_id FK NULL, origin_place_id FK NULL, origin_lat, origin_lng,
                    dest_place_id FK, travel_mode, started_at, distance_km, eta_minutes,
                    actual_minutes NULL, rerouted_count, status)
```

The decomposition is lossless (every split is on a key that is kept as a foreign key in the child table) and dependency-preserving (each FD above lives entirely inside one table).

Two honest notes on `places`:

- **`address -> city_id`.** The address ends with the city name and a pincode. In the seed data the city name in the address equals the city of `city_id` for 100% of places, and each of the 100 pincodes belongs to one city. So `place_id -> address -> city_id` is a transitive dependency. We keep `city_id` in `places` because `address` is free text, and every search ("Bengaluru places...") filters by `city_id` and needs it to be a real column. The risk is an inconsistent update (changing the address but not the city); it is not enforced by a constraint.
- **`price_level`** is NULL for every non-restaurant place (26,667 NULLs, all categories except Restaurant). This is a dependency on `category_id` that only holds for one category, so it is a legitimate optional attribute and not a normalization violation.

---

## Part B: Roads, traffic and incidents

### B.0 UNF

```
ROAD_REPORT(
  segment_id, road_name, city_name, road_type, speed_limit_kmph,
  start_lat, start_lng, end_lat, end_lng, length_m,
  { reading_id, recorded_at, avg_speed_kmph, congestion_level },                 -- repeating group
  { report_id, reporter_id, incident_type, reported_at, expires_at, upvotes }    -- repeating group
)
```

Real data, segment 1: `MG Road (Segment 2)`, Bengaluru, ARTERIAL, speed limit 50, length 1650 m, with many readings (e.g. reading 1 on segment 454: 2025-01-01 00:00:00+05:30, 29.5 km/h, LOW) and many incident reports.

Anomalies: a new segment with no readings yet cannot be stored in a readings row (insert); the road name, city and limit are repeated in each of the 250,000 readings (redundancy, update); two independent repeating groups in one row force a cross-product of readings and incidents.

### B.1 1NF

Both repeating groups become their own tables, one row per reading and one row per incident:

```
ROAD_SEGMENTS_1NF(segment_id, road_name, city_name, road_type, speed_limit_kmph, start_lat, start_lng, end_lat, end_lng, length_m)
TRAFFIC_READINGS_1NF(reading_id, segment_id, recorded_at, avg_speed_kmph, congestion_level)
INCIDENT_REPORTS_1NF(report_id, segment_id, user_id, incident_type, reported_at, expires_at, upvotes)
```

Keys: `segment_id`, `reading_id`, `report_id`.

### B.2 2NF

Every table has a single-column key, so no non-key column can depend on part of a key. All three tables are in 2NF.

### B.3 3NF

Transitive dependencies in `ROAD_SEGMENTS_1NF`:

- `segment_id -> city_name`, but really `segment_id -> city_id -> city_name`. Use the `cities` table.
- `segment_id -> road_type -> speed_limit_kmph`. In the seed data ARTERIAL is always 50, HIGHWAY is always 80, LOCAL is always 30, across all 2,000 segments. The speed limit depends on the road type, not on the segment.
- `road_name` does not determine `city_id`: the 20 base road names (e.g. "MG Road") repeat across up to 3 cities, and the "(Segment n)" suffix only numbers the segment. So road name cannot be split out as its own entity.

3NF result:

```
cities(city_id PK, ...)                               -- shared with Part A
road_types(road_type PK, speed_limit_kmph)            -- 3 rows: ARTERIAL 50, HIGHWAY 80, LOCAL 30
road_segments(segment_id PK, road_name, city_id FK, road_type FK, start_lat, start_lng, end_lat, end_lng, length_m)
traffic_readings(reading_id PK, segment_id FK, recorded_at, avg_speed_kmph, congestion_level)
incident_reports(report_id PK, segment_id FK, user_id FK, incident_type, reported_at, expires_at, upvotes)
```

Decision for the implemented schema: the project's 30 queries (for example R25) read `speed_limit_kmph` straight from `road_segments`, and the task requires the exact column names of the CSV files. So `sql/01_schema.sql` keeps `speed_limit_kmph` in `road_segments` and does not create a `road_types` table. This is a deliberate, documented denormalization. The cost is a possible inconsistency (two LOCAL segments with different limits); the benefit is one less join in the traffic reports.

---

## Part C: BCNF check of the implemented tables

BCNF rule: for every non-trivial FD `X -> Y`, `X` must be a superkey.

| Table | Candidate keys | Non-trivial FDs | BCNF? |
|---|---|---|---|
| cities | city_id, city_name | city_id -> all | Yes |
| place_categories | category_id, category_name | category_id -> category_name | Yes |
| places | place_id, plus_code, phone, website | place_id -> all (each key determines all) | Yes, except the `address -> city_id` note in A.3 |
| opening_hours | (place_id, weekday) | (place_id, weekday) -> opens, closes | Yes |
| users | user_id, email | user_id -> all; `guide_level -> is_local_guide` (see below) | Yes, with one note |
| place_reviews | review_id, (place_id, user_id) | review_id -> all | Yes |
| saved_places | (user_id, place_id, list_name) | key -> saved_at | Yes |
| road_segments | segment_id | segment_id -> all; `road_type -> speed_limit_kmph` | No, accepted (see B.3) |
| traffic_readings | reading_id | reading_id -> all | Yes |
| navigation_sessions | session_id | session_id -> all | Yes |
| incident_reports | report_id | report_id -> all | Yes |

`users` note: every non-NULL `guide_level` belongs to a user with `is_local_guide = true`, and every user with `is_local_guide = true` has a level (3,912 of 40,000 users). So `is_local_guide` is derivable from whether `guide_level` is NULL. The schema keeps both columns and enforces the link with a CHECK constraint.

---

## Part D: Derived and redundant columns

| Column | Derived from | Keep it? |
|---|---|---|
| `places.avg_rating`, `places.review_count` | average and count of `place_reviews` for the place | Yes. Place pages and searches read them on every request. A nightly job (W04) recomputes them. Cost: they go stale; in the seed data 558 of 40,042 places have a `review_count` that no longer matches their reviews. |
| `traffic_readings.congestion_level` | `avg_speed_kmph` compared with the segment's speed limit | Yes. The live-traffic and alert queries filter on it. It is not a clean function of speed alone (the speed ranges of LOW, MODERATE and HEAVY overlap), so it is stored data from the traffic feed. |
| `navigation_sessions.eta_minutes` | distance and travel mode | Yes. It is the prediction made at the start of the trip; it must be stored to compare with `actual_minutes` (ETA quality reports). |
| `navigation_sessions.origin_lat/lng` | `places.latitude/longitude` when `origin_place_id` is set | Yes. For sessions started from GPS there is no origin place, so the coordinates are the only origin. For the 7,416 sessions with an origin place they duplicate the place's coordinates. |
| `road_segments.speed_limit_kmph` | `road_type` | Kept, see B.3. |
| `users.is_local_guide` | `guide_level IS NOT NULL` | Kept, protected by a CHECK constraint. |

---

## Part E: Final result

| Table | Primary key | Normal form |
|---|---|---|
| cities | city_id | BCNF |
| place_categories | category_id | BCNF |
| places | place_id | 3NF (BCNF apart from `address -> city_id`) |
| opening_hours | (place_id, weekday) | BCNF |
| users | user_id | BCNF (flag derivable from level, CHECK-protected) |
| place_reviews | review_id | BCNF |
| saved_places | (user_id, place_id, list_name) | BCNF |
| road_segments | segment_id | 2NF (not 3NF on purpose: `road_type -> speed_limit_kmph` kept) |
| traffic_readings | reading_id | BCNF |
| navigation_sessions | session_id | BCNF |
| incident_reports | report_id | BCNF |

Summary: starting from two flat reports, 1NF removed the repeating groups (opening hours, reviews, saved lists, readings, incidents), 2NF separated session data from per-weekday hours, and 3NF removed the transitive dependencies through user, place, category, city and road type. The implemented 11-table schema is in 3NF except for two small, documented denormalizations (`places.address` containing the city, and `road_segments.speed_limit_kmph`), which are kept on purpose for query speed and to match the CSV column names.
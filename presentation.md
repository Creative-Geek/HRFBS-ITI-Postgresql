# Hotel Reservation & Flight Booking System

> ITI Database Project — PostgreSQL

---

## Slide 1 — Introduction

**Project:** Hotel Reservation & Flight Booking System

A relational database that handles:

- User registration and role management
- Hotel and room inventory
- Flight and seat inventory
- Hotel bookings with date-range conflict prevention
- Flight bookings with seat assignment
- Unified payment tracking
- Reviews and ratings for hotels and airlines

**Tech:** PostgreSQL, SQL

**Files:**
| File | Purpose |
|---|---|
| `schema.sql` | Table definitions, constraints, triggers |
| `seed.sql` | Sample data (6 customers, 5 hotels, 4 airlines, 8 flights, etc.) |
| `queries.sql` | 12 report-style queries |

---

## Slide 2 — Entity Extraction

Reading the requirements document, we identified the following entities:

| Entity              | Key Attributes                                            | Source Requirement |
| ------------------- | --------------------------------------------------------- | ------------------ |
| **Users**           | name, email, phone, password, role                        | User Management    |
| **Hotels**          | name, location, rating, description                       | Hotel Management   |
| **Rooms**           | type, price_per_night (belongs to Hotel)                  | Hotel Management   |
| **Airlines**        | name                                                      | Flight Management  |
| **Flights**         | departure/arrival city & time, price (belongs to Airline) | Flight Management  |
| **Seats**           | seat_number (belongs to Flight)                           | Flight Booking     |
| **Hotel Bookings**  | check_in, check_out, total_cost, status                   | Hotel Booking      |
| **Flight Bookings** | seat_id, status                                           | Flight Booking     |
| **Payments**        | amount, method, date (links to one booking)               | Payment System     |
| **Reviews**         | rating, comment (links to hotel or airline)               | Reviews & Ratings  |

**10 tables total** — no M:M junction tables needed; every relationship is 1:M resolved directly by foreign keys.

---

## Slide 3 — ERD (Full Diagram)

> Rendered via the Mermaid live editor from `erd.md`

<!-- Paste the ERD screenshot here -->

**Relationships at a glance:**

- `Users` 1:M `Hotel Bookings`, `Flight Bookings`, `Reviews`
- `Hotels` 1:M `Rooms`, `Reviews`
- `Rooms` 1:M `Hotel Bookings`
- `Airlines` 1:M `Flights`, `Reviews`
- `Flights` 1:M `Seats`, `Flight Bookings`
- `Seats` 1:M `Flight Bookings`
- `Hotel Bookings` 1:1 `Payments` (optional)
- `Flight Bookings` 1:1 `Payments` (optional)

**Constraint highlights:**

- Payments & Reviews use the **nullable FK pattern** — exactly one of two FKs must be set
- Room double-booking is blocked by a **BEFORE INSERT trigger**
- Seat double-booking is blocked by a **partial UNIQUE index** (`WHERE status != 'cancelled'`)
- Room/seat availability is **derived**, never stored as a boolean

---

## Slide 4 — Query 1: Hotel Revenue Report

**Business question:** How much has each hotel made from confirmed bookings?

**Who benefits:** Management — decide where to invest or expand.

**SQL concepts:** `JOIN`, `GROUP BY`, `SUM`, `AVG`, `ORDER BY`

```sql
SELECT
    h.name                       AS hotel,
    h.location,
    COUNT(hb.booking_id)         AS total_bookings,
    SUM(hb.total_cost)           AS total_revenue,
    ROUND(AVG(hb.total_cost), 2) AS avg_booking_value
FROM hotels h
JOIN rooms r           ON h.hotel_id  = r.hotel_id
JOIN hotel_bookings hb ON r.room_id   = hb.room_id
WHERE hb.status != 'cancelled'
GROUP BY h.hotel_id, h.name, h.location
ORDER BY total_revenue DESC;
```

**Result:**

<!-- query_01.png -->

Burj Al Arab leads with $9,000 in revenue. Nile Ritz-Carlton has the most bookings (4) but at a lower price point.

---

## Slide 5 — Query 2: Available Rooms Search

**Business question:** Which rooms are free in Cairo between Apr 1 and May 1?

**Who benefits:** Customers — core hotel search functionality.

**SQL concepts:** `JOIN`, subquery with `NOT IN`, date range overlap logic

```sql
SELECT
    r.room_id,
    h.name           AS hotel,
    r.type,
    r.price_per_night
FROM rooms r
JOIN hotels h ON r.hotel_id = h.hotel_id
WHERE h.location = 'Cairo'
  AND r.room_id NOT IN (
      SELECT room_id
      FROM hotel_bookings
      WHERE status != 'cancelled'
        AND check_in  < '2025-05-01'
        AND check_out > '2025-04-01'
  )
ORDER BY r.price_per_night;
```

**Result:**

<!-- query_02.png -->

Rooms 1 (single) and 2 (double) are available. Room 3 (suite, booked Apr 20-25) is excluded because it overlaps.

---

## Slide 6 — Query 3: Top Spenders (Hotel + Flight Combined)

**Business question:** Who is spending the most across both booking types?

**Who benefits:** Marketing — loyalty programs, VIP targeting.

**SQL concepts:** `CTE` (3 levels), `COALESCE`, `LEFT JOIN`, `RANK()` window function

```sql
WITH hotel_spend AS (...),
     flight_spend AS (...),
     combined AS (...)
SELECT name, hotel_spend, flight_spend, total_spent,
       RANK() OVER (ORDER BY total_spent DESC) AS spending_rank
FROM combined
ORDER BY spending_rank;
```

**Result:**

<!-- query_03.png -->

Dina Samir is the top spender at $8,050 total. All 6 customers ranked by combined spend.

---

## Slide 7 — Query 4: Flight Occupancy Report

**Business question:** For each flight, how full is it?

**Who benefits:** Airlines — decide whether to add or cancel flights.

**SQL concepts:** `JOIN`, `LEFT JOIN`, `GROUP BY`, calculated `occupancy_pct`, type casting

```sql
SELECT
    al.name                            AS airline,
    f.departure_city || ' -> ' || f.arrival_city AS route,
    f.departure_time::date             AS departure_date,
    COUNT(s.seat_id)                   AS total_seats,
    COUNT(fb.booking_id)               AS booked_seats,
    COUNT(s.seat_id) - COUNT(fb.booking_id) AS available_seats,
    ROUND(COUNT(fb.booking_id)::NUMERIC / COUNT(s.seat_id) * 100, 1) AS occupancy_pct
FROM flights f
JOIN airlines al             ON f.airline_id = al.airline_id
JOIN seats s                 ON f.flight_id  = s.flight_id
LEFT JOIN flight_bookings fb ON s.seat_id    = fb.seat_id AND fb.status != 'cancelled'
GROUP BY f.flight_id, al.name, f.departure_city, f.arrival_city, f.departure_time
ORDER BY occupancy_pct DESC;
```

**Result:**

<!-- query_04.png -->

Cairo->Dubai and Dubai->Paris lead at 25% occupancy. London->Cairo has zero bookings.

---

## Slide 8 — Query 5: Hotel Satisfaction Ranking

**Business question:** Which hotels are guests actually happy with?

**Who benefits:** Management — quality control and marketing.

**SQL concepts:** `CTE`, `JOIN`, `AVG`, `COUNT`, `RANK()` window function with tiebreaker

```sql
WITH hotel_ratings AS (...)
SELECT name, location, total_reviews, avg_rating,
       RANK() OVER (ORDER BY avg_rating DESC, total_reviews DESC) AS rating_rank
FROM hotel_ratings
ORDER BY rating_rank;
```

**Result:**

<!-- query_05.png -->

Burj Al Arab leads with a perfect 5.0. Nile Ritz-Carlton and Le Meurice both average 4.5 but Nile Ritz ranks higher (4 reviews vs 2). The Plaza has no reviews and doesn't appear.

---

## Slide 9 — Query 6: Monthly Revenue Breakdown

**Business question:** How much came in each month, split by hotel vs flight?

**Who benefits:** Finance — track revenue streams and seasonal trends.

**SQL concepts:** `CTE`, `UNION ALL`, `TO_CHAR`, `SUM` window function with `PARTITION BY`

```sql
WITH monthly AS (
    SELECT TO_CHAR(...) AS month, 'hotel' AS booking_type, SUM(amount) AS revenue ...
    UNION ALL
    SELECT TO_CHAR(...) AS month, 'flight' AS booking_type, SUM(amount) AS revenue ...
)
SELECT month, booking_type, revenue,
       SUM(revenue) OVER (PARTITION BY month) AS total_monthly_revenue
FROM monthly ORDER BY month, booking_type;
```

**Result:**

<!-- query_06.png -->

June is the busiest month ($6,440 combined). Hotels dominate every month; flight revenue starts in May.

---

## Slide 10 — Query 7: Top Flight Routes

**Business question:** Which routes get the most bookings and revenue?

**Who benefits:** Airlines — capacity planning and marketing focus.

**SQL concepts:** `LEFT JOIN`, `GROUP BY`, `SUM`, `AVG`, string concatenation

```sql
SELECT
    f.departure_city || ' -> ' || f.arrival_city AS route,
    COUNT(fb.booking_id)   AS total_bookings,
    SUM(p.amount)          AS total_revenue,
    ROUND(AVG(f.price), 2) AS avg_ticket_price
FROM flights f
LEFT JOIN flight_bookings fb ON ...
LEFT JOIN payments p         ON ...
GROUP BY f.departure_city, f.arrival_city
ORDER BY total_bookings DESC, total_revenue DESC;
```

**Result:**

<!-- query_07.png -->

Dubai->Paris and Cairo->Dubai lead with 2 bookings each. London->Cairo has zero.

---

## Slide 11 — Query 8: Cross-Bookers (Hotel + Flight)

**Business question:** Which customers booked both a hotel and a flight?

**Who benefits:** Marketing — bundling and cross-sell campaigns.

**SQL concepts:** Subquery, `INTERSECT`, `IN`

```sql
SELECT u.name, u.email
FROM users u
WHERE u.user_id IN (
    SELECT user_id FROM hotel_bookings  WHERE status != 'cancelled'
    INTERSECT
    SELECT user_id FROM flight_bookings WHERE status != 'cancelled'
);
```

**Result:**

<!-- query_08.png -->

All 6 customers have both hotel and flight bookings — strong cross-sell engagement.

---

## Slide 12 — Query 9: Booking Status Breakdown

**Business question:** What's the ratio of confirmed/pending/cancelled across both booking types?

**Who benefits:** Operations — system health check.

**SQL concepts:** `UNION ALL`, `GROUP BY`, `COUNT`, `SUM`

```sql
SELECT 'hotel' AS booking_type, status, COUNT(*), SUM(total_cost)
FROM hotel_bookings GROUP BY status
UNION ALL
SELECT 'flight' AS booking_type, status, COUNT(*), SUM(f.price)
FROM flight_bookings fb JOIN flights f ON ... GROUP BY status
ORDER BY booking_type, status;
```

**Result:**

<!-- query_09.png -->

Hotels: 9 confirmed ($17,890), 2 pending ($5,500), 1 cancelled ($5,000). Flights: 8 confirmed, 1 pending, 1 cancelled.

---

## Slide 13 — Query 10: Payment Method Analysis

**Business question:** Which payment method brings in the most money?

**Who benefits:** Finance — optimize payment partnerships and processing fees.

**SQL concepts:** `GROUP BY`, nested `SUM() OVER()` window function for percentage calculation

```sql
SELECT
    method,
    COUNT(*)       AS transactions,
    SUM(amount)    AS total_revenue,
    ROUND(SUM(amount) / SUM(SUM(amount)) OVER () * 100, 1) AS revenue_pct
FROM payments GROUP BY method ORDER BY total_revenue DESC;
```

**Result:**

<!-- query_10.png -->

Credit card dominates at 58.4% of revenue. Online is second (32.6%), cash is minimal (9.0%).

---

## Slide 14 — Query 11: Cumulative Revenue Over Time

**Business question:** What does the day-by-day revenue growth look like?

**Who benefits:** Finance/Executives — track overall growth trajectory.

**SQL concepts:** `GROUP BY`, nested `SUM() OVER(ORDER BY ...)` for running total

```sql
SELECT
    payment_date,
    SUM(amount)                                   AS daily_revenue,
    SUM(SUM(amount)) OVER (ORDER BY payment_date) AS running_total
FROM payments GROUP BY payment_date ORDER BY payment_date;
```

**Result:**

<!-- query_11.png -->

Running total grows from $480 (Jan 9) to $26,850 (Jul 9). Largest single-day spike: $4,760 on Jun 9.

---

## Slide 15 — Query 12: Full Customer Booking History

**Business question:** Every booking a customer ever made, hotel or flight, in one unified list?

**Who benefits:** Customer support — account statements and history lookup.

**SQL concepts:** `UNION ALL`, multi-table `JOIN`, type casting, `ORDER BY` across union

```sql
SELECT u.name AS customer, 'Hotel' AS booking_type, h.name AS destination,
       hb.check_in::text AS travel_date, hb.total_cost AS amount, hb.status
FROM users u JOIN hotel_bookings hb ON ... JOIN rooms r ON ... JOIN hotels h ON ...
UNION ALL
SELECT u.name, 'Flight', f.departure_city || ' -> ' || f.arrival_city,
       f.departure_time::date::text, f.price, fb.status
FROM users u JOIN flight_bookings fb ON ... JOIN flights f ON ...
ORDER BY customer, travel_date;
```

**Result:**

<!-- query_12.png -->

22 rows total, sorted by customer name then date. Every booking (hotel + flight) in chronological order per customer.

---

## Slide 16 — Decisions & Problems Solved

### Nullable FK Pattern (Payments & Reviews)

One table instead of two. A `CHECK` constraint ensures exactly one FK is set. Reused for both `payments` and `reviews`.

### Availability Is Derived, Not Stored

No `is_available` boolean anywhere. Room availability = no overlapping active bookings. Seat availability = count of unbooked seats. Always correct, zero maintenance.

### Double Booking Prevention

- **Rooms:** `BEFORE INSERT OR UPDATE` trigger checks for date-range overlaps. We chose a trigger over `EXCLUDE USING GIST` to avoid requiring the `btree_gist` extension (portability for grading).
- **Seats:** Partial unique index (`WHERE status != 'cancelled'`). Cancelling frees the seat automatically.

### total_cost Is Stored, Not Computed

If room prices change later, historical bookings still show what was actually charged. Correct behavior for anything financial.

### Seats Are Pre-Populated

Every seat exists as a row at flight creation time. Bookings claim seats via FK. Makes "select your seat" queries trivial.

### TIMESTAMPTZ Over DATE for Flights

A flight time without a timezone is meaningless. `TIMESTAMPTZ` stores UTC internally and handles conversion correctly.

---

## Slide 17 — SQL Concepts Used

| Concept                               | Queries                                  |
| ------------------------------------- | ---------------------------------------- |
| `JOIN` (INNER)                        | 1, 2, 3, 4, 5, 6, 7, 8, 9, 12            |
| `LEFT JOIN`                           | 3, 4, 7                                  |
| `GROUP BY`                            | 1, 4, 5, 6, 7, 9, 10, 11                 |
| `HAVING` / Filtering aggregates       | 3 (via CTE + WHERE)                      |
| `UNION ALL`                           | 6, 9, 12                                 |
| `INTERSECT`                           | 8                                        |
| `CTE` (WITH)                          | 3, 5, 6                                  |
| Window functions (`RANK`, `SUM OVER`) | 3, 5, 6, 10, 11                          |
| Subquery                              | 2                                        |
| `CHECK` constraints                   | schema-wide                              |
| Triggers                              | room double-booking                      |
| Partial unique indexes                | seat double-booking, one review per user |
| Type casting (`::date`, `::numeric`)  | 4, 11, 12                                |

---

## Slide 18 — Thank You

**Hotel Reservation & Flight Booking System**

Thank you for your time and attention.

**Files delivered:**

- `schema.sql` — full database schema with constraints and triggers
- `seed.sql` — realistic sample data
- `queries.sql` — 12 report-style SQL queries
- `erd.md` — Mermaid ERD matching the schema
- `decisions.md` — design rationale for every non-obvious choice

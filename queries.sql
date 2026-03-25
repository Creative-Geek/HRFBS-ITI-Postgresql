-- queries for the hotel reservation & flight booking system
-- all report-style, meant to answer real business questions
-- run schema.sql then seed.sql before running any of these


-- 1. how much has each hotel made from confirmed bookings?
-- good for deciding where to invest or expand

SELECT
    h.name                          AS hotel,
    h.location,
    COUNT(hb.booking_id)            AS total_bookings,
    SUM(hb.total_cost)              AS total_revenue,
    ROUND(AVG(hb.total_cost), 2)    AS avg_booking_value
FROM hotels h
JOIN rooms r           ON h.hotel_id  = r.hotel_id
JOIN hotel_bookings hb ON r.room_id   = hb.room_id
WHERE hb.status != 'cancelled'
GROUP BY h.hotel_id, h.name, h.location
ORDER BY total_revenue DESC;

-- burj al arab and le meurice should lead, nile ritz has more bookings but lower price point


-- 2. which rooms are free in Cairo between Apr 1 and May 1?
-- this is the core search a customer would run, change the location and dates to search any window

SELECT
    r.room_id,
    h.name              AS hotel,
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

-- rooms 1 and 2 are available (their bookings were jan-mar, no overlap)
-- room 3 (suite) is booked apr 20-25, overlaps the window so it's excluded


-- 3. who is spending the most across hotels AND flights combined?
-- useful for loyalty programs or vip targeting
-- two CTEs aggregate spend per source, a third merges them before ranking

WITH hotel_spend AS (
    SELECT hb.user_id, SUM(p.amount) AS amount
    FROM hotel_bookings hb
    JOIN payments p ON p.hotel_booking_id = hb.booking_id
    GROUP BY hb.user_id
),
flight_spend AS (
    SELECT fb.user_id, SUM(p.amount) AS amount
    FROM flight_bookings fb
    JOIN payments p ON p.flight_booking_id = fb.booking_id
    GROUP BY fb.user_id
),
combined AS (
    SELECT
        u.name,
        COALESCE(hs.amount, 0)                           AS hotel_spend,
        COALESCE(fs.amount, 0)                           AS flight_spend,
        COALESCE(hs.amount, 0) + COALESCE(fs.amount, 0) AS total_spent
    FROM users u
    LEFT JOIN hotel_spend  hs ON u.user_id = hs.user_id
    LEFT JOIN flight_spend fs ON u.user_id = fs.user_id
    WHERE u.role = 'customer'
      AND (hs.amount IS NOT NULL OR fs.amount IS NOT NULL)
)
SELECT
    name,
    hotel_spend,
    flight_spend,
    total_spent,
    RANK() OVER (ORDER BY total_spent DESC) AS spending_rank
FROM combined
ORDER BY spending_rank;

-- dina and layla should be near the top with those suite bookings


-- 4. for each flight, how full is it?
-- helps airlines decide whether to add or cancel flights

SELECT
    al.name                                                            AS airline,
    f.departure_city || ' -> ' || f.arrival_city                      AS route,
    f.departure_time::date                                            AS departure_date,
    COUNT(s.seat_id)                                                  AS total_seats,
    COUNT(fb.booking_id)                                              AS booked_seats,
    COUNT(s.seat_id) - COUNT(fb.booking_id)                           AS available_seats,
    ROUND(COUNT(fb.booking_id)::NUMERIC / COUNT(s.seat_id) * 100, 1) AS occupancy_pct
FROM flights f
JOIN airlines al             ON f.airline_id = al.airline_id
JOIN seats s                 ON f.flight_id  = s.flight_id
LEFT JOIN flight_bookings fb ON s.seat_id    = fb.seat_id AND fb.status != 'cancelled'
GROUP BY f.flight_id, al.name, f.departure_city, f.arrival_city, f.departure_time
ORDER BY occupancy_pct DESC;

-- cairo->dubai and dubai->paris have 2 bookings each so they lead on occupancy
-- flight 7 (london->cairo) has zero bookings, shows up at the bottom


-- 5. which hotels are guests actually happy with?
-- avg rating + review count, ranked by satisfaction

WITH hotel_ratings AS (
    SELECT
        h.hotel_id,
        h.name,
        h.location,
        COUNT(r.review_id)      AS total_reviews,
        ROUND(AVG(r.rating), 1) AS avg_rating
    FROM hotels h
    JOIN reviews r ON h.hotel_id = r.hotel_id
    WHERE r.hotel_id IS NOT NULL
    GROUP BY h.hotel_id, h.name, h.location
)
SELECT
    name,
    location,
    total_reviews,
    avg_rating,
    RANK() OVER (ORDER BY avg_rating DESC, total_reviews DESC) AS rating_rank
FROM hotel_ratings
ORDER BY rating_rank;

-- burj al arab leads with a perfect 5.0, nile ritz and le meurice both average 4.5 but nile ritz
-- ranks higher because it has more reviews (4 vs 2), the plaza has no reviews and doesn't appear


-- 6. how much came in each month, and from which stream?
-- UNION ALL splits hotel vs flight revenue, window function adds the combined monthly total per row

WITH monthly AS (
    SELECT
        TO_CHAR(p.payment_date, 'YYYY-MM') AS month,
        'hotel'                             AS booking_type,
        SUM(p.amount)                       AS revenue
    FROM payments p
    WHERE p.hotel_booking_id IS NOT NULL
    GROUP BY TO_CHAR(p.payment_date, 'YYYY-MM')

    UNION ALL

    SELECT
        TO_CHAR(p.payment_date, 'YYYY-MM') AS month,
        'flight'                            AS booking_type,
        SUM(p.amount)                       AS revenue
    FROM payments p
    WHERE p.flight_booking_id IS NOT NULL
    GROUP BY TO_CHAR(p.payment_date, 'YYYY-MM')
)
SELECT
    month,
    booking_type,
    revenue,
    SUM(revenue) OVER (PARTITION BY month) AS total_monthly_revenue
FROM monthly
ORDER BY month, booking_type;

-- june is the busiest month ($6,440 combined), march is second ($6,360) from the hotel suite bookings


-- 7. which flight routes get the most bookings and revenue?
-- useful for capacity planning and marketing focus

SELECT
    f.departure_city || ' -> ' || f.arrival_city AS route,
    COUNT(fb.booking_id)                          AS total_bookings,
    SUM(p.amount)                                 AS total_revenue,
    ROUND(AVG(f.price), 2)                        AS avg_ticket_price
FROM flights f
LEFT JOIN flight_bookings fb ON f.flight_id         = fb.flight_id AND fb.status != 'cancelled'
LEFT JOIN payments p         ON p.flight_booking_id = fb.booking_id
GROUP BY f.departure_city, f.arrival_city
ORDER BY total_bookings DESC, total_revenue DESC;


-- 8. which customers booked both a hotel and a flight?
-- good for bundling or cross-sell campaigns
-- INTERSECT handles the overlap cleanly

SELECT u.name, u.email
FROM users u
WHERE u.user_id IN (
    SELECT user_id FROM hotel_bookings  WHERE status != 'cancelled'
    INTERSECT
    SELECT user_id FROM flight_bookings WHERE status != 'cancelled'
);

-- all 6 customers appear — karim has a pending hotel booking (not cancelled) and dina has both too


-- 9. what's the ratio of confirmed/pending/cancelled across both booking types?
-- a quick health check on the overall system

SELECT
    'hotel'         AS booking_type,
    status,
    COUNT(*)        AS count,
    SUM(total_cost) AS total_value
FROM hotel_bookings
GROUP BY status

UNION ALL

SELECT
    'flight'        AS booking_type,
    status,
    COUNT(*)        AS count,
    SUM(f.price)    AS total_value
FROM flight_bookings fb
JOIN flights f ON fb.flight_id = f.flight_id
GROUP BY status

ORDER BY booking_type, status;


-- 10. which payment method brings in the most money?
-- window function calculates each method's share of total revenue in one pass

SELECT
    method,
    COUNT(*)                                                AS transactions,
    SUM(amount)                                             AS total_revenue,
    ROUND(SUM(amount) / SUM(SUM(amount)) OVER () * 100, 1) AS revenue_pct
FROM payments
GROUP BY method
ORDER BY total_revenue DESC;

-- credit_card should dominate, cash will be the smallest slice


-- 11. running total of all payments day by day
-- useful for tracking growth trajectory over time

SELECT
    payment_date,
    SUM(amount)                                   AS daily_revenue,
    SUM(SUM(amount)) OVER (ORDER BY payment_date) AS running_total
FROM payments
GROUP BY payment_date
ORDER BY payment_date;


-- 12. every booking a customer ever made, hotel or flight, in one list
-- useful for customer support or account statements

SELECT
    u.name                                       AS customer,
    'Hotel'                                      AS booking_type,
    h.name                                       AS destination,
    hb.check_in::text                            AS travel_date,
    hb.total_cost                                AS amount,
    hb.status
FROM users u
JOIN hotel_bookings hb ON u.user_id   = hb.user_id
JOIN rooms r           ON hb.room_id  = r.room_id
JOIN hotels h          ON r.hotel_id  = h.hotel_id

UNION ALL

SELECT
    u.name                                       AS customer,
    'Flight'                                     AS booking_type,
    f.departure_city || ' -> ' || f.arrival_city AS destination,
    f.departure_time::date::text                 AS travel_date,
    f.price                                      AS amount,
    fb.status
FROM users u
JOIN flight_bookings fb ON u.user_id    = fb.user_id
JOIN flights f          ON fb.flight_id = f.flight_id

ORDER BY customer, travel_date;

-- returns everything per customer in chronological order
-- admins won't appear since they have no bookings

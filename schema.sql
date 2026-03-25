-- drop everything first so we can re-run this file cleanly
DROP TABLE IF EXISTS reviews          CASCADE;
DROP TABLE IF EXISTS payments         CASCADE;
DROP TABLE IF EXISTS flight_bookings  CASCADE;
DROP TABLE IF EXISTS hotel_bookings   CASCADE;
DROP TABLE IF EXISTS seats            CASCADE;
DROP TABLE IF EXISTS flights          CASCADE;
DROP TABLE IF EXISTS airlines         CASCADE;
DROP TABLE IF EXISTS rooms            CASCADE;
DROP TABLE IF EXISTS hotels           CASCADE;
DROP TABLE IF EXISTS users            CASCADE;


-- users first, everything else references this table
CREATE TABLE users (
    user_id       SERIAL        PRIMARY KEY,
    name          VARCHAR(100)  NOT NULL,
    email         VARCHAR(150)  NOT NULL UNIQUE,
    phone         VARCHAR(20),                      -- optional, not everyone shares it
    password_hash VARCHAR(255)  NOT NULL,
    role          VARCHAR(20)   NOT NULL DEFAULT 'customer'
                  CHECK (role IN ('customer', 'admin'))
);


-- hotels, no dependencies
CREATE TABLE hotels (
    hotel_id    SERIAL        PRIMARY KEY,
    name        VARCHAR(150)  NOT NULL,
    location    VARCHAR(150)  NOT NULL,
    rating      NUMERIC(2,1)  CHECK (rating >= 0.0 AND rating <= 5.0),  -- the hotel's own star rating, separate from user reviews
    description TEXT
);


-- rooms belong to hotels
-- availability is NOT a column here, it's derived from booking date overlaps
CREATE TABLE rooms (
    room_id         SERIAL        PRIMARY KEY,
    hotel_id        INT           NOT NULL REFERENCES hotels(hotel_id) ON DELETE CASCADE,
    type            VARCHAR(50)   NOT NULL,          -- single, double, suite, etc.
    price_per_night NUMERIC(10,2) NOT NULL CHECK (price_per_night > 0)
);


-- airlines, independent
CREATE TABLE airlines (
    airline_id  SERIAL        PRIMARY KEY,
    name        VARCHAR(100)  NOT NULL UNIQUE
);


-- flights belong to airlines
CREATE TABLE flights (
    flight_id       SERIAL        PRIMARY KEY,
    airline_id      INT           NOT NULL REFERENCES airlines(airline_id) ON DELETE CASCADE,
    departure_city  VARCHAR(100)  NOT NULL,
    arrival_city    VARCHAR(100)  NOT NULL,
    departure_time  TIMESTAMPTZ   NOT NULL,
    arrival_time    TIMESTAMPTZ   NOT NULL,
    price           NUMERIC(10,2) NOT NULL CHECK (price > 0),
    CHECK (arrival_time > departure_time)   -- can't land before you take off
);


-- seats belong to flights and are pre-populated when a flight is created
-- a seat exists whether or not anyone books it
-- available seat count is derived: seats on this flight with no active flight_booking
CREATE TABLE seats (
    seat_id     SERIAL       PRIMARY KEY,
    flight_id   INT          NOT NULL REFERENCES flights(flight_id) ON DELETE CASCADE,
    seat_number VARCHAR(10)  NOT NULL,       -- e.g. 12A, 14C
    UNIQUE (flight_id, seat_number)          -- same seat number can't appear twice on the same flight
);


-- hotel bookings — a user reserves a specific room for a date range
-- total_cost is stored explicitly so historical records stay accurate
-- if price_per_night changes later, past bookings still show what was actually charged
CREATE TABLE hotel_bookings (
    booking_id  SERIAL        PRIMARY KEY,
    user_id     INT           NOT NULL REFERENCES users(user_id),
    room_id     INT           NOT NULL REFERENCES rooms(room_id),
    check_in    DATE          NOT NULL,
    check_out   DATE          NOT NULL,
    total_cost  NUMERIC(10,2) NOT NULL CHECK (total_cost > 0),
    status      VARCHAR(20)   NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'confirmed', 'cancelled')),
    CHECK (check_out > check_in)
);

-- double booking prevention for rooms is handled by the trigger at the bottom


-- flight bookings — a user claims a specific seat on a specific flight
-- flight_id is stored directly (not derived through seat) for easier querying
CREATE TABLE flight_bookings (
    booking_id  SERIAL       PRIMARY KEY,
    user_id     INT          NOT NULL REFERENCES users(user_id),
    flight_id   INT          NOT NULL REFERENCES flights(flight_id),
    seat_id     INT          NOT NULL REFERENCES seats(seat_id),
    status      VARCHAR(20)  NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'confirmed', 'cancelled'))
);

-- partial unique index instead of a plain UNIQUE on seat_id
-- so a cancelled booking frees the seat up for someone else automatically
CREATE UNIQUE INDEX unique_active_seat
    ON flight_bookings(seat_id)
    WHERE status != 'cancelled';


-- one payments table for both booking types
-- exactly one of the two FKs must be set, the other must be null
CREATE TABLE payments (
    payment_id          SERIAL        PRIMARY KEY,
    hotel_booking_id    INT           REFERENCES hotel_bookings(booking_id),   -- nullable
    flight_booking_id   INT           REFERENCES flight_bookings(booking_id),  -- nullable
    amount              NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    method              VARCHAR(50)   NOT NULL,   -- e.g. credit_card, cash, online
    payment_date        DATE          NOT NULL DEFAULT CURRENT_DATE,
    -- exactly one booking type must be linked, never both, never neither
    CHECK (
        (hotel_booking_id  IS NOT NULL AND flight_booking_id IS NULL) OR
        (hotel_booking_id  IS NULL     AND flight_booking_id IS NOT NULL)
    )
);


-- reviews work exactly like payments — nullable FK per entity type
-- a review targets either a hotel or an airline, not both
CREATE TABLE reviews (
    review_id   SERIAL       PRIMARY KEY,
    user_id     INT          NOT NULL REFERENCES users(user_id),
    hotel_id    INT          REFERENCES hotels(hotel_id),      -- nullable
    airline_id  INT          REFERENCES airlines(airline_id),  -- nullable
    rating      SMALLINT     NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    -- same check pattern as payments
    CHECK (
        (hotel_id  IS NOT NULL AND airline_id IS NULL) OR
        (hotel_id  IS NULL     AND airline_id IS NOT NULL)
    )
);

-- one review per user per hotel, one review per user per airline
-- partial indexes so the null side doesn't interfere
CREATE UNIQUE INDEX unique_user_hotel_review
    ON reviews(user_id, hotel_id)
    WHERE hotel_id IS NOT NULL;

CREATE UNIQUE INDEX unique_user_airline_review
    ON reviews(user_id, airline_id)
    WHERE airline_id IS NOT NULL;


-- trigger to block double booking of rooms
-- fires before any insert or update on hotel_bookings
-- overlap condition: existing.check_in < NEW.check_out AND existing.check_out > NEW.check_in
-- COALESCE on booking_id makes sure an update doesn't conflict with itself

-- note: an EXCLUDE statment USING GIST constraint with btree_gist would handle concurrent transactions, but we're skipping the extension to keep this runnable in any environment without extra setup. the trigger is enough here.

CREATE OR REPLACE FUNCTION check_room_double_booking()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   hotel_bookings
        WHERE  room_id    =  NEW.room_id
          AND  status     != 'cancelled'
          AND  booking_id != COALESCE(NEW.booking_id, -1)
          AND  check_in   <  NEW.check_out
          AND  check_out  >  NEW.check_in
    ) THEN
        RAISE EXCEPTION
            'room % is already booked between % and %.',
            NEW.room_id, NEW.check_in, NEW.check_out;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_double_booking
    BEFORE INSERT OR UPDATE ON hotel_bookings
    FOR EACH ROW EXECUTE FUNCTION check_room_double_booking();


-- That's it! now to seeding data, reference seed.sql file next.

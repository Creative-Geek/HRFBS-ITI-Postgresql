-- seed data for the hotel reservation & flight booking system
-- run schema.sql first, then this file

-- 2 admins, 6 customers
-- passwords are fake hashes, a real app would bcrypt these
INSERT INTO users (name, email, phone, password_hash, role) VALUES
('Ahmed Hassan',  'ahmed.hassan@email.com',  '01012345678', 'hashed_pw_1', 'admin'), -- random phone and email for extra realism XD
('Sara Mohamed',  'sara.mohamed@email.com',  '01123456789', 'hashed_pw_2', 'admin'),
('Omar Khalil',   'omar.khalil@email.com',   '01234567890', 'hashed_pw_3', 'customer'),
('Nour Ibrahim',  'nour.ibrahim@email.com',  '01098765432', 'hashed_pw_4', 'customer'),
('Youssef Ali',   'youssef.ali@email.com',   '01187654321', 'hashed_pw_5', 'customer'),
('Layla Mahmoud', 'layla.mahmoud@email.com', '01276543210', 'hashed_pw_6', 'customer'),
('Karim Farouk',  'karim.farouk@email.com',  '01365432109', 'hashed_pw_7', 'customer'),
('Dina Samir',    'dina.samir@email.com',    '01454321098', 'hashed_pw_8', 'customer'),
('Tarek Nasser',  'tarek.nasser@email.com',  '01512345678', 'hashed_pw_9', 'customer');  -- flight only, no hotel booking (used to test query 8)


-- 5 hotels across 5 cities
-- rating here is the hotel's own star classification, not user reviews!!!
INSERT INTO hotels (name, location, rating, description) VALUES
('Nile Ritz-Carlton', 'Cairo',    4.8, 'Luxury hotel overlooking the Nile River in the heart of Cairo'),
('Burj Al Arab',      'Dubai',    5.0, 'Iconic sail-shaped ultra-luxury hotel on its own island'),
('Le Meurice',        'Paris',    4.7, 'Palace hotel near the Tuileries Garden, a Parisian landmark'),
('The Savoy',         'London',   4.6, 'Historic grand hotel on the Strand since 1889'),
('The Plaza',         'New York', 4.5, 'Landmark hotel overlooking Central Park on Fifth Avenue');


-- 3 rooms per hotel: single, double, suite
-- IDs will be 1-15, grouped by hotel
INSERT INTO rooms (hotel_id, type, price_per_night) VALUES
-- Nile Ritz-Carlton (rooms 1-3)
(1, 'single', 120.00),
(1, 'double', 200.00),
(1, 'suite',  450.00),
-- Burj Al Arab (rooms 4-6)
(2, 'double', 500.00),
(2, 'suite',  900.00),
(2, 'suite',  1500.00),  -- presidential suite, separate row from the regular suite
-- Le Meurice (rooms 7-9)
(3, 'single', 250.00),
(3, 'double', 400.00),
(3, 'suite',  800.00),
-- The Savoy (rooms 10-12)
(4, 'single', 300.00),
(4, 'double', 500.00),
(4, 'suite',  1000.00),
-- The Plaza (rooms 13-15)
(5, 'single', 350.00),
(5, 'double', 600.00),
(5, 'suite',  1200.00);


-- 4 airlines
INSERT INTO airlines (name) VALUES
('EgyptAir'),        -- id 1
('Emirates'),        -- id 2
('British Airways'), -- id 3
('Air France');      -- id 4


-- 8 flights across different routes and airlines
-- using UTC timestamps to keep things consistent
INSERT INTO flights (airline_id, departure_city, arrival_city, departure_time, arrival_time, price) VALUES
(1, 'Cairo',    'Dubai',    '2025-06-01 08:00:00+00', '2025-06-01 12:00:00+00', 250.00),  -- flight 1
(1, 'Cairo',    'London',   '2025-06-05 10:00:00+00', '2025-06-05 15:00:00+00', 450.00),  -- flight 2
(2, 'Dubai',    'Paris',    '2025-06-10 14:00:00+00', '2025-06-10 19:30:00+00', 380.00),  -- flight 3
(3, 'London',   'New York', '2025-06-15 09:00:00+00', '2025-06-15 14:00:00+00', 550.00),  -- flight 4
(4, 'Paris',    'Cairo',    '2025-06-20 11:00:00+00', '2025-06-20 15:00:00+00', 420.00),  -- flight 5
(2, 'Dubai',    'Cairo',    '2025-07-01 07:00:00+00', '2025-07-01 10:00:00+00', 260.00),  -- flight 6
(3, 'London',   'Cairo',    '2025-07-05 13:00:00+00', '2025-07-05 18:00:00+00', 440.00),  -- flight 7
(4, 'New York', 'London',   '2025-07-10 18:00:00+00', '2025-07-11 06:00:00+00', 520.00);  -- flight 8


-- 8 seats per flight, 64 rows total
-- seat IDs end up as: flight 1 = 1-8, flight 2 = 9-16, flight 3 = 17-24, and so on
-- we'll need these IDs when inserting flight bookings below
INSERT INTO seats (flight_id, seat_number) VALUES
-- flight 1: Cairo -> Dubai
(1,'1A'),(1,'1B'),(1,'2A'),(1,'2B'),(1,'3A'),(1,'3B'),(1,'4A'),(1,'4B'),
-- flight 2: Cairo -> London
(2,'1A'),(2,'1B'),(2,'2A'),(2,'2B'),(2,'3A'),(2,'3B'),(2,'4A'),(2,'4B'),
-- flight 3: Dubai -> Paris
(3,'1A'),(3,'1B'),(3,'2A'),(3,'2B'),(3,'3A'),(3,'3B'),(3,'4A'),(3,'4B'),
-- flight 4: London -> New York
(4,'1A'),(4,'1B'),(4,'2A'),(4,'2B'),(4,'3A'),(4,'3B'),(4,'4A'),(4,'4B'),
-- flight 5: Paris -> Cairo
(5,'1A'),(5,'1B'),(5,'2A'),(5,'2B'),(5,'3A'),(5,'3B'),(5,'4A'),(5,'4B'),
-- flight 6: Dubai -> Cairo
(6,'1A'),(6,'1B'),(6,'2A'),(6,'2B'),(6,'3A'),(6,'3B'),(6,'4A'),(6,'4B'),
-- flight 7: London -> Cairo
(7,'1A'),(7,'1B'),(7,'2A'),(7,'2B'),(7,'3A'),(7,'3B'),(7,'4A'),(7,'4B'),
-- flight 8: New York -> London
(8,'1A'),(8,'1B'),(8,'2A'),(8,'2B'),(8,'3A'),(8,'3B'),(8,'4A'),(8,'4B');


-- 12 hotel bookings spread across users and hotels
-- total_cost = price_per_night * number of nights, stored explicitly
-- one cancelled booking (hb11) to keep history realistic
INSERT INTO hotel_bookings (user_id, room_id, check_in, check_out, total_cost, status) VALUES
(3, 1,  '2025-01-10', '2025-01-14', 480.00,  'confirmed'),  -- hb1:  Omar,   Cairo single,  4 nights
(5, 1,  '2025-03-05', '2025-03-08', 360.00,  'confirmed'),  -- hb2:  Youssef, Cairo single, 3 nights (no overlap with hb1)
(4, 2,  '2025-02-14', '2025-02-18', 800.00,  'confirmed'),  -- hb3:  Nour,   Cairo double,  4 nights
(6, 3,  '2025-04-20', '2025-04-25', 2250.00, 'confirmed'),  -- hb4:  Layla,  Cairo suite,   5 nights
(3, 4,  '2025-02-01', '2025-02-05', 2000.00, 'confirmed'),  -- hb5:  Omar,   Dubai double,  4 nights
(7, 4,  '2025-05-10', '2025-05-15', 2500.00, 'pending'),    -- hb6:  Karim,  Dubai double,  5 nights (no overlap with hb5)
(8, 5,  '2025-03-15', '2025-03-20', 4500.00, 'confirmed'),  -- hb7:  Dina,   Dubai suite,   5 nights
(4, 8,  '2025-05-01', '2025-05-06', 2000.00, 'confirmed'),  -- hb8:  Nour,   Paris double,  5 nights
(6, 9,  '2025-06-10', '2025-06-15', 4000.00, 'confirmed'),  -- hb9:  Layla,  Paris suite,   5 nights
(5, 11, '2025-04-01', '2025-04-04', 1500.00, 'confirmed'),  -- hb10: Youssef, London double, 3 nights
(7, 12, '2025-01-20', '2025-01-25', 5000.00, 'cancelled'),  -- hb11: Karim,  London suite,  cancelled
(8, 14, '2025-07-05', '2025-07-10', 3000.00, 'pending');    -- hb12: Dina,   NY double,     5 nights


-- 10 flight bookings
-- seat IDs: flight 1 = seats 1-8, flight 2 = 9-16, flight 3 = 17-24,
--           flight 4 = 25-32, flight 5 = 33-40, flight 6 = 41-48, flight 8 = 57-64
--
-- fb8 and fb9 are the interesting ones:
-- Nour books seat 41 (flight 6, 1A) then cancels
-- Youssef books the same seat 41 right after — this proves the partial unique index works
INSERT INTO flight_bookings (user_id, flight_id, seat_id, status) VALUES
(3, 1, 1,  'confirmed'),  -- fb1:  Omar,    Cairo->Dubai,     seat 1A
(4, 1, 2,  'confirmed'),  -- fb2:  Nour,    Cairo->Dubai,     seat 1B
(5, 2, 9,  'confirmed'),  -- fb3:  Youssef, Cairo->London,    seat 1A
(6, 3, 17, 'confirmed'),  -- fb4:  Layla,   Dubai->Paris,     seat 1A
(7, 3, 18, 'confirmed'),  -- fb5:  Karim,   Dubai->Paris,     seat 1B
(8, 4, 25, 'confirmed'),  -- fb6:  Dina,    London->New York, seat 1A
(3, 5, 33, 'confirmed'),  -- fb7:  Omar,    Paris->Cairo,     seat 1A
(4, 6, 41, 'cancelled'),  -- fb8:  Nour,    Dubai->Cairo,     seat 1A — cancelled, frees the seat
(5, 6, 41, 'confirmed'),  -- fb9:  Youssef, Dubai->Cairo,     seat 1A — same seat, now rebooked
(7, 8, 57, 'pending'),    -- fb10: Karim,   New York->London, seat 1A
(9, 7, 49, 'confirmed');  -- fb11: Tarek,   London->Cairo,    seat 1A — flight only, no hotel booking


-- payments for all non-cancelled bookings
-- no payment for hb11 (cancelled hotel) or fb8 (cancelled flight)
INSERT INTO payments (hotel_booking_id, flight_booking_id, amount, method, payment_date) VALUES
-- hotel booking payments
(1,  NULL, 480.00,  'credit_card', '2025-01-09'),  -- hb1
(2,  NULL, 360.00,  'online',      '2025-03-04'),  -- hb2
(3,  NULL, 800.00,  'credit_card', '2025-02-13'),  -- hb3
(4,  NULL, 2250.00, 'credit_card', '2025-04-19'),  -- hb4
(5,  NULL, 2000.00, 'cash',        '2025-01-31'),  -- hb5
(6,  NULL, 2500.00, 'online',      '2025-05-09'),  -- hb6
(7,  NULL, 4500.00, 'credit_card', '2025-03-14'),  -- hb7
(8,  NULL, 2000.00, 'online',      '2025-04-30'),  -- hb8
(9,  NULL, 4000.00, 'credit_card', '2025-06-09'),  -- hb9
(10, NULL, 1500.00, 'credit_card', '2025-03-31'),  -- hb10
(12, NULL, 3000.00, 'online',      '2025-07-04'),  -- hb12 (skipping hb11, it was cancelled)
-- flight booking payments
(NULL, 1,  250.00,  'credit_card', '2025-05-31'),  -- fb1
(NULL, 2,  250.00,  'online',      '2025-05-31'),  -- fb2
(NULL, 3,  450.00,  'credit_card', '2025-06-04'),  -- fb3
(NULL, 4,  380.00,  'credit_card', '2025-06-09'),  -- fb4
(NULL, 5,  380.00,  'online',      '2025-06-09'),  -- fb5
(NULL, 6,  550.00,  'credit_card', '2025-06-14'),  -- fb6
(NULL, 7,  420.00,  'cash',        '2025-06-19'),  -- fb7
(NULL, 9,  260.00,  'online',      '2025-06-30'),  -- fb9 (skipping fb8, it was cancelled)
(NULL, 10, 520.00,  'credit_card', '2025-07-09'),  -- fb10
(NULL, 12, 440.00,  'online',      '2025-07-04');  -- fb11 (Tarek)


-- 10 reviews: 8 hotel reviews, 2 airline reviews
-- all from users who actually booked the thing they're reviewing
INSERT INTO reviews (user_id, hotel_id, airline_id, rating, comment) VALUES
-- hotel reviews
(3, 1, NULL, 5, 'Amazing Nile views, exceptional service from check-in to check-out'),
(4, 1, NULL, 4, 'Great location and very clean rooms, breakfast could be better'),
(5, 1, NULL, 5, 'Best hotel in Cairo, will absolutely come back'),
(6, 1, NULL, 4, 'Lovely stay, a bit pricey for a suite but the experience is worth it'),
(8, 2, NULL, 5, 'Once in a lifetime experience, absolutely stunning in every way'),
(4, 3, NULL, 5, 'Le Meurice is a dream, the perfect Parisian stay'),
(6, 3, NULL, 4, 'Beautiful hotel, staff was incredible, rooms are magazine-worthy'),
(5, 4, NULL, 4, 'The Savoy fully lives up to its legendary reputation'),
-- airline reviews
(5, NULL, 1, 4, 'Comfortable flight, good in-flight service, minor delay on departure'),
(6, NULL, 2, 5, 'Emirates never disappoints, premium experience from gate to gate');


-- this should FAIL — overlaps with hb1 (Omar, room 1, Jan 10-14)
-- the trigger catches it because Jan 12 < Jan 14 AND Jan 15 > Jan 10
-- uncomment to verify the trigger is working
-- INSERT INTO hotel_bookings (user_id, room_id, check_in, check_out, total_cost)
-- VALUES (4, 1, '2025-01-12', '2025-01-15', 360.00);
-- does fail indeed...now to queries (report style!), reference queries.sql

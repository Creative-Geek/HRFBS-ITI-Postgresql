# Design Decisions & Why We Made Them

A record of every non-obvious choice we made while building this, written the way we actually talked about it.

---

## 1. One payments table, not two

The obvious path was a `hotel_payments` table and a `flight_payments` table. We didn't do that because it's just the same columns twice. Instead, one `payments` table with two nullable FKs — `hotel_booking_id` and `flight_booking_id` — and a `CHECK` constraint that makes sure exactly one of them is set.

```sql
CHECK (
    (hotel_booking_id IS NOT NULL AND flight_booking_id IS NULL) OR
    (hotel_booking_id IS NULL     AND flight_booking_id IS NOT NULL)
)
```

This pattern came up again with reviews. Same solution, same reasoning.

---

## 2. Reviews ended up covering airlines too

The original requirements only mentioned hotel reviews. We caught this during planning and expanded it — users should be able to review their airline experience too.

Instead of a separate `airline_reviews` table, we reused the same nullable FK pattern from payments: one `reviews` table, nullable `hotel_id` and `airline_id`, same CHECK constraint. One review per user per hotel, one review per user per airline, enforced by partial unique indexes.

---

## 3. Room availability is not a column

There's no `is_available` boolean on the rooms table. Availability is derived — a room is available if no active (non-cancelled) booking overlaps the requested dates.

Storing a boolean would mean keeping it in sync manually every time a booking is created, cancelled, or updated. That's just asking for bugs. The query is a simple NOT IN subquery and it's always correct.

Same thinking applied to flight seat availability — we count unbooked seats, we don't store a number.

---

## 4. Seats are pre-populated, bookings claim them

The seats table is filled when a flight is created. Every seat exists as a row whether or not anyone books it.

When someone books a flight, the `flight_bookings` row gets a `seat_id` FK pointing to that seat. The booking claims the seat, not the other way around. This makes the "select your seat" UI straightforward — just query for seats on this flight with no active booking.

---

## 5. Double booking rooms — trigger, not EXCLUDE

PostgreSQL has a cleaner way to prevent date-range overlaps: an `EXCLUDE USING GIST` constraint with the `btree_gist` extension. It's atomic, handles concurrent transactions, and is a single line of DDL.

We didn't use it. The reason is practical — it requires enabling an extension, and this is a graded class project. If the grader's environment doesn't have `btree_gist` or doesn't allow extensions, the whole schema fails to run. That's a worse outcome than using a trigger.

The trigger isn't bulletproof under heavy concurrency, and we noted that explicitly in the code. But for this use case it's fine.

---

## 6. Double booking seats — partial unique index

For seats we didn't need a trigger. A partial unique index does the job:

```sql
CREATE UNIQUE INDEX unique_active_seat
    ON flight_bookings(seat_id)
    WHERE status != 'cancelled';
```

This means a cancelled booking frees the seat automatically. If Nour cancels her seat, Youssef can book the exact same one with no conflicts. We tested this in the seed data intentionally — fb8 cancels seat 41, fb9 books it again.

---

## 7. Booking status is separate on each table

`hotel_bookings` and `flight_bookings` both have a `status` column with the same valid values: `pending`, `confirmed`, `cancelled`. They're separate columns on separate tables, not a shared reference.

The values happen to be the same now, but if the business logic ever diverges — say flights add a `boarded` status, or hotels add `checked_in` — each table can evolve on its own without touching the other.

---

## 8. total_cost is stored, not computed

`hotel_bookings` stores `total_cost` explicitly instead of computing it from `price_per_night * nights` at query time.

If a room's price changes next month, every historical query would return the wrong amount if we computed on the fly. Storing it means the record reflects what the customer was actually charged at the time of booking. This is the right behavior for anything financial.

---

## 9. flight_id lives on flight_bookings even though seat already knows it

`seats` has a `flight_id` FK, so technically you could derive which flight a booking is for by joining through the seat. We stored `flight_id` directly on `flight_bookings` anyway.

Two reasons: queries are simpler and faster when you don't need an extra join, and it leaves the door open for seat re-assignment without losing track of which flight the booking is actually for.

---

## 10. TIMESTAMPTZ for flight times

The course baseline uses `DATE`. We used `TIMESTAMPTZ` for departure and arrival times because a flight time without a timezone is meaningless — a departure at 14:00 in Dubai is a completely different moment than 14:00 in London. `TIMESTAMPTZ` stores everything in UTC internally and handles the conversion correctly.

---

## 11. The failing INSERT in seed.sql

At the end of `seed.sql` there's a commented-out INSERT that would try to book room 1 during a window it's already occupied. It's there as a proof that the trigger works — uncomment it, run it, watch it fail with the right error message. Useful for demos and for anyone reading the code later.

---

## 12. schema.sql + seed.sql are a replayable pair

`schema.sql` starts with `DROP TABLE IF EXISTS ... CASCADE` for every table in reverse FK order. This means you can run `schema.sql` then `seed.sql` as many times as you want and always get a clean, consistent state.

`seed.sql` alone is not replayable — running it twice without a fresh schema would hit unique constraint violations on emails, airline names, seat numbers, etc.

`queries.sql` is always replayable since it's all SELECTs.
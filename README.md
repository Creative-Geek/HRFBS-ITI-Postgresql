# Hotel Reservation & Flight Booking System (HRFBS)

HRFBS is a relational data model and reporting project built in PostgreSQL.

## Scope

HRFBS models an end-to-end travel workflow across hotels and flights:

- User and role management (`customer`, `admin`)
- Hotel inventory (hotels and rooms)
- Airline inventory (airlines, flights, seats)
- Booking lifecycle (pending, confirmed, cancelled)
- Payments and reviews across both booking domains

## Entity Relationship Diagram

```mermaid
erDiagram

    USERS {
        serial      user_id         PK
        varchar     name            "NOT NULL"
        varchar     email           "NOT NULL, UNIQUE"
        varchar     phone
        varchar     password_hash   "NOT NULL"
        varchar     role            "CHECK: customer | admin"
    }

    HOTELS {
        serial      hotel_id        PK
        varchar     name            "NOT NULL"
        varchar     location        "NOT NULL"
        numeric     rating          "CHECK: 0.0 - 5.0"
        text        description
    }

    ROOMS {
        serial      room_id         PK
        int         hotel_id        FK
        varchar     type            "e.g. single, double, suite"
        numeric     price_per_night "NOT NULL"
    }

    HOTEL_BOOKINGS {
        serial      booking_id      PK
        int         user_id         FK
        int         room_id         FK
        date        check_in        "NOT NULL"
        date        check_out       "NOT NULL"
        numeric     total_cost      "NOT NULL"
        varchar     status          "CHECK: pending | confirmed | cancelled"
    }

    AIRLINES {
        serial      airline_id      PK
        varchar     name            "NOT NULL, UNIQUE"
    }

    FLIGHTS {
        serial      flight_id       PK
        int         airline_id      FK
        varchar     departure_city  "NOT NULL"
        varchar     arrival_city    "NOT NULL"
        timestamptz departure_time  "NOT NULL"
        timestamptz arrival_time    "NOT NULL"
        numeric     price           "NOT NULL"
    }

    SEATS {
        serial      seat_id         PK
        int         flight_id       FK
        varchar     seat_number     "NOT NULL, e.g. 12A"
    }

    FLIGHT_BOOKINGS {
        serial      booking_id      PK
        int         user_id         FK
        int         flight_id       FK
        int         seat_id         FK
        varchar     status          "CHECK: pending | confirmed | cancelled"
    }

    PAYMENTS {
        serial      payment_id          PK
        int         hotel_booking_id    FK  "nullable"
        int         flight_booking_id   FK  "nullable"
        numeric     amount              "NOT NULL"
        varchar     method              "e.g. credit_card, cash, online"
        date        payment_date        "NOT NULL"
    }

    REVIEWS {
        serial      review_id       PK
        int         user_id         FK
        int         hotel_id        FK  "nullable"
        int         airline_id      FK  "nullable"
        smallint    rating          "CHECK: 1 - 5"
        text        comment
        timestamptz created_at      "DEFAULT now()"
    }

    USERS          ||--o{ HOTEL_BOOKINGS   : "makes"
    USERS          ||--o{ FLIGHT_BOOKINGS  : "makes"
    USERS          ||--o{ REVIEWS          : "writes"

    HOTELS         ||--o{ ROOMS            : "has"
    HOTELS         ||--o{ REVIEWS          : "receives"

    AIRLINES       ||--o{ REVIEWS          : "receives"

    ROOMS          ||--o{ HOTEL_BOOKINGS   : "reserved in"

    AIRLINES       ||--o{ FLIGHTS          : "operates"

    FLIGHTS        ||--o{ SEATS            : "has"
    FLIGHTS        ||--o{ FLIGHT_BOOKINGS  : "booked on"

    SEATS          ||--o{ FLIGHT_BOOKINGS  : "assigned to"

    HOTEL_BOOKINGS |o--o| PAYMENTS         : "paid via"
    FLIGHT_BOOKINGS|o--o| PAYMENTS         : "paid via"
```

## Repository Files

- `schema.sql`: Full schema definition, constraints, indexes, and trigger functions.
- `seed.sql`: Representative seed data for operational and reporting scenarios.
- `queries.sql`: Report-style analytics queries for revenue, occupancy, ranking, and behavior insights.
- `results.txt`: Reference output generated from running the query suite on seeded data.
- `erd.md`: Entity relationship diagram and design rationale.

## Quick Start

### Prerequisites

- PostgreSQL running locally or remotely
- `psql` CLI available in your shell

### Execution Order

```bash
# 1) Create database
createdb hrfbs

# 2) Build schema
psql -d hrfbs -f schema.sql

# 3) Load sample data
psql -d hrfbs -f seed.sql

# 4) Run analytics queries
psql -d hrfbs -f queries.sql
```

Optional: persist query output.

```bash
psql -d hrfbs -f queries.sql > results.txt
```

## HRFBS Design Principles

### Integrity First

- Room double-booking is blocked using overlap validation in a trigger.
- Flight seat conflicts are prevented with a partial unique index for active bookings.
- Payments enforce exactly one booking reference (hotel or flight, never both).
- Reviews enforce exactly one target entity (hotel or airline, never both).

### Operational Realism

- Booking states preserve lifecycle history instead of deleting records.
- `cancelled` records remain queryable for auditability.
- `total_cost` is stored on hotel bookings to preserve historical price truth.

### Analytics Readiness

- Query suite is written as business reports, not isolated SQL drills.
- CTEs and window functions are used where they improve clarity and insight.
- Outputs support decision-making for pricing, occupancy, customer value, and service quality.
- Performance is optimized with indexes on foreign keys, dates, and route columns.

## Notes

- `schema.sql` is rerunnable and begins with `DROP TABLE IF EXISTS ... CASCADE`.
- Always run `seed.sql` after `schema.sql`.
- Report outputs depend on the seeded dataset and booking statuses.

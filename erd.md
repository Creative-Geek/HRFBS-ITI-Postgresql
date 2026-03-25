# Hotel Reservation & Flight Booking System — ERD

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

## Key Design Notes

| Constraint | Where | How |
|---|---|---|
| Double booking (rooms) | `hotel_bookings` | `BEFORE INSERT OR UPDATE` trigger checks for date overlaps on the same `room_id` |
| Double booking (seats) | `flight_bookings` | Partial `UNIQUE` index on `seat_id WHERE status != 'cancelled'` |
| Payment links to exactly one booking | `payments` | `CHECK ((hotel_booking_id IS NOT NULL AND flight_booking_id IS NULL) OR (hotel_booking_id IS NULL AND flight_booking_id IS NOT NULL))` |
| One review per user per hotel | `reviews` | Partial unique index: `UNIQUE(user_id, hotel_id) WHERE hotel_id IS NOT NULL` |
| One review per user per airline | `reviews` | Partial unique index: `UNIQUE(user_id, airline_id) WHERE airline_id IS NOT NULL` |
| Review links to exactly one entity | `reviews` | `CHECK ((hotel_id IS NOT NULL AND airline_id IS NULL) OR (hotel_id IS NULL AND airline_id IS NOT NULL))` |
| Room & flight availability | derived | Computed from booking overlaps / unbooked seat count — no stored boolean |
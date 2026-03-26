from datetime import date
from urllib.parse import quote

from fastapi import FastAPI, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

import db

app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")


# ── home ─────────────────────────────────────────────────────────────────────


@app.get("/", response_class=HTMLResponse)
def home(request: Request, msg: str = None, error: str = None):
    locations = db.fetch("SELECT DISTINCT location FROM hotels ORDER BY location")
    departures = db.fetch(
        "SELECT DISTINCT departure_city FROM flights ORDER BY departure_city"
    )
    arrivals = db.fetch(
        "SELECT DISTINCT arrival_city   FROM flights ORDER BY arrival_city"
    )

    return templates.TemplateResponse(
        request,
        "index.html",
        {
            "msg": msg,
            "error": error,
            "locations": [r["location"] for r in locations],
            "departures": [r["departure_city"] for r in departures],
            "arrivals": [r["arrival_city"] for r in arrivals],
        },
    )


# ── hotel search & booking ────────────────────────────────────────────────────


@app.get("/search/hotels", response_class=HTMLResponse)
def search_hotels(request: Request, location: str, check_in: str, check_out: str):
    ci = date.fromisoformat(check_in)
    co = date.fromisoformat(check_out)
    nights = (co - ci).days

    if nights <= 0:
        return RedirectResponse(
            f"/?error=Check-out+must+be+after+check-in", status_code=302
        )

    rooms = db.fetch(
        """
        SELECT r.room_id, r.type, r.price_per_night,
               h.name AS hotel_name, h.location, h.rating, h.description
        FROM rooms r
        JOIN hotels h ON r.hotel_id = h.hotel_id
        WHERE LOWER(h.location) = LOWER(%s)
          AND r.room_id NOT IN (
              SELECT room_id FROM hotel_bookings
              WHERE status != 'cancelled'
                AND check_in  < %s
                AND check_out > %s
          )
        ORDER BY h.rating DESC, r.price_per_night
    """,
        (location, check_out, check_in),
    )

    return templates.TemplateResponse(
        request,
        "hotel_results.html",
        {
            "rooms": rooms,
            "location": location,
            "check_in": check_in,
            "check_out": check_out,
            "nights": nights,
        },
    )


@app.get("/book/hotel", response_class=HTMLResponse)
def book_hotel_page(
    request: Request,
    room_id: int,
    check_in: str,
    check_out: str,
    nights: int,
    error: str = None,
):
    room = db.fetch_one(
        """
        SELECT r.room_id, r.type, r.price_per_night,
               h.name AS hotel_name, h.location
        FROM rooms r
        JOIN hotels h ON r.hotel_id = h.hotel_id
        WHERE r.room_id = %s
    """,
        (room_id,),
    )

    return templates.TemplateResponse(
        request,
        "book_hotel.html",
        {
            "room": room,
            "check_in": check_in,
            "check_out": check_out,
            "nights": nights,
            "total": room["price_per_night"] * nights,
            "error": error,
        },
    )


@app.post("/book/hotel")
def book_hotel(
    room_id: int = Form(...),
    check_in: str = Form(...),
    check_out: str = Form(...),
    total_cost: float = Form(...),
    nights: int = Form(...),
    email: str = Form(...),
):
    user = db.fetch_one("SELECT user_id, name FROM users WHERE email = %s", (email,))
    if not user:
        return RedirectResponse(
            f"/book/hotel?room_id={room_id}&check_in={check_in}"
            f"&check_out={check_out}&nights={nights}&error=No+account+found+for+that+email",
            status_code=302,
        )

    try:
        booking = db.execute(
            """
            INSERT INTO hotel_bookings (user_id, room_id, check_in, check_out, total_cost, status)
            VALUES (%s, %s, %s, %s, %s, 'confirmed')
            RETURNING booking_id
        """,
            (user["user_id"], room_id, check_in, check_out, total_cost),
        )

        return RedirectResponse(
            f"/payment?type=hotel&booking_id={booking['booking_id']}&amount={total_cost}",
            status_code=302,
        )
    except Exception as e:
        # trigger fires here for double bookings
        error = quote(str(e).split("\n")[0])
        return RedirectResponse(
            f"/book/hotel?room_id={room_id}&check_in={check_in}"
            f"&check_out={check_out}&nights={nights}&error={error}",
            status_code=302,
        )


# ── flight search & booking ───────────────────────────────────────────────────


@app.get("/search/flights", response_class=HTMLResponse)
def search_flights(request: Request, departure: str, arrival: str):
    flights = db.fetch(
        """
        SELECT f.flight_id, f.departure_city, f.arrival_city,
               f.departure_time, f.arrival_time, f.price,
               al.name AS airline,
               COUNT(s.seat_id) - COUNT(fb.booking_id) AS available_seats
        FROM flights f
        JOIN airlines al ON f.airline_id = al.airline_id
        JOIN seats s     ON f.flight_id  = s.flight_id
        LEFT JOIN flight_bookings fb ON s.seat_id = fb.seat_id AND fb.status != 'cancelled'
        WHERE LOWER(f.departure_city) = LOWER(%s)
          AND LOWER(f.arrival_city)   = LOWER(%s)
        GROUP BY f.flight_id, al.name
        HAVING COUNT(s.seat_id) - COUNT(fb.booking_id) > 0
        ORDER BY f.departure_time
    """,
        (departure, arrival),
    )

    return templates.TemplateResponse(
        request,
        "flight_results.html",
        {
            "flights": flights,
            "departure": departure,
            "arrival": arrival,
        },
    )


@app.get("/book/flight/{flight_id}", response_class=HTMLResponse)
def book_flight_page(request: Request, flight_id: int, error: str = None):
    flight = db.fetch_one(
        """
        SELECT f.flight_id, f.departure_city, f.arrival_city,
               f.departure_time, f.arrival_time, f.price,
               al.name AS airline
        FROM flights f
        JOIN airlines al ON f.airline_id = al.airline_id
        WHERE f.flight_id = %s
    """,
        (flight_id,),
    )

    seats = db.fetch(
        """
        SELECT s.seat_id, s.seat_number
        FROM seats s
        WHERE s.flight_id = %s
          AND s.seat_id NOT IN (
              SELECT seat_id FROM flight_bookings WHERE status != 'cancelled'
          )
        ORDER BY s.seat_number
    """,
        (flight_id,),
    )

    return templates.TemplateResponse(
        request,
        "book_flight.html",
        {
            "flight": flight,
            "seats": seats,
            "error": error,
        },
    )


@app.post("/book/flight")
def book_flight(
    flight_id: int = Form(...),
    seat_id: int = Form(...),
    email: str = Form(...),
):
    user = db.fetch_one("SELECT user_id FROM users WHERE email = %s", (email,))
    if not user:
        return RedirectResponse(
            f"/book/flight/{flight_id}?error=No+account+found+for+that+email",
            status_code=302,
        )

    flight = db.fetch_one(
        "SELECT price FROM flights WHERE flight_id = %s", (flight_id,)
    )

    try:
        booking = db.execute(
            """
            INSERT INTO flight_bookings (user_id, flight_id, seat_id, status)
            VALUES (%s, %s, %s, 'confirmed')
            RETURNING booking_id
        """,
            (user["user_id"], flight_id, seat_id),
        )

        return RedirectResponse(
            f"/payment?type=flight&booking_id={booking['booking_id']}&amount={flight['price']}",
            status_code=302,
        )
    except Exception as e:
        error = quote(str(e).split("\n")[0])
        return RedirectResponse(
            f"/book/flight/{flight_id}?error={error}",
            status_code=302,
        )


# ── payment ───────────────────────────────────────────────────────────────────


@app.get("/payment", response_class=HTMLResponse)
def payment_page(request: Request, type: str, booking_id: int, amount: float):
    return templates.TemplateResponse(
        request,
        "payment.html",
        {
            "type": type,
            "booking_id": booking_id,
            "amount": amount,
        },
    )


@app.post("/pay")
def pay(
    booking_type: str = Form(...),
    booking_id: int = Form(...),
    amount: float = Form(...),
    method: str = Form(...),
):
    hotel_id = booking_id if booking_type == "hotel" else None
    flight_id = booking_id if booking_type == "flight" else None

    db.execute(
        """
        INSERT INTO payments (hotel_booking_id, flight_booking_id, amount, method, payment_date)
        VALUES (%s, %s, %s, %s, CURRENT_DATE)
    """,
        (hotel_id, flight_id, amount, method),
    )

    return RedirectResponse(
        "/?msg=Payment+successful!+Your+booking+is+confirmed.", status_code=302
    )


# ── booking history ───────────────────────────────────────────────────────────


@app.get("/bookings", response_class=HTMLResponse)
def bookings(request: Request, email: str = None):
    user = None
    history = []

    if email:
        user = db.fetch_one(
            "SELECT user_id, name, email FROM users WHERE email = %s", (email,)
        )
        if user:
            history = db.fetch(
                """
                SELECT 'Hotel'       AS type,
                       h.name        AS destination,
                       hb.check_in::text AS date,
                       hb.total_cost AS amount,
                       hb.status
                FROM hotel_bookings hb
                JOIN rooms r  ON hb.room_id  = r.room_id
                JOIN hotels h ON r.hotel_id  = h.hotel_id
                WHERE hb.user_id = %s

                UNION ALL

                SELECT 'Flight'                                            AS type,
                       f.departure_city || ' → ' || f.arrival_city        AS destination,
                       f.departure_time::date::text                        AS date,
                       COALESCE(p.amount, f.price)                         AS amount,
                       fb.status
                FROM flight_bookings fb
                JOIN flights f     ON fb.flight_id          = f.flight_id
                LEFT JOIN payments p ON p.flight_booking_id = fb.booking_id
                WHERE fb.user_id = %s

                ORDER BY date
            """,
                (user["user_id"], user["user_id"]),
            )

    return templates.TemplateResponse(
        request,
        "bookings.html",
        {
            "user": user,
            "history": history,
            "email": email,
        },
    )

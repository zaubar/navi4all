# Core Backend

This is a Python-based backend that integrates various data and routing services to expose unified APIs for the mobile app. It utilises a modular architecture with a routing engine adaptor (Valhalla; OpenTripPlanner was retired 2026-09) and geocoding providers (Pelias). The backend is designed to be scalable and maintainable, allowing for easy addition of new features and services in the future.


![Core backend architecture diagram](/docs/core-backend-structure-diagram.svg)

## System Requirements

- Docker Engine (or Docker Desktop)
- Docker Compose v2 (`docker compose`)
- Python 3.11.12+ (only needed for non-Docker local development)

## Environment Configuration

#### 1) Create `.env` from template

```bash
cd apps/core_backend
cp .env.example .env
```

Template file: `apps/core_backend/.env.example`

#### 2) Configure environment variables

- `VALHALLA_URL`: Valhalla endpoint, the only routing engine. `engine=valhalla`
  is the default on every routing endpoint; `engine=otp|otp_kl|hybrid` answers
  HTTP 400 `engine retired: use valhalla`.
- `OPEN_TRIP_PLANNER_URL`, `OPEN_TRIP_PLANNER_KL_URL`: retired, optional; accepted
  and ignored so an existing env still boots.
- `VALHALLA_PEDESTRIAN_DESTINATION_ONLY_PENALTY`: seconds charged when a walking
  route enters an `access=destination` edge (default `0`).
- `VALHALLA_AVOID_BAD_SURFACES_SMOOTH` / `_MEDIUM`: value of the fork's pedestrian
  option `avoid_bad_surfaces` (0..1) sent for `walk.surface_quality >= 0.7` and
  `0.3 < surface_quality < 0.7` (defaults `1.0` / `0.4`); not sent otherwise.
- `GEOCODING_PROVIDER`: `none` or `pelias`.
- `GEOCODING_PROVIDER_API_URL`: required when `GEOCODING_PROVIDER != none`.
- `GEOCODING_PROVIDER_API_KEY`: optional/provider-specific key.
- `USER_ENGAGEMENT_EVENT_FILE`: optional JSON file path for user engagement payload.
- `DEBUG`: set `true` to enable `/docs` and `/redoc`.

#### 3) Run Docker deployment

```bash
cd apps/core_backend
docker compose up --build -d
```

API at `http://localhost:8010`
# Core backend

![Project structure diagram](/docs/project-structure-diagram.svg)

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

- `OPEN_TRIP_PLANNER_URL`: OTP endpoint used by the `otp` engine.
- `OPEN_TRIP_PLANNER_KL_URL`: OTP endpoint used by the `otp_kl` engine.
- `VALHALLA_URL`: Valhalla base URL.
- `GEOCODING_PROVIDER`: `none` or `pelias`.
- `GEOCODING_PROVIDER_API_URL`: required when `GEOCODING_PROVIDER != none`.
- `GEOCODING_PROVIDER_API_KEY`: optional/provider-specific key.
- `USER_ENGAGEMENT_EVENT_FILE`: optional JSON file path for user engagement payload.
- `DEBUG`: set `true` to enable `/docs` and `/redoc`.

#### 3) Run Docker deployment

```bash
cd apps/core_backend
docker compose up --build
```

API at `http://localhost:8010`
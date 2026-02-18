# Navi4All • Multi-modal navigation for everyone

Navi4All is an open-source, multi-modal navigation platform designed to provide accessible navigation solutions for everyone, including those with disabilities.

#### Features
- General, vision-impaired and blind user profiles
- Search for destinations including Points of Interest (POIs), addresses and streets
- Favourite and sort destinations of your choice
- Multi-modal itinerary planing with customisable mode, speed and accessibility options
- Step-by-step navigation instructions with audio-cues and haptic feedback

![Navi4All](/apps/kl_mobile/assets/kl_mobile_screenshots.png)

## Codebase

![Project structure diagram](/docs/project-structure-diagram.svg)

- **Cross-platform mobile app**: Built using Flutter for Android and iOS
- **Core backend**: A Python-based backend that integrates various data and routing services to expose unified APIs for the mobile app
- **Services**:
    - **OpenTripPlanner**: Multi-modal routing with a focus on transit
    - **Valhalla**: Pedestrian routing with precise step-by-step instructions
    - **Pelias**: Geocoding and autocomplete for place search

## Deployment

### Services
- Fetch required routing data files and place in `services/otp_kl` and `services/valhalla` directories
- Start routing services with Docker Compose: `cd services && docker compose up -d`
- Full instructions: [services/README.md](services/README.md)

### Core backend

- Copy env template and configure: `cd apps/core_backend && cp .env.example .env`
- Start with Docker: `docker compose up --build`
- Full instructions: [apps/core_backend/README.md](apps/core_backend/README.md)

### `kl_mobile`

- Copy env template and configure: `cd apps/kl_mobile && cp .env.example .env`
- Run with env defines: `flutter run --dart-define-from-file=.env`
- Full instructions: [apps/kl_mobile/README.md](apps/kl_mobile/README.md)

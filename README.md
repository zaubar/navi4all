# Navi4All • Multi-modal navigation for everyone

Navi4All is an open-source, multi-modal navigation platform designed to provide accessible navigation solutions for everyone, including those with disabilities.

#### Features
- User profiles with accessibility preferences and custom settings
- Map view of your current location and nearby Points of Interest (POIs)
- Place search including POIs, addresses and streets
- Favourite and sort places of your choice
- Multi-modal itinerary planning with customisable mode, speed and accessibility options
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

### Core Backend

- Copy env template and configure: `cd apps/core_backend && cp .env.example .env`
- Start with Docker: `docker compose up --build`
- Full instructions: [apps/core_backend/README.md](apps/core_backend/README.md)

### Mobile App
Navi4All is designed to be a modular and customisable platform for the needs of different cities and regions. The app is currently deployed in the following regions:

- Navi4All - Kaiserslautern, Rhineland-Pfalz (DE): [kl_mobile](apps/kl_mobile/README.md)
- Park-Stark - Mannheim, Baden-Württemberg (DE): [ma_mobile](apps/ma_mobile/README.md)

Setup:
- Copy env template and configure: `cd apps/REGIONAL_APP_DIR && cp .env.example .env`
- Run with env defines: `flutter run --dart-define-from-file=.env`
- Full instructions can be found in the respective app directories:
    - [kl_mobile/README.md](apps/kl_mobile/README.md)
    - [ma_mobile/README.md](apps/ma_mobile/README.md)

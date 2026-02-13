# Navi4All • Multi-modal navigation for everyone

Navi4All is an open-source, multi-modal navigation platform designed to provide accessible navigation solutions for everyone, including those with disabilities.

### Kaiserslautern: Navi4All
Pedestrian and transit navigation with a focus on accessibility, including features for visually impaired users.

![Navi4All](/apps/kl_mobile/assets/kl_mobile_screenshots.png)

### Mannheim: Park-Stark
An overview of disabled parking spaces with real-time availability information, along with destination search, favourites and car navigation.

![Park-Stark](/apps/ma_mobile/assets/ma_mobile_screenshots.png)

## Codebase

![Project structure diagram](/docs/project-structure-diagram.svg)

- **Cross-platform mobile apps**: Built using Flutter for Android and iOS
- **Core backend**: A Python-based backend that integrates various data and routing services to expose unified APIs for the mobile app
- **Services**:
    - **OpenTripPlanner**: Multi-modal routing with a focus on transit
    - **Valhalla**: Pedestrian and car routing with precise step-by-step instructions
    - **Pelias**: Geocoding and autocomplete for place search

## Deployment

### Core backend

- Copy env template and configure: `cd apps/core_backend && cp .env.example .env`
- Start with Docker: `docker compose up --build`
- Full instructions: [apps/core_backend/README.md](apps/core_backend/README.md)

### `kl_mobile`

- Copy env template and configure: `cd apps/kl_mobile && cp .env.example .env`
- Run with env defines: `flutter run --dart-define-from-file=.env`
- Full instructions: [apps/kl_mobile/README.md](apps/kl_mobile/README.md)

### `ma_mobile`

- Copy env template and configure: `cd apps/ma_mobile && cp .env.example .env`
- Run with env defines: `flutter run --dart-define-from-file=.env`
- Full instructions: [apps/ma_mobile/README.md](apps/ma_mobile/README.md)




# Navi4All • Multi-modal navigation for everyone

Navi4All is an open-source, multi-modal navigation platform designed to provide accessible navigation solutions for everyone, including those with disabilities.

## Features
- User profiles with accessibility preferences and custom settings
- Map view of the user's location and nearby Points of Interest (POIs)
- Place search including POIs, addresses and streets
- Favourites with drag-and-drop sorting
- Multi-modal itinerary planning with customisable mode, speed and accessibility options
- Step-by-step navigation instructions with audio-cues and haptic feedback

## Codebase

![Project structure diagram](/docs/project-structure-diagram.svg)

- **Mobile App**: Cross-platform client for Android and iOS built with Flutter
- **Core Backend**: Python-based backend that integrates data and routing services to expose unified APIs for the mobile app
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
Designed to be a modular and customisable platform, Navi4All is currently deployed in the following regions:

- Navi4All - Kaiserslautern, Rhineland-Pfalz (DE): [kl_mobile](apps/kl_mobile/README.md)
- Park-Stark - Mannheim, Baden-Württemberg (DE): [ma_mobile](apps/ma_mobile/README.md)

#### Setup
- Copy env template and configure: `cd apps/REGIONAL_APP_DIR && cp .env.example .env`
- Run with env defines: `flutter run --dart-define-from-file=.env`
- Full instructions can be found in the respective app directories:
    - [kl_mobile/README.md](apps/kl_mobile/README.md)
    - [ma_mobile/README.md](apps/ma_mobile/README.md)

## Gallery

<h3><img src="apps/kl_mobile/android/app/src/main/ic_launcher-playstore.png" alt="Navi4All app icon" height="80" style="border-radius:16px; vertical-align:middle; margin-right:12px;" /><span style="display:inline-block; vertical-align:middle; line-height:1.3;">Navi4All<br/><span style="font-size:0.78em; font-weight:400;">Kaiserslautern, Rhineland-Pfalz (DE)</span></span></h3>

![Navi4All](/apps/kl_mobile/assets/kl_mobile_screenshots.png)

<h3><img src="apps/ma_mobile/android/app/src/main/ic_launcher-playstore.png" alt="Park-Stark app icon" height="80" style="border-radius:16px; vertical-align:middle; margin-right:12px;" /><span style="display:inline-block; vertical-align:middle; line-height:1.3;">Park-Stark<br/><span style="font-size:0.78em; font-weight:400;">Mannheim, Baden-Württemberg (DE)</span></span></h3>

<p>
    <a href="https://play.google.com/store/apps/details?id=de.plan4better.smartroots" style="display:inline-block; margin-right:12px;margin-top:12px;">
        <img src="docs/GetItOnGooglePlay_Badge_Web_color_English.svg" alt="Get it on Google Play" height="48" />
    </a>
    <a href="https://apps.apple.com/de/app/park-stark/id6752861087">
        <img src="docs/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg" alt="Download on the App Store" height="48" />
    </a>
</p>

![Park-Stark](/apps/ma_mobile/assets/ma_mobile_screenshots.png)

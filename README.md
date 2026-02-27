# Navi4All • Multi-modal navigation for everyone

Navi4All is an open-source, multi-modal map & navigation platform for mobile devices. With a focus on modular and customisable design, the app is easy to setup and deploy in new regions.

## Features
- **Map view** of the user's location and nearby Points of Interest (POIs)
- **Place search** including POIs, addresses and streets
- **Favourites** with drag-and-drop sorting
- **Accessibility profiles** with custom settings for different user needs
- **Multi-modal itinerary planning** with mode, speed and accessibility options
- **Step-by-step navigation** instructions with audio-cues and haptic feedback

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
Navi4All is currently deployed in the following regions:

- Kaiserslautern, Rhineland-Pfalz (DE) as ***Navi4All***
- Mannheim, Baden-Württemberg (DE) as ***Park-Stark***

#### Setup
- Copy env template and configure: `cd apps/REGIONAL_APP_DIR && cp .env.example .env`
- Run with env defines: `flutter run --dart-define-from-file=.env`
- Full instructions can be found in the respective app directories:
    - Kaiserslautern: [kl_mobile/README.md](apps/kl_mobile/README.md)
    - Mannheim: [ma_mobile/README.md](apps/ma_mobile/README.md)

## Gallery

<p>
  <img src="docs/app_icon_kl_mobile.png" alt="Navi4All app icon" width="80" align="left" />
  <br/>
  &nbsp;&nbsp;<strong>Navi4All</strong><br/>
  &nbsp;&nbsp;Kaiserslautern, Rhineland-Pfalz (DE)
  <br/><br/>
</p>

![Navi4All](apps/kl_mobile/assets/kl_mobile_screenshots.png)

<br/>

<p>
  <img src="docs/app_icon_ma_mobile.png" alt="Park-Stark app icon" width="80" align="left" />
  <br/>
  &nbsp;&nbsp;<strong>Park-Stark</strong><br/>
  &nbsp;&nbsp;Mannheim, Baden-Württemberg (DE)
  <br/><br/>
</p>

<a href="https://play.google.com/store/apps/details?id=de.plan4better.smartroots"><img src="docs/GetItOnGooglePlay_Badge_Web_color_English.svg" alt="Get it on Google Play" width="130" /></a>&nbsp;&nbsp;
<a href="https://apps.apple.com/de/app/park-stark/id6752861087"><img src="docs/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg" alt="Download on the App Store" width="120" /></a>

![Park-Stark](apps/ma_mobile/assets/ma_mobile_screenshots.png)

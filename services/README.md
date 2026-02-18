# Services

OpenTripPlanner and Valhalla are used for routing, while Pelias is used for geocoding and place search. These services are deployed separately from the core backend and mobile apps, allowing for flexibility in scaling and maintenance. The core backend integrates with these services to provide unified APIs for the mobile applications.

As multi-modal routing is a key feature of the Navi4All platform, a hybrid approach was chosen for itinerary planning. OpenTripPlanner results are used to find the best public transport connections, while Valhalla is used for high-precision step-by-step instructions for the pedestrian and car routing legs of an itinerary.

![Project structure diagram](/docs/project-structure-diagram.svg)

## System Requirements

- Docker Engine (or Docker Desktop)
- Docker Compose v2 (`docker compose`)

## Deploy Routing Services (OpenTripPlanner + Valhalla)

### 1) Create required directories

From the project root, create the service data directories:

```bash
mkdir -p services/otp_kl services/valhalla
```

### 2) Add required routing data files

After creating the directories, download and place the following files:

- `services/otp_kl/graph.obj`
	- https://assets.plan4better.de/otp/klnavi/graph.obj
- `services/valhalla/kl_ped_net.pbf`
	- https://assets.plan4better.de/otp/klnavi/kl_ped_net.pbf

*Note: The OpenTripPlanner graph file and Valhalla PBF file have been specially produced for Kaiserslautern. You may choose to alternatively use custom files for different regions or routing configurations.*

### 3) Verify files are present

```bash
ls -lh services/otp_kl/graph.obj
ls -lh services/valhalla/kl_ped_net.pbf
```

### 4) Start routing services with Docker Compose

From the `services` directory:

```bash
cd services
docker compose up
```

To run in detached mode:

```bash
docker compose up -d
```

To stop services:

```bash
docker compose down
```

## Deploy Geocoder (Pelias)

The geocoder (Pelias) is **not started from this `services` directory**.

Set up Pelias using the official Docker Compose project instructions for Germany:

- https://github.com/pelias/docker/tree/master/projects/germany

This link points to the **Germany region** setup. You may instead choose a Pelias project for a different region if that better matches your deployment needs.

Before starting the backend, ensure `apps/core_backend/.env` is correctly configured so API settings point to your running geocoder service.

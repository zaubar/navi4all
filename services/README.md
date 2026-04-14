# Services

OpenTripPlanner and Valhalla are used for routing, while Pelias is used for geocoding and place search. These services are deployed separately from the core backend and mobile app, allowing for flexibility in scaling and maintenance. The core backend integrates with these services to provide unified APIs for the mobile application.

As multi-modal routing is a key feature of the Navi4All platform, a hybrid approach was chosen for itinerary planning. OpenTripPlanner results are used to find the best public transport connections, while Valhalla is used for high-precision step-by-step instructions for the pedestrian routing legs of an itinerary.

![Services structure diagram](/docs/services-structure-diagram.svg)

## System Requirements

- Docker Engine (or Docker Desktop)

To install Docker, follow the [official setup instructions](https://docs.docker.com/engine/install/).

## Deploy Routing Services (OpenTripPlanner + Valhalla)

### 1) Create required directories

From the project root, create the service data directories:

```bash
mkdir -p services/otp_kl services/valhalla
```

### 2) Add required routing data files

After creating the directories, download and place the following files:

- `services/otp_kl/graph.obj`
```bash
wget -P services/otp_kl/ https://assets.plan4better.de/otp/klnavi/graph.obj
```
- `services/valhalla/kl_ped_net.pbf`
```bash
wget -P services/valhalla/ https://assets.plan4better.de/otp/klnavi/kl_ped_net.pbf
```

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
docker compose up -d
```

To view logs and run in the foreground (skip the `-d` option):

```bash
docker compose up
```

To stop services:

```bash
docker compose down
```

## Deploy Geocoder (Pelias)

The following instructions are specific to setting up Pelias in the Kaiserslautern region.

1. Create and change to a directory for the `pelias` deployment
```bash
mkdir pelias && cd pelias
```
2. Create a data directory
```bash
mkdir data
```
3. Install the Pelias command-line utility
```bash
git clone https://github.com/pelias/docker.git && cd docker
sudo ln -s "$(pwd)/pelias" /usr/local/bin/pelias
```
4. Download and place the configuration for Kaiserslautern
```bash
wget -P projects/ https://assets.plan4better.de/kaiserslautern.zip && cd projects
unzip kaiserslautern.zip && cd kaiserslautern/
```
5. Run the following commands to prepare and start the Pelias service

	_Note: This step may take a while._

```bash
pelias compose pull
pelias elastic start
pelias elastic wait
pelias elastic create
pelias download all
pelias prepare all
pelias import all
pelias compose up
```

6. Before starting the backend, ensure `apps/core_backend/.env` is correctly configured so API settings point to your running geocoder service.

### Additional Regions
To deploy Pelias in various other regions, follow the [official setup instructions](https://github.com/pelias/docker/tree/master/projects/germany).

_Note: This link points to the **Germany region** setup. You may instead choose a Pelias project for a different region if that better matches your deployment needs._

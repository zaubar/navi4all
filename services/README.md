# Services Setup

This folder is specifically for **routing services** used by Navi4All.

## Routing Services (OTP + Valhalla)

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

## Geocoder

The geocoder (Pelias) is **not started from this `services` directory**.

Set up Pelias using the official Docker Compose project instructions for Germany:

- https://github.com/pelias/docker/tree/master/projects/germany

This link points to the **Germany region** setup. You may instead choose a Pelias project for a different region if that better matches your deployment needs.

Before starting the backend, ensure `apps/core_backend/.env` is correctly configured so API settings point to your running geocoding service.

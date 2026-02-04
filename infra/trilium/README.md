# TriliumNext Local Environment

Local TriliumNext deployment for OpenClaw knowledge base integration.

## Quick Start

```bash
# Copy environment file
cp .env.example .env

# Start TriliumNext
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

## Access

- **URL:** http://127.0.0.1:3011
- **Port:** 3011 (non-default, registered in PORT_REGISTRY.md)
- **Bind:** 127.0.0.1 only (not exposed externally)

## Data Persistence

Data is stored in a Docker named volume:
- **Volume name:** `trilium-data`
- **Container path:** `/home/node/trilium-data`

To inspect:
```bash
docker volume inspect trilium-data
```

## Management Commands

```bash
# Start
docker compose up -d

# Stop
docker compose down

# Restart
docker compose restart

# Stop and remove volume (DELETES ALL DATA)
docker compose down -v
```

## Port Policy

This service uses a non-default port (3011 instead of 8080) to:
1. Avoid conflicts with other local services
2. Maintain registry compliance

If you need to change the port:
1. Update `.env` with new `TRILIUM_PORT` value
2. Update `PORT_REGISTRY.md` in project root
3. Update `/home/clayton/IDE/port-registry.json` (global registry)
4. Restart the container

## Troubleshooting

### Port already in use
```bash
lsof -i :3011  # Check what's using the port
```

### Container won't start
```bash
docker compose logs trilium  # Check container logs
```

### Connection refused
- Verify container is running: `docker compose ps`
- Verify port binding: `lsof -i :3011`
- Use `127.0.0.1` not `localhost` in URLs

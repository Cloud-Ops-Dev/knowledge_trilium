# Port Registry — knowledge_trilium

This file tracks port allocations for services in this project.

## Registered Ports

| Port | Service | Container | Status | Description |
|------|---------|-----------|--------|-------------|
| **3011** | TriliumNext | `trilium` | Reserved | Local knowledge base (127.0.0.1:3011) |

## Port Policy

- All services bind to `127.0.0.1` (not `localhost`) to avoid IPv6 issues
- Ports must be registered here AND in the global registry at `/home/clayton/IDE/port-registry.json`
- Check port availability before starting: `lsof -i :<port>`

## Global Registry Reference

This project's ports are also tracked in the workspace-wide registry:
- **Location:** `/home/clayton/IDE/port-registry.json`
- **Range:** 3000-3099 (Frontend Development)

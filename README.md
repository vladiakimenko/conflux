# Conflux

Minimal Docker-based L4 TCP/UDP forwarder manager.

Conflux dynamically creates and manages independent `socat`
containers using Bash and Docker.

It provides simple port forwarding between two servers without
protocol inspection, TLS termination, or application-level logic.

## Architecture

```text
Client (protocol specific)
   |
   v
Conflux (first-hop VPS)
   |
   | transparent TCP / UDP relay
   |
   v
Destination VPS (actual proxy service)
```

Conflux is a transparent forwarding layer.
All application-level intelligence resides at the destination.

## Requirements

- Linux
- Docker
- Bash

The user running Conflux must have permission to access Docker.

## Installation

Make the scripts executable:

```bash
chmod +x forwarder
chmod +x lib/*.sh
```

Check Docker:

```bash
docker info
```

Display help:

```bash
./forwarder help
```

## Adding forwarders

Every forwarder requires:

- A unique name
- A protocol
- An incoming IP address
- An incoming port
- A destination IPv4 address
- A destination port

`--listen-ip` specifies the local IP address on which the forwarder listens.
Use `0.0.0.0` to listen on all IPv4 interfaces.

Example:
```bash
./forwarder add \
    --name my_proxy \
    --protocol tcp \
    --listen-ip 0.0.0.0 \
    --listen-port 443 \
    --target-ip 200.100.10.100 \
    --target-port 443
```

## Different incoming and destination ports

There is no requirement for incoming and destination ports
to match.

For example:

```bash
./forwarder add \
    --name alternate-grpc \
    --protocol tcp \
    --listen-ip 0.0.0.0 \
    --listen-port 8443 \
    --target-ip 10.20.0.5 \
    --target-port 443
```

This creates:

```text
Conflux:8443 -> 10.20.0.5:443
```

## Listening IP

The `--listen-ip` option specifies the local IP address
on which the forwarder accepts incoming connections.

By default, the script uses:

```text
0.0.0.0
```

This makes the forwarder accessible through all IPv4
interfaces.

You can restrict a forwarder to a particular local interface:

```bash
./forwarder add \
    --name internal-proxy \
    --protocol tcp \
    --listen-ip 127.0.0.1 \
    --listen-port 8080 \
    --target-ip 10.20.0.5 \
    --target-port 8080
```

The listening IP must be assigned to the host.

## Managing forwarders

### List all forwarders

```bash
./forwarder list
```

Displays:

- Name
- Container state
- Protocol
- Incoming IP and port
- Destination IP and port

Both running and stopped containers are included.

The information is read directly from Docker labels.
There is no separate inventory file.

### Restart a forwarder

```bash
./forwarder restart reality
```

### Stop a forwarder

```bash
./forwarder stop reality
```

Stopping a container does not remove it.
Its configuration remains available through Docker labels.

You can start it again using `restart`.

### Remove a forwarder

```bash
./forwarder remove reality
```

This permanently removes its container and labels.

### Replace an existing forwarder

Use `--replace` to remove and recreate an existing
forwarder with updated settings:

```bash
./forwarder add \
    --name reality \
    --protocol tcp \
    --listen-ip 0.0.0.0 \
    --listen-port 31816 \
    --target-ip 10.20.0.5 \
    --target-port 443 \
    --replace
```

The existing container is removed before the replacement
is created. If creation fails, the old container is not
automatically restored.

### Stop all forwarders

```bash
./forwarder stop-all
```

Stops all running managed containers.

Their configurations remain intact.

### Remove all forwarders

```bash
./forwarder remove-all
```

Asks for confirmation before permanently removing
all managed containers.

## Docker containers

Each forwarder runs independently.

Container naming:

```text
conflux-<forwarder-name>
```

Example:

```bash
docker ps -a --filter label=managed-by=conflux
```

Inspect a container:

```bash
docker inspect conflux-reality
```

View logs:

```bash
docker logs conflux-reality
```

Follow logs:

```bash
docker logs -f conflux-reality
```

Containers use:

```text
restart: unless-stopped
```

They automatically start after Docker or the host restarts,
unless explicitly stopped.

## Docker labels

Each container stores its configuration in Docker labels:

```text
managed-by=conflux
forwarder.name=reality
forwarder.protocol=tcp
forwarder.listen-ip=0.0.0.0
forwarder.listen-port=31816
forwarder.target-ip=217.177.11.239
forwarder.target-port=31816
```

These labels are the source of truth.

The `list` command reads them directly.

You can inspect them using:

```bash
docker inspect conflux-reality
```

## Image configuration

By default, Conflux uses:

```text
alpine/socat:latest
```

You can override this using an environment variable:

```bash
CONFLUX_IMAGE=alpine/socat:latest ./forwarder add ...
```

## Networking and security

- Ensure the destination service is reachable from Conflux.
- Open required incoming ports in the VPS firewall.
- Ensure Docker can publish the requested ports.
- Avoid exposing management panels publicly without access restrictions.
- Containers use Docker's default bridge networking.
- Host networking is not required.

Conflux does not encrypt traffic independently.
Any encryption is provided by the forwarded application protocol.

## Troubleshooting

### Container fails to start

```bash
docker ps -a
docker logs conflux-reality
```

### Port already in use

Check listeners:

```bash
sudo ss -lntup
```

Docker will reject publishing a port it cannot bind.

### Destination unreachable

Test TCP connectivity from the Conflux host:

```bash
nc -vz 200.200.10.100 443
```

### Check managed containers

```bash
docker ps -a --filter label=managed-by=conflux
```

### Inspect forwarding configuration

```bash
docker inspect conflux-reality \
    --format '{{json .Config.Labels}}'
```

## License

MIT

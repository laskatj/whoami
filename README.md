# whoami

[![Docker Pulls](https://img.shields.io/docker/pulls/traefik/whoami.svg)](https://hub.docker.com/r/traefik/whoami/)
[![Build Status](https://github.com/traefik/whoami/workflows/Main/badge.svg?branch=master)](https://github.com/traefik/whoami/actions)

Tiny Go webserver that prints OS information and HTTP request to output.

## Usage

### Paths

#### `/[?wait=d]`

Returns the whoami information (request and network information).

The optional `wait` query parameter can be provided to tell the server to wait before sending the response.
The duration is expected in Go's [`time.Duration`](https://golang.org/pkg/time/#ParseDuration) format (e.g. `/?wait=100ms` to wait 100 milliseconds).

The optional `env` query parameter can be set to `true` to add the environment variables to the response.

#### `/api`

Returns the whoami information (and some extra information) as JSON.

The optional `env` query parameter can be set to `true` to add the environment variables to the response.

#### `/bench`

Always return the same response (`1`).

#### `/data?size=n[&unit=u]`

Creates a response with a size `n`.

The unit of measure, if specified, accepts the following values: `KB`, `MB`, `GB`, `TB` (optional, default: bytes).

#### `/echo`

WebSocket echo.

#### `/health`

Heath check.

- `GET`, `HEAD`, ...: returns a response with the status code defined by the `POST`
- `POST`: changes the status code of the `GET` (`HEAD`, ...) response.

### Flags

| Flag      | Env var              | Description                             |
|-----------|----------------------|-----------------------------------------|
| `cert`    |                      | Give me a certificate.                  |
| `key`     |                      | Give me a key.                          |
| `cacert`  |                      | Give me a CA chain, enforces mutual TLS |
| `port`    | `WHOAMI_PORT_NUMBER` | Give me a port number. (default: `80`)  |
| `name`    | `WHOAMI_NAME`        | Give me a name.                         |
| `verbose` |                      | Enable verbose logging.                 |

## Examples

```console
$ docker run -d -p 8080:80 --name iamfoo traefik/whoami

$ curl http://localhost:8080
Hostname: 9c9c93da54b5
IP: 127.0.0.1
IP: ::1
IP: 172.17.0.2
RemoteAddr: 172.17.0.1:41040
GET / HTTP/1.1
Host: localhost:8080
User-Agent: curl/8.5.0
Accept: */*
```

```console
# updates health check status
$ curl -X POST -d '500' http://localhost:8080/health

# calls the health check
$ curl -v http://localhost:8080/health
* Host localhost:8080 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:8080...
* Connected to localhost (::1) port 8080
> GET /health HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/8.5.0
> Accept: */*
> 
< HTTP/1.1 500 Internal Server Error
< Date: Fri, 18 Apr 2025 13:36:02 GMT
< Content-Length: 0
```

```console
$ openssl req -newkey rsa:4096 \
    -x509 \
    -sha256 \
    -days 3650 \
    -nodes \
    -out ./certs/example.crt \
    -keyout ./certs/example.key

$ docker run -d -p 8080:80 -v ./certs:/certs --name iamfoo traefik/whoami --cert /certs/example.crt --key /certs/example.key

$ curl https://localhost:8080 -k --cert certs/example.crt  --key certs/example.key
Hostname: 25bc0df47b95
IP: 127.0.0.1
IP: ::1
IP: 172.17.0.2
RemoteAddr: 172.17.0.1:50278
Certificate[0] Subject: CN=traefik.io,O=TraefikLabs,L=Lyon,ST=France,C=FR
GET / HTTP/1.1
Host: localhost:8080
User-Agent: curl/8.5.0
Accept: */*
```

```console
$ docker run -d -p 8080:80 --name iamfoo traefik/whoami

$ grpcurl -plaintext -proto grpc.proto localhost:8080 whoami.Whoami/Whoami
{
  "hostname": "5a45e21984b4",
  "iface": [
    "127.0.0.1",
    "::1",
    "172.17.0.2"
  ]
}

$ grpcurl -plaintext -proto grpc.proto localhost:8080 whoami.Whoami/Bench
{
  "data": 1
}
```

```yml
version: '3.9'

services:
  whoami:
    image: traefik/whoami
    command:
       # It tells whoami to start listening on 2001 instead of 80
       - --port=2001
       - --name=iamfoo
```

## Health Check

The whoami container includes a lightweight health check binary that uses Go's built-in HTTP client to verify the container's health status.

### Built-in Health Check

The container automatically includes a health check that runs every 30 seconds:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD ["/healthcheck"]
```

### Docker Compose Usage

```yml
version: '3.9'

services:
  whoami:
    build: .
    ports:
      - "8080:80"
    healthcheck:
      test: ["CMD", "/healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s
```

### Custom Health Check Parameters

The health check binary supports configurable parameters:

```bash
# Default: checks http://localhost:80/health with 5s timeout and 3 retries
/healthcheck

# Custom URL, timeout, and retry settings
/healthcheck -url=http://localhost:80/health -timeout=3s -retries=2

# Available flags:
#   -url      Health check URL (default: http://localhost:80/health)
#   -timeout  Request timeout (default: 5s)
#   -retries  Number of retries (default: 3)
#   -interval Retry interval (default: 1s)
```

### Manual Health Check

You can also run the health check manually from within the container:

```bash
docker exec <container_name> /healthcheck
```

The health check will exit with:
- **Exit code 0**: Container is healthy
- **Exit code 1**: Container is unhealthy

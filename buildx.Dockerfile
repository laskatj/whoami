# syntax=docker/dockerfile:1.2
FROM golang:1-alpine as builder

RUN apk --no-cache --no-progress add git ca-certificates tzdata make \
    && update-ca-certificates \
    && rm -rf /var/cache/apk/*

WORKDIR /go/whoami

# Download go modules
COPY go.mod .
COPY go.sum .
RUN GO111MODULE=on GOPROXY=https://proxy.golang.org go mod download

COPY . .

RUN make build
# Build health check binary
RUN CGO_ENABLED=0 go build -o healthcheck healthcheck.go

# syntax=docker/dockerfile:1.2
# Create a minimal container to run a Golang static binary
FROM scratch

COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /go/whoami/whoami /
COPY --from=builder /go/whoami/healthcheck /healthcheck

ENTRYPOINT ["/whoami"]
EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD ["/healthcheck"]

.PHONY: default check test build image healthcheck

IMAGE_NAME := traefik/whoami

default: check test build

build:
	CGO_ENABLED=0 go build -a --trimpath --installsuffix cgo --ldflags="-s" -o whoami

healthcheck:
	CGO_ENABLED=0 go build -a --trimpath --installsuffix cgo --ldflags="-s" -o healthcheck ./cmd/healthcheck

test:
	go test -v -cover ./...

check:
	golangci-lint run

image:
	docker build -t $(IMAGE_NAME) .

protoc:
	 protoc --proto_path . ./grpc.proto --go-grpc_out=./ --go_out=./

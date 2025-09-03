ARG SERVER_BUILDER_IMAGE_VERSION=1.24-alpine3.21
ARG RUNTIME_IMAGE_VERSION=3.21

FROM golang:${SERVER_BUILDER_IMAGE_VERSION} AS server-builder

WORKDIR /app

RUN apk add --no-cache gcc musl-dev

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG BUILD_ENVIRONMENT="production"
ARG BUILD_VERSION="dev"
ARG BUILD_DATE="unknown"
RUN mkdir -p ./bin && \
  go build -ldflags "-s -w \
  -X main.buildVersion=${BUILD_VERSION} \
  -X main.buildTime=${BUILD_DATE} \
  -X main.buildEnvironment=${BUILD_ENVIRONMENT}" \
  -a \
  -o ./bin/server \
  cmd/server/main.go

FROM alpine:${RUNTIME_IMAGE_VERSION}

COPY --from=client-builder /app/client/web/dist /app/public
COPY --from=server-builder /app/bin/server /app/

CMD ["/app/server"]

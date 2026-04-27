# Build stage
FROM golang:1.25-alpine AS builder

# Install git for fetching dependencies
RUN apk add --no-cache git

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download
RUN go install github.com/swaggo/swag/cmd/swag@latest

# Copy source code
COPY . .

# Generate Swagger docs
RUN swag init

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/hackers-api

# Final stage
FROM alpine:3.21

# Add CA certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

# Create non-root user for security (CKV_DOCKER_3)
RUN addgroup -g 1000 appgroup && \
    adduser -D -u 1000 -G appgroup appuser

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/hackers-api .

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Add health check (CKV_DOCKER_2)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run the application
CMD ["./hackers-api"] 

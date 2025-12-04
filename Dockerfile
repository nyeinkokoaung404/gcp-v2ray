# Stage 1: Builder - Download and extract V2Ray
FROM alpine:3.19 AS builder

ARG V2RAY_VERSION=v5.8.1
ARG TARGETARCH=amd64

RUN apk add --no-cache curl unzip ca-certificates && \
    mkdir -p /tmp/v2ray

# Convert architecture naming
RUN case "${TARGETARCH}" in \
      amd64) ARCH="64" ;; \
      arm64) ARCH="arm64-v8a" ;; \
      arm) ARCH="arm32-v7a" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/v2ray.zip \
      "https://github.com/v2fly/v2ray-core/releases/download/${V2RAY_VERSION}/v2ray-linux-${ARCH}.zip" && \
    unzip /tmp/v2ray.zip -d /tmp/v2ray/ && \
    rm -f /tmp/v2ray.zip

# Stage 2: Runtime - Minimal image
FROM alpine:3.19

LABEL maintainer="your-email@example.com" \
      org.opencontainers.image.source="https://github.com/nyeinkokoaung404" \
      org.opencontainers.image.description="V2Ray VLESS Proxy Server" \
      org.opencontainers.image.licenses="MIT"

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata libcap && \
    # Create non-root user
    addgroup -g 1000 -S v2ray && \
    adduser -u 1000 -S v2ray -G v2ray && \
    # Set timezone
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime && \
    # Clean cache
    rm -rf /var/cache/apk/*

# Copy V2Ray binaries from builder
COPY --from=builder --chown=v2ray:v2ray /tmp/v2ray/v2ray /usr/local/bin/
COPY --from=builder --chown=v2ray:v2ray /tmp/v2ray/v2ctl /usr/local/bin/
COPY --from=builder --chown=v2ray:v2ray /tmp/v2ray/geoip.dat /usr/local/share/v2ray/
COPY --from=builder --chown=v2ray:v2ray /tmp/v2ray/geosite.dat /usr/local/share/v2ray/

# Copy configuration
COPY --chown=v2ray:v2ray config.json /etc/v2ray/config.json

# Set capabilities for binding to privileged ports (optional)
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/v2ray || true

# Create directories with proper permissions
RUN mkdir -p /var/log/v2ray && \
    chown -R v2ray:v2ray /var/log/v2ray /etc/v2ray && \
    chmod 755 /usr/local/bin/v2ray /usr/local/bin/v2ctl && \
    chmod 644 /etc/v2ray/config.json

# Health check (requires API enabled in config)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD /usr/local/bin/v2ray api stats --server=127.0.0.1:10085 || exit 1

# Expose ports
EXPOSE 8080

# Switch to non-root user
USER v2ray

# Run V2Ray
ENTRYPOINT ["/usr/local/bin/v2ray"]
CMD ["run", "-config", "/etc/v2ray/config.json"]

FROM alpine:latest

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    unzip

# Download and install v2ray
RUN wget https://github.com/v2fly/v2ray-core/releases/download/v5.7.0/v2ray-linux-64.zip && \
    unzip v2ray-linux-64.zip && \
    rm v2ray-linux-64.zip && \
    chmod +x v2ray

# Copy config file
COPY config.json .

# Expose port (Cloud Run requires this)
EXPOSE 8080

# Health check and start
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Start v2ray on port 8080
CMD ["./v2ray", "run", "-config", "config.json"]

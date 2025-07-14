FROM teddysun/v2ray:latest

# Expose the correct container port (8080)
EXPOSE 8080

# Copy the VLESS config into the container
COPY config.json /etc/v2ray/config.json

# Run V2Ray with the config file
CMD ["v2ray", "run", "-config", "/etc/v2ray/config.json"]


# join telegram https://t.me/ahs93  for new updates 
# my telegram username is @ahs93

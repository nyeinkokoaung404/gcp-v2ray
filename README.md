
# ⚡ VLESS over WebSocket (WS) on Google Cloud Run + CDN

This project allows you to deploy a **VLESS proxy** server over **WebSocket** using **Xray-core**, fully containerized with Docker and deployed to **Google Cloud Run**, fronted by **Google Cloud CDN**.

---

## 🌟 Features

- ✔️ VLESS over WebSocket (WS)
- ✔️ Deployed on Google Cloud Run (serverless + autoscaling)
- ✔️ Works with Google Cloud Load Balancer + CDN
- ✔️ Dockerized and easy to deploy
- ✔️ Designed for domain fronting, bypassing, FreeNet

---

## ⚠️ Important Notice

- ❌ Google Cloud IPs starting with `34.*` and `35.*` **do NOT work** reliably with V2Ray/VLESS.
- ✅ Use a **custom domain with HTTPS** via **Google Load Balancer + CDN** for proper functionality.

---

## 🔧 Configuration Overview

### `config.json`
```json
{
  "inbounds": [
    {
      "port": 8080,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "d1b77b27-8ceb-41ac-ba5d-0f4b61ca8ab8",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/t.me/kokhant834"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
````

> 🔐 Replace the UUID with your own for security.

---

## 🐳 Docker Deployment

### Step 1: Build Docker Image

```bash
docker build -t gcr.io/YOUR_PROJECT_ID/vless-ws .
```

### Step 2: Push to Container Registry

```bash
docker push gcr.io/YOUR_PROJECT_ID/vless-ws
```

### Step 3: Deploy to Google Cloud Run

```bash
gcloud run deploy vless-ws \
  --image gcr.io/YOUR_PROJECT_ID/vless-ws \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --port 8080
```

> ☑️ Make sure to allow **unauthenticated access**.

---

## 🌐 Setup Google CDN + Load Balancer

1. Go to **Google Cloud Console > Network services > Load balancing**
2. Create a new **HTTP(S) Load Balancer**
3. Add your **Cloud Run service** as a backend
4. **Enable CDN** on the backend
5. Attach a **custom domain** and **SSL certificate**

> 🔒 HTTPS is handled by Google; no need to configure TLS in Xray.

---

## 📲 Client Configuration (V2Ray, Xray)

Use the following settings in your client app:

| Setting    | Value                                  |
| ---------- | -------------------------------------- |
| Protocol   | VLESS                                  |
| Address    | `your.domain.com`                      |
| Port       | `443` (HTTPS)                          |
| UUID       | `d1b77b27-8ceb-41ac-ba5d-0f4b61ca8ab8` |
| Encryption | none                                   |
| Transport  | WebSocket (WS)                         |
| WS Path    | `/tg-@kokhant834`                         |
| TLS        | Yes (via Google CDN)                   |

---

## 🧪 Tested Clients

* ✅ **Windows**: V2RayN
* ✅ **Android**: SagerNet / V2RayNG
* ✅ **iOS**: Shadowrocket / V2Box
* ✅ **macOS/Linux**: Xray CLI

---

## 🛡 Tips for Better Stealth

* Use random UUIDs and WS paths
* Combine with Cloudflare DNS and proxy
* Rotate domains if needed
* Enable logs in debug environments only

---

## 📄 License

This project is licensed under the **MIT License**.

---

## 👤 Author

Made with ❤️ by [kokhant](https://t.me/kokhant834)

---



# Session 6–7 — Docker Fundamentals

**Name:** Ridaa Mirza
**Enrollment No:** 24BCS10394

Six Hello World web applications, each in its own folder with its own Dockerfile.

> **Status:** all application code and Dockerfiles are complete and committed. The build/run outputs and screenshots still need to be captured — see [Pending](#pending) at the bottom.

---

## Folder structure

```
05-docker-apps/
├── nodejs-app/     Node.js + Express      → port 3000
├── python-app/     Python + Flask         → port 5000
├── java-app/       Java + JDK HttpServer  → port 8000
├── Apache-app/     Apache httpd           → port 80
├── React-app/      React + Vite → Nginx   → port 80
└── nginx-app/      Nginx                  → port 80
```

---

## Quick reference — build and run all six

| App | Build | Run | URL |
|---|---|---|---|
| Node.js | `docker build -t hello-node ./nodejs-app` | `docker run -d -p 3000:3000 --name hello-node hello-node` | http://localhost:3000 |
| Python | `docker build -t hello-python ./python-app` | `docker run -d -p 5000:5000 --name hello-python hello-python` | http://localhost:5000 |
| Java | `docker build -t hello-java ./java-app` | `docker run -d -p 8000:8000 --name hello-java hello-java` | http://localhost:8000 |
| Apache | `docker build -t hello-apache ./Apache-app` | `docker run -d -p 8081:80 --name hello-apache hello-apache` | http://localhost:8081 |
| React | `docker build -t hello-react ./React-app` | `docker run -d -p 8082:80 --name hello-react hello-react` | http://localhost:8082 |
| Nginx | `docker build -t hello-nginx ./nginx-app` | `docker run -d -p 8083:80 --name hello-nginx hello-nginx` | http://localhost:8083 |

Apache, React, and Nginx all listen on port 80 inside their containers, so each is mapped to a **different host port** (8081, 8082, 8083) to avoid a collision.

---

## 1. `nodejs-app` — Node.js + Express

**Files:** [`server.js`](nodejs-app/server.js), [`package.json`](nodejs-app/package.json), [`Dockerfile`](nodejs-app/Dockerfile)

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY server.js ./
EXPOSE 3000
CMD ["node", "server.js"]
```

`package.json` is copied **before** the source code on purpose. Docker caches each layer, so as long as dependencies do not change, editing `server.js` reuses the cached `npm install` layer instead of re-downloading everything.

```bash
docker build -t hello-node ./nodejs-app
docker run -d -p 3000:3000 --name hello-node hello-node
curl http://localhost:3000
```

Expected: **Hello World from Node.js**

---

## 2. `python-app` — Python + Flask

**Files:** [`app.py`](python-app/app.py), [`requirements.txt`](python-app/requirements.txt), [`Dockerfile`](python-app/Dockerfile)

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py ./
EXPOSE 5000
CMD ["python", "app.py"]
```

Flask binds to `0.0.0.0`, not `127.0.0.1`. This matters: a server bound to loopback inside a container is unreachable from the host even with `-p` published, because the port mapping forwards to the container's external interface.

```bash
docker build -t hello-python ./python-app
docker run -d -p 5000:5000 --name hello-python hello-python
curl http://localhost:5000
```

Expected: **Hello World from Python**

---

## 3. `java-app` — Java + JDK HttpServer

**Files:** [`HelloWorld.java`](java-app/HelloWorld.java), [`Dockerfile`](java-app/Dockerfile)

```dockerfile
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY HelloWorld.java ./
RUN javac HelloWorld.java

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/HelloWorld.class ./
EXPOSE 8000
CMD ["java", "HelloWorld"]
```

This is a **multi-stage build**: stage one uses the full **JDK** to compile, stage two ships only the compiled `.class` file on the much smaller **JRE**. The compiler never reaches the final image.

The app uses the JDK's built-in `com.sun.net.httpserver.HttpServer`, so no Maven or Gradle is required.

```bash
docker build -t hello-java ./java-app
docker run -d -p 8000:8000 --name hello-java hello-java
curl http://localhost:8000
```

Expected: **Hello World from Java**

---

## 4. `Apache-app` — Apache HTTP Server

**Files:** [`index.html`](Apache-app/index.html), [`Dockerfile`](Apache-app/Dockerfile)

```dockerfile
FROM httpd:2.4-alpine
COPY index.html /usr/local/apache2/htdocs/index.html
EXPOSE 80
```

No `CMD` is needed — the `httpd` base image already runs the server in the foreground. Apache's document root inside the official image is `/usr/local/apache2/htdocs/`.

```bash
docker build -t hello-apache ./Apache-app
docker run -d -p 8081:80 --name hello-apache hello-apache
curl http://localhost:8081
```

Expected: **Hello World from Apache**

---

## 5. `React-app` — React + Vite, served by Nginx

**Files:** [`src/App.jsx`](React-app/src/App.jsx), [`src/main.jsx`](React-app/src/main.jsx), [`index.html`](React-app/index.html), [`vite.config.js`](React-app/vite.config.js), [`package.json`](React-app/package.json), [`Dockerfile`](React-app/Dockerfile)

```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
```

This is the standard production pattern for a frontend. React compiles to **static HTML, CSS and JS** — Node is only needed at build time. Stage two therefore discards Node entirely and serves the `dist/` output from Nginx, cutting the image from roughly 1 GB to around 50 MB.

```bash
docker build -t hello-react ./React-app
docker run -d -p 8082:80 --name hello-react hello-react
curl http://localhost:8082
```

Expected: **Hello World from React**

---

## 6. `nginx-app` — Nginx

**Files:** [`index.html`](nginx-app/index.html), [`Dockerfile`](nginx-app/Dockerfile)

```dockerfile
FROM nginx:1.27-alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
```

Nginx's default document root is `/usr/share/nginx/html/`, so overwriting `index.html` there replaces the default welcome page.

```bash
docker build -t hello-nginx ./nginx-app
docker run -d -p 8083:80 --name hello-nginx hello-nginx
curl http://localhost:8083
```

Expected: **Hello World from Nginx**

---

## Verifying all six at once

```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

for p in 3000 5000 8000 8081 8082 8083; do
  echo "--- port $p ---"
  curl -s "http://localhost:$p" | grep -o "Hello World from [A-Za-z.]*"
done
```

Cleanup:

```bash
docker rm -f hello-node hello-python hello-java hello-apache hello-react hello-nginx
docker rmi hello-node hello-python hello-java hello-apache hello-react hello-nginx
```

---

## Notes on `EXPOSE` vs `-p`

A point worth being precise about, since it is a common interview question:

- `EXPOSE 3000` in a Dockerfile is **documentation only**. It publishes nothing and opens no port on the host.
- `-p 3000:3000` at run time is what actually creates the mapping — `hostPort:containerPort`.

An image with `EXPOSE` but run without `-p` is unreachable from the host.

---

## Pending

Docker is not installed on the machine this repository was prepared on, so the following still need to be captured and added:

- [ ] `docker build` output for each of the six apps
- [ ] `docker ps` showing all six containers running
- [ ] Browser screenshots of each Hello World page → save to `screenshots/`
- [ ] `docker images` showing the resulting image sizes

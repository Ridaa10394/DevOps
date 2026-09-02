# Session 6–7 — Docker Multi-Stage Build

**Name:** Ridaa Mirza
**Enrollment No:** 24BCS10394

> **Status:** the upstream application is vendored in [`app/`](app/) and all commands are documented. The screenshots still need to be captured — see [Pending](#pending).

---

## Task 1 — Run the multi-stage Dockerfile

### Source

The multi-stage application comes from the course repository:

```bash
git clone https://github.com/Nency-Ravaliya/devops-heros.git
cd devops-heros/session6-7-docker/multi-stage-dockerfile
```

A copy is vendored here under [`app/`](app/) so this folder is self-contained:

```
06-multi-stage/app/
├── Dockerfile
├── package.json
└── server.js
```

### The Dockerfile

```dockerfile
# -------------------------
# Stage 1: Build
# -------------------------
FROM node:24-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

# -------------------------
# Stage 2: Production
# -------------------------
FROM node:24-alpine AS production
WORKDIR /app
COPY --from=builder /app/package*.json ./
RUN npm install --omit=dev
COPY --from=builder /app/server.js ./
EXPOSE 3000
CMD ["npm", "start"]
```

### ⚠️ Important — the container listens on 3000, not 8080

`server.js` hardcodes `const PORT = 3000`, and the Dockerfile declares `EXPOSE 3000`. The assignment requires the application to be reachable on **port 8080**.

Both are satisfied by the **port mapping**, not by changing the code:

```
-p 8080:3000
   │     └── container port (what the app listens on)
   └──────── host port (what the assignment requires)
```

Running it with `-p 8080:8080` would fail — nothing inside the container listens on 8080.

### Build and run

```bash
cd app

# Build
docker build -t multistage-hello .

# Run, mapping host 8080 to container 3000
docker run -d -p 8080:3000 --name multistage-app multistage-hello

# Verify the container is up
docker ps

# Access the application
curl http://localhost:8080
```

Then open **http://localhost:8080** in a browser.

### Expected result

```html
<h1>Hello World from Docker Multi-Stage Build!</h1>
```

Expected `docker ps` output:

```
CONTAINER ID   IMAGE               COMMAND         STATUS         PORTS                                       NAMES
<id>           multistage-hello    "npm start"     Up X seconds   0.0.0.0:8080->3000/tcp, [::]:8080->3000/tcp  multistage-app
```

The `PORTS` column showing `0.0.0.0:8080->3000/tcp` is the evidence the assignment asks for.

---

## Task 2 — Documentation

**Name:** Ridaa Mirza
**Enrollment Number:** 24BCS10394

### Screenshot 1 — application running on port 8080

<!-- Add after capturing: ![App on port 8080](screenshots/app-8080.png) -->

_To be added: browser at `http://localhost:8080` showing "Hello World from Docker Multi-Stage Build!"_

### Screenshot 2 — `docker ps` showing the container on port 8080

<!-- Add after capturing: ![docker ps](screenshots/docker-ps.png) -->

_To be added: terminal output of `docker ps` with the `PORTS` column showing `0.0.0.0:8080->3000/tcp`._

---

## What a multi-stage build is, and why it matters

A multi-stage Dockerfile uses **several `FROM` statements**. Each `FROM` starts a fresh stage with its own filesystem. `COPY --from=<stage>` pulls selected artifacts forward, and **everything else in that stage is discarded**.

The problem it solves: building software needs compilers, dev dependencies, and toolchains. Running it usually does not. Without multi-stage builds, all of that ships to production — bloating the image and widening the attack surface.

### Sizes in practice

| Approach | Typical size |
|---|---|
| Single-stage Node build (with dev dependencies) | ~1.1 GB |
| Multi-stage, production dependencies only | ~180 MB |
| Multi-stage compiled to static binary on `scratch` | ~15 MB |

### What this Dockerfile actually gains

Stage 1 runs a full `npm install` including devDependencies. Stage 2 starts clean and installs with `--omit=dev`, then copies only `server.js` across. The devDependencies exist during the build and never reach the final image.

### Benefits

1. **Smaller images** — faster to push, pull, and deploy.
2. **Better security** — no compilers or build tools in production to exploit.
3. **No leaked secrets** — build-time credentials stay in the discarded stage.
4. **One file** — build and runtime defined together, no external build script.

### Useful multi-stage techniques

```dockerfile
# Name your stages
FROM node:20 AS builder

# Copy from a named stage
COPY --from=builder /app/dist ./dist

# Copy from an external image, no build needed
COPY --from=nginx:alpine /etc/nginx/nginx.conf ./

# Build only up to a specific stage
# docker build --target builder -t myapp:build .
```

---

## Task 3 — Deploy at least 3 application types

Six applications (Node.js, Python, Java, Apache, React, Nginx) are implemented in [`../05-docker-apps/`](../05-docker-apps/), which exceeds the requirement of three.

The three named in the assignment:

| Type | Folder | Build | Run |
|---|---|---|---|
| Node.js | [`../05-docker-apps/nodejs-app/`](../05-docker-apps/nodejs-app/) | `docker build -t hello-node .` | `docker run -d -p 3000:3000 hello-node` |
| Python | [`../05-docker-apps/python-app/`](../05-docker-apps/python-app/) | `docker build -t hello-python .` | `docker run -d -p 5000:5000 hello-python` |
| Java | [`../05-docker-apps/java-app/`](../05-docker-apps/java-app/) | `docker build -t hello-java .` | `docker run -d -p 8000:8000 hello-java` |

Two of them — `java-app` and `React-app` — are themselves multi-stage builds, applying the technique from Task 1.

---

## Pending

Docker is not installed on the machine this repository was prepared on. Still to capture:

- [ ] `docker build` output for the multi-stage image
- [ ] Browser screenshot at `http://localhost:8080` → `screenshots/app-8080.png`
- [ ] `docker ps` screenshot showing `0.0.0.0:8080->3000/tcp` → `screenshots/docker-ps.png`
- [ ] `docker images` output comparing image sizes

# Session 8 — Docker Networking & Volumes

**Name:** Ridaa Mirza
**Enrollment No:** 24BCS10394

> **Status:** all commands, configuration, and the bind-mount content are prepared. Screenshots still need to be captured — see [Pending](#pending).

---

## Task 1 — Docker Container Networking

**Goal:** 3 containers (frontend, backend, database), 3 networks, with the **backend attached to two networks**, then verify connectivity.

### Topology

```
   frontend-net                      backend-net
  ┌──────────────┐                 ┌──────────────┐
  │  frontend    │                 │   database   │
  │  (nginx)     │                 │   (mysql)    │
  └──────┬───────┘                 └───────┬──────┘
         │                                 │
         └────────┐             ┌──────────┘
                  │             │
              ┌───┴─────────────┴───┐
              │      backend        │   ← on BOTH networks
              │      (alpine)       │
              └─────────────────────┘

   isolated-net  ── created, deliberately unconnected
```

The backend is the only container on both networks, so it is the only path between frontend and database. The frontend **cannot** reach the database directly — that isolation is the point of the exercise.

### Step 1 — Create the three networks

```bash
docker network create frontend-net
docker network create backend-net
docker network create isolated-net

docker network ls
```

### Step 2 — Create the containers

```bash
# Frontend on frontend-net
docker run -d --name frontend --network frontend-net nginx:alpine

# Database on backend-net
docker run -d --name database --network backend-net \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=testdb \
  mysql:8.0

# Backend on frontend-net initially
docker run -d --name backend --network frontend-net alpine:latest sleep infinity
```

### Step 3 — Attach the backend to a second network

A container can only be given one network with `docker run`. Additional networks are attached afterwards:

```bash
docker network connect backend-net backend
```

Verify it is on two:

```bash
docker inspect backend -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'
# expected: backend-net frontend-net
```

### Step 4 — Check connectivity

Docker's **embedded DNS** resolves container names automatically on user-defined networks, so containers can be reached by name.

```bash
# Install ping inside the alpine backend
docker exec backend apk add --no-cache iputils bind-tools

# backend -> frontend  (both on frontend-net)  SHOULD WORK
docker exec backend ping -c 3 frontend

# backend -> database  (both on backend-net)   SHOULD WORK
docker exec backend ping -c 3 database

# frontend -> database (no shared network)     SHOULD FAIL
docker exec frontend ping -c 3 database
# expected: ping: bad address 'database'

# frontend -> backend  (both on frontend-net)  SHOULD WORK
docker exec frontend ping -c 3 backend
```

Testing the actual database port from the backend:

```bash
docker exec backend nc -zv database 3306
```

Inspecting which containers sit on each network:

```bash
docker network inspect frontend-net -f '{{range .Containers}}{{.Name}} {{end}}'
# expected: backend frontend

docker network inspect backend-net -f '{{range .Containers}}{{.Name}} {{end}}'
# expected: backend database
```

### Expected results

| From | To | Result | Why |
|---|---|---|---|
| backend | frontend | Success | Share `frontend-net` |
| backend | database | Success | Share `backend-net` |
| frontend | backend | Success | Share `frontend-net` |
| frontend | database | **Fails — bad address** | No shared network |

The failure is the important observation: name resolution does not even succeed, because Docker's embedded DNS only resolves names within networks the querying container belongs to.

### Compose equivalent

The same topology is expressed declaratively in [`docker-compose.yml`](docker-compose.yml):

```bash
docker compose up -d
docker compose ps
docker compose down
```

### Cleanup

```bash
docker rm -f frontend backend database
docker network rm frontend-net backend-net isolated-net
```

---

## Task 2 — Host Network

**Goal:** run Apache2 on the host network and reach it on port 80.

```bash
# Pull the Apache image
docker pull httpd:2.4

# Run with the host network - note there is NO -p flag
docker run -d --name apache-host --network host httpd:2.4

# Verify
docker ps
curl http://localhost:80
```

Then open **http://localhost** — the Apache default page ("It works!") should appear.

### What the host network does

With `--network host`, the container **shares the host's network namespace** instead of getting its own. There is no virtual interface, no NAT, no port mapping.

Consequences:

- `-p 80:80` is **not used and has no effect**. The container binds host port 80 directly.
- Because there is no NAT layer, throughput is slightly higher and latency slightly lower.
- **Port conflicts become real.** If the host already runs something on 80, the container fails.
- The container loses network isolation and can see all host interfaces.
- **Linux only.** On Docker Desktop for Windows and macOS the daemon runs inside a VM, so `--network host` binds to the VM's network, not the Windows host. It does not behave as documented there.

Confirming the shared namespace:

```bash
# Container sees exactly the host's interfaces
docker exec apache-host ip addr show

# Apache appears bound on the host itself
sudo ss -tulnp | grep :80
```

### Bridge vs host

| | Bridge (default) | Host |
|---|---|---|
| Network namespace | Own, isolated | **Shared with host** |
| IP address | Private (e.g. 172.17.0.2) | The host's IP |
| Port publishing | Needs `-p` | Not applicable |
| Performance | Slight NAT overhead | Native |
| Isolation | Good | **None** |
| Port conflicts | Avoidable via mapping | Possible |
| Platform | All | Linux only |

### Cleanup

```bash
docker rm -f apache-host
```

---

## Task 3 — Bind Mount

**Goal:** bind mount a local folder into Nginx and show that edits appear live.

The folder is [`bind-mount/`](bind-mount/), containing [`index.html`](bind-mount/index.html) with the content **Hello students**.

### Step 1 — The local file

```html
<h1>Hello students</h1>
```

### Step 2 — Mount it into Nginx

```bash
cd 07-docker-network-volume

docker run -d --name nginx-bind \
  -p 8090:80 \
  -v "$(pwd)/bind-mount":/usr/share/nginx/html \
  nginx:alpine
```

On Windows PowerShell:

```powershell
docker run -d --name nginx-bind -p 8090:80 -v "${PWD}\bind-mount:/usr/share/nginx/html" nginx:alpine
```

The `-v` syntax is `hostPath:containerPath`. The host path must be **absolute** — a relative path is interpreted as a named volume instead, which is a common mistake.

### Step 3 — Verify

```bash
curl http://localhost:8090
```

Expected: `<h1>Hello students</h1>` — open **http://localhost:8090** in a browser.

### Step 4 — Modify the file and confirm the change is live

```bash
# Edit the file on the HOST
echo '<h1>Hello students - UPDATED without restarting!</h1>' > bind-mount/index.html

# Re-request WITHOUT touching the container
curl http://localhost:8090
```

The new content appears immediately. Confirm the container was never restarted:

```bash
docker ps --filter name=nginx-bind --format "{{.Names}} {{.Status}}"
# Status still shows the original uptime - no restart
```

### What I understood

The bind mount maps a host directory **directly into the container's filesystem**. Nothing is copied — both sides read and write the same inodes on the host disk. That is why the edit is visible instantly: Nginx reads the file from disk on each request, and the file it reads *is* the host file.

This is the mechanism behind hot-reload in development: mount your source directory in, and edits on the host are seen by the process in the container.

### Bind mount vs named volume

| | Bind mount | Named volume |
|---|---|---|
| Syntax | `-v /host/path:/container/path` | `-v myvolume:/container/path` |
| Location | Any host path you choose | Managed by Docker (`/var/lib/docker/volumes`) |
| Created by | Must already exist | Docker creates it |
| Host access | Direct, ordinary file access | Through Docker |
| Portability | Tied to host layout | Portable |
| Best for | **Development**, config files, source | **Production data**, databases |
| Backup | Normal filesystem tools | `docker volume` commands |

```bash
# Named volume for comparison
docker volume create web-content
docker run -d --name nginx-vol -p 8091:80 -v web-content:/usr/share/nginx/html nginx:alpine
docker volume inspect web-content
```

### Cleanup

```bash
docker rm -f nginx-bind
git checkout bind-mount/index.html   # restore "Hello students"
```

---

## Task 4 — Overlay Networks (research)

### What an overlay network is

An overlay network spans **multiple Docker hosts**, letting containers on different physical machines communicate as though they were on the same LAN — even though the hosts may be in different racks or data centres.

Bridge networks are limited to a single host. Overlay networks are the answer when a cluster outgrows one machine.

### How it works

1. **VXLAN encapsulation.** Container traffic is wrapped inside UDP packets (default port **4789**) and sent across the physical network. The receiving host unwraps it and delivers it to the target container. The containers never see the encapsulation — from their view they are on one flat layer-2 segment.

2. **A distributed control plane.** Docker Swarm keeps a shared store (via the Raft consensus protocol) of which container lives on which host, with which IP and MAC. This is how a host knows where to send a packet destined for a container it does not own.

3. **Built-in service discovery.** Each overlay network has an embedded DNS server. Container and service names resolve cluster-wide, so an application connects to `database` without knowing which node it runs on.

4. **Load balancing via VIP.** A Swarm service gets a Virtual IP. Traffic to the VIP is distributed across all its replicas by IPVS in the kernel, wherever those replicas are.

### Ports required between hosts

| Port | Protocol | Purpose |
|---|---|---|
| 2377 | TCP | Cluster management (managers only) |
| 7946 | TCP + UDP | Node-to-node control plane gossip |
| 4789 | UDP | VXLAN data plane |

Blocked port 4789 is the classic cause of "the overlay network exists but containers cannot reach each other".

### Setting one up

```bash
# On the manager node
docker swarm init --advertise-addr <MANAGER-IP>

# On each worker
docker swarm join --token <TOKEN> <MANAGER-IP>:2377

# Create an attachable overlay network
docker network create -d overlay --attachable my-overlay

# Deploy a service across the cluster
docker service create --name web --network my-overlay --replicas 3 nginx:alpine

docker service ls
docker service ps web
docker network inspect my-overlay
```

`--attachable` matters: without it, only Swarm *services* can join the network, not standalone containers started with `docker run`.

### Use cases

- **Multi-host container clusters** — the core use case; a Swarm cluster requires it.
- **Microservices spread across nodes** — services address each other by name regardless of placement.
- **High availability** — replicas on different hosts stay on one logical network, so a node failure does not partition the application.
- **Encrypted traffic between hosts** — `docker network create -d overlay --opt encrypted` enables IPsec on the data plane, which matters when hosts communicate over an untrusted network.
- **Horizontal scaling** — add a node to the Swarm and it joins the existing overlay without reconfiguration.

### Driver comparison

| Driver | Scope | Use case |
|---|---|---|
| `bridge` | Single host | Default; containers on one machine |
| `host` | Single host | Remove network isolation for performance |
| `overlay` | **Multi-host** | Swarm clusters, distributed applications |
| `macvlan` | Single host | Give a container a real MAC on the physical LAN |
| `ipvlan` | Single host | Like macvlan, sharing the host MAC |
| `none` | Single host | Fully disable networking |

### Overlay vs Kubernetes

Overlay networking is not unique to Docker Swarm. Kubernetes CNI plugins — Flannel, Calico, Weave — solve the same multi-host problem with the same underlying idea, most of them also using VXLAN. Understanding Docker overlay transfers directly to understanding Kubernetes pod networking.

Reference: <https://docs.docker.com/engine/network/drivers/>

---

## Pending

Docker is not installed on the machine this repository was prepared on. Still to capture:

- [ ] Task 1 — `docker network ls`, `docker ps`, and the four ping results (including the expected frontend→database failure)
- [ ] Task 2 — `docker ps` for the host-network container and the Apache page on port 80
- [ ] Task 3 — browser before and after the edit, proving no restart occurred
- [ ] Save all images into `screenshots/` and embed them above

Task 4 is research-only and is complete.

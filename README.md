# DevOps Homework — Submission

**Name:** Ridaa Mirza
**Enrollment No:** 24BCS10394

Homework for the [devops-heros](https://github.com/Nency-Ravaliya/devops-heros) course, sessions 1–8.

---

## Contents

| # | Session | Folder | Status |
|---|---|---|---|
| 1 | Linux Fundamentals | [`01-linux/`](01-linux/) | Complete |
| 2 | Shell Scripting | [`02-shell-scripting/`](02-shell-scripting/) | Complete |
| 3 | Networking Fundamentals | [`03-networking/`](03-networking/) | Complete |
| 4 | Git / GitHub | [`04-git-github/`](04-git-github/) | Complete |
| 5 | Docker Fundamentals | [`05-docker-apps/`](05-docker-apps/) | Code complete, screenshots pending |
| 6 | Dockerfiles & Multi-Stage Builds | [`06-multi-stage/`](06-multi-stage/) | Code complete, screenshots pending |
| 7 | Docker Networking & Volumes | [`07-docker-network-volume/`](07-docker-network-volume/) | Commands documented, screenshots pending |

---

## Task coverage

### 1. Linux — [`01-linux/`](01-linux/)
- Soft vs hard links: difference, commands, and a live demonstration proving the hard link survives deletion of the original while the soft link breaks
- `adduser` vs `useradd`: comparison table and why `adduser` is preferred on Ubuntu
- `journalctl`: what it is, the useful flags, and real service and error log output
- Linux command cheat sheet, grouped by purpose

Raw output: [`links-output.txt`](01-linux/links-output.txt), [`journalctl-output.txt`](01-linux/journalctl-output.txt)

### 2. Shell Scripting — [`02-shell-scripting/`](02-shell-scripting/)
- [`sysinfo.sh`](02-shell-scripting/sysinfo.sh) — prints date, hostname, username, disk usage and processes; uses variables; takes input via `read -p`; creates a directory with `mkdir` and a file with `touch`; writes the process list using `>` redirection
- README with the full run transcript and verification that the directory, file, and redirected content were all created

Raw output: [`run-output.txt`](02-shell-scripting/run-output.txt)

### 3. Networking — [`03-networking/`](03-networking/)
- Real output and a written explanation for each of `ip addr`, `ip route`, `ping`, `ss`, `netstat`, `arp`, `route`, `curl`, `nc`, `ifconfig`, `/etc/resolv.conf`, `/etc/hosts`
- [`subnetting-notes.md`](03-networking/subnetting-notes.md) — IP classes, subnet masks, host counting, three worked examples including this machine's own `/20` interface, private ranges, special addresses
- A layer-by-layer troubleshooting order

Raw output: [`commands-output.txt`](03-networking/commands-output.txt)

### 4. Git / GitHub — [`04-git-github/`](04-git-github/)
- `git commit -m` vs `git commit -a -m`, demonstrated with a case that shows `-a` silently skipping a new untracked file
- Full cherry-pick exercise: 5 commits on `main`, 3 on a feature branch, one commit identified and cherry-picked across, verified — including the branch graph showing the copy carries a **new hash**

Raw output: [`commands-output.txt`](04-git-github/commands-output.txt)

### 5. Docker Fundamentals — [`05-docker-apps/`](05-docker-apps/)
Six Hello World web applications, each with its own Dockerfile:

| Folder | Stack | Container port |
|---|---|---|
| [`nodejs-app/`](05-docker-apps/nodejs-app/) | Node.js + Express | 3000 |
| [`python-app/`](05-docker-apps/python-app/) | Python + Flask | 5000 |
| [`java-app/`](05-docker-apps/java-app/) | Java + JDK HttpServer (multi-stage) | 8000 |
| [`Apache-app/`](05-docker-apps/Apache-app/) | Apache httpd | 80 |
| [`React-app/`](05-docker-apps/React-app/) | React + Vite → Nginx (multi-stage) | 80 |
| [`nginx-app/`](05-docker-apps/nginx-app/) | Nginx | 80 |

### 6. Multi-Stage Builds — [`06-multi-stage/`](06-multi-stage/)
- The course multi-stage application vendored under [`app/`](06-multi-stage/app/), with build and run instructions
- Note on the port: the app listens on **3000** internally, so reaching it on the required port 8080 means running `-p 8080:3000`
- Explanation of what multi-stage builds are, the size and security gains, and the techniques involved

### 7. Docker Networking & Volumes — [`07-docker-network-volume/`](07-docker-network-volume/)
- Three containers across three networks with the backend on two of them, plus the connectivity matrix (including the frontend→database failure that proves the isolation)
- Apache on the host network, with an explanation of what sharing the host namespace means
- Bind mount into Nginx showing live edits without a restart
- Overlay network research: VXLAN, the control plane, required ports, setup, and use cases
- [`docker-compose.yml`](07-docker-network-volume/docker-compose.yml) expressing the Task 1 topology declaratively

---

## Environment

Everything that could be executed was executed and captured verbatim:

- **OS:** Ubuntu 24.04.1 LTS (WSL2), kernel `6.18.33.2-microsoft-standard-WSL2`
- **Git:** 2.49.0
- **systemd:** 255

## Outstanding work

Docker is **not installed** on the machine this repository was prepared on, so sections 5–7 contain complete, reviewed code and commands but no captured build output or screenshots yet. Each of those three READMEs ends with a `Pending` checklist of exactly what remains to be captured.

To complete them:

```bash
# Install Docker Engine on Ubuntu / WSL2
sudo apt update
sudo apt install -y docker.io
sudo service docker start
sudo usermod -aG docker $USER   # then restart the shell

docker run hello-world          # verify
```

Then work through the `Pending` checklist in each section.

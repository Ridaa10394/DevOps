# Session 21 - Final DevOps Capstone: TaskBoard

Name: Ridaa Mirza
Enrollment No: 24BCS10394

## Overview

This is the final capstone. The instructor gave us a complete project called **TaskBoard**: a React + Vite frontend, a FastAPI backend, PostgreSQL with Alembic migrations, pytest tests, Dockerfiles, a GitHub Actions pipeline with Trivy, Terraform for AWS VPC + EKS, a Helm chart (with Ingress, HPA and a ServiceMonitor), a load-test script and two deliberately broken manifests for troubleshooting. Their [README](INSTRUCTOR-README.md) walks through it as Parts A to O plus a FINAL DEMO, and [GRADING.md](GRADING.md) is the rubric.

My job was to take that project as it is, **run everything it describes**, screenshot the real terminal output, and write it up. So I copied the instructor's project into this folder unchanged and then followed their README part by part. Some things did not work out of the box. When that happened I made the smallest fix I could and wrote down what broke, why, and what I changed (see [Fixes I made](#fixes-i-made-to-the-instructors-code)).

Where things ran:

- Docker Desktop on my Mac (arm64) for the Docker Compose stack, the images and the scans.
- My local **minikube** (docker driver), which other homework namespaces (`s09`, `s17`) were sharing at the same time. I only used the chart's own namespace, `taskboard`, and deleted it at the end.
- GitHub Actions, the GHCR push and the real AWS `terraform apply` can't run from my laptop without pushing or AWS credentials. Those steps are marked **TODO** with the exact commands to run.
- **Part M (Prometheus + Grafana) is skipped for this submission** (see [Part M](#part-m---monitoring-skipped)).

Every screenshot below is a render of a raw output file in [`outputs/`](outputs/). Each file starts with the `$ command` that produced it. When a file was too long for one image I split it (`-a`, `-b`, ...) or cut the middle with a `...` line. I never edited the text itself. Screenshots `10a`, `10b`, `10d`, `11` and `51` are real browser captures (Playwright/Chromium). The numbering has gaps (57-58, 61-68) because I removed the monitoring outputs when Part M was dropped.

### Files

```
20-final-capstone/
|-- README.md                      # this file (my write-up)
|-- INSTRUCTOR-README.md           # the instructor's original README (Parts A-O)
|-- GRADING.md                     # the rubric (unchanged)
|-- docker-compose.yml             # unchanged
|-- docker-compose.alt-ports.yml   # MY override - only remaps host ports 3000/8000 (busy on my laptop)
|-- .gitignore                     # extended (.env, .venv, __pycache__, .pytest_cache, coverage, tfstate ...)
|-- backend/                       # FastAPI + SQLAlchemy + Alembic + pytest   (2 small fixes)
|-- frontend/                      # React + Vite, nginx runtime                (2 small fixes)
|-- helm/taskboard/                # Helm chart                                 (3 small fixes)
|-- terraform/                     # AWS VPC + EKS                              (syntax fix only)
|-- k8s/namespace.yaml             # unchanged
|-- monitoring/prometheus-values.yaml   # unchanged (not used - Part M skipped)
|-- scripts/load-test.sh           # unchanged
|-- troubleshooting/               # broken-image.yaml, broken-service.yaml - unchanged
|-- .github/workflows/ci-cd.yml    # instructor's workflow, kept for reference (note added at the top)
|-- outputs/                       # raw command outputs (NN-name.txt)
`-- screenshots/                   # terminal + browser screenshots (NN-name.png)

../.github/workflows/s21-capstone.yml   # the copy of the workflow that GitHub actually runs
```

### Architecture

```
                       Developer (me) --- git push ---> GitHub (Ridaa10394/DevOps)
                                                               |
                                            .github/workflows/s21-capstone.yml
                                                               |
     +----------------------------+----------------------------+-----------------------------+
     | test                       | build-scan-push            | deploy / deploy-kind        |
     |  pytest -v                 |  docker build x2 (SHA tag) |  helm upgrade --install     |
     |  npm install + vite build  |  trivy image HIGH,CRIT gate|  (real cluster if secret,   |
     |                            |  docker push -> GHCR       |   else throwaway kind)      |
     +----------------------------+----------------------------+-----------------------------+
                                                               |
              terraform/ (AWS ap-south-1: VPC, 2 public + 2 private subnets, NAT, EKS 1.31, 2x t3.medium)
                                                               |
                                                    Kubernetes (minikube here)
                                                    namespace: taskboard
                                                               |
     ingress-nginx  --- Host: taskboard.local ---+-------------+----------------+
                                                 | /                            | /api
                                                 v                              v
                                     Service taskboard-frontend:80      Service backend:8000
                                                 |                              |
                                   Deployment taskboard-frontend   Deployment taskboard-taskboard-backend
                                     (nginx, React build;             (FastAPI, /health /ready /metrics,
                                      also proxies /api ->             alembic upgrade on start)
                                      backend:8000)                     ^ HPA taskboard-backend 2..6 @60% CPU
                                                                        |
                                                             Service taskboard-postgres:5432
                                                                        |
                                                  Deployment taskboard-postgres + PVC 5Gi + Secret
```

---

## Part A - Understand the application

The repo layout as I copied it, plus the tool versions on my machine. Note helm is **v4**, which matters later in Part L.

```bash
find . -type f | sort
docker --version; docker compose version; python3 --version; node --version; ...
```

![project tree](screenshots/01-project-tree.png)
![tool versions](screenshots/02-versions.png)

The backend exposes `/`, `/health`, `/ready` (it actually runs a DB query), `/metrics` and the `/api/tasks` CRUD + `/api/tasks/stats`. The full list is in the route printout in step B.3 below.

---

## Part B - Run it locally

### B.1 Docker Compose

The instructor's command is `docker compose up --build` (I used `-d` so it runs in the background). On my laptop the first try failed: another project's container already had port 8000.

```bash
docker compose up -d --build
```

![compose up - port 8000 already allocated](screenshots/03-compose-up-first-try.png)

**What I saw:** both images built fine, postgres started, then `Bind for 0.0.0.0:8000 failed: port is already allocated`. 3000 was also taken. That's my machine, not the project, so I left `docker-compose.yml` alone. Instead I added a tiny override file, [`docker-compose.alt-ports.yml`](docker-compose.alt-ports.yml), that uses `ports: !override` to remap only the **host** side: frontend `13000:80`, backend `18000:8000`.

```bash
docker compose -f docker-compose.yml -f docker-compose.alt-ports.yml up -d --build
docker compose -f docker-compose.yml -f docker-compose.alt-ports.yml ps
docker compose logs backend
```

![compose up](screenshots/04-compose-up.png)
![compose ps + backend logs](screenshots/05-compose-ps.png)

**What I saw:** all three services up. The backend log shows Alembic running `0001_create_tasks` before Uvicorn starts, which is exactly what the Dockerfile `CMD` does. One thing to note: compose has `depends_on: postgres` without a healthcheck. Here postgres happened to be ready in time, but in Kubernetes the same race made the backend restart a few times (Part I).

### B.2 Health, readiness, Swagger

```bash
curl -s http://localhost:18000/
curl -s http://localhost:18000/health
curl -s http://localhost:18000/ready
curl -s -o /dev/null -w "GET /docs -> HTTP %{http_code}\n" http://localhost:18000/docs
curl -s http://localhost:18000/openapi.json | python3 -c '...print every METHOD path...'
```

![health ready root routes](screenshots/06-health-ready-root.png)

![Swagger UI at /docs](screenshots/11-swagger-docs.png)

**What I saw:** `{"status":"UP"}`, `{"status":"READY"}`, Swagger at `/docs` returns 200, and the route list matches the instructor's README (10 routes).

### B.3 /metrics

```bash
curl -s http://localhost:18000/metrics | head -12
curl -s http://localhost:18000/metrics | grep -E "^http_requests_total"
curl -s http://localhost:18000/metrics | grep -E "^http_request_duration_seconds_(count|sum)"
```

![metrics a](screenshots/07-metrics-a.png)
![metrics b](screenshots/07-metrics-b.png)

**What I saw:** Prometheus text format from `prometheus-fastapi-instrumentator`, with `http_requests_total` by handler, method and status class. The counters match the CRUD calls I made in the next step, including the `4xx` ones.

### B.4 CRUD

```bash
curl -s http://localhost:18000/api/tasks
curl -s -X POST http://localhost:18000/api/tasks -H "Content-Type: application/json" -d '{"title":"Set up CI pipeline",...}'
curl -s http://localhost:18000/api/tasks/1
curl -s -X PUT http://localhost:18000/api/tasks/1 -H "Content-Type: application/json" -d '{"status":"IN_PROGRESS"}'
curl -s -X DELETE http://localhost:18000/api/tasks/3        # 204
curl -s http://localhost:18000/api/tasks/3                  # 404
curl -s http://localhost:18000/api/tasks/stats
curl -s -X POST ... -d '{"title":"bad","priority":"URGENT"}' # 422
```

![crud a](screenshots/08-crud-a.png)
![crud b](screenshots/08-crud-b.png)

**What I saw:** create returns 201 with `id` and `created_at`. PUT is a partial update (only `status` changed). DELETE gives 204 and then GET gives 404 `Task not found`. Stats count by status. An invalid priority gets a 422 from Pydantic (`Input should be 'LOW', 'MEDIUM' or 'HIGH'`).

### B.5 Frontend (and a bug)

```bash
curl -s -i http://localhost:13000/ | head -20
curl -s http://localhost:13000/api/tasks/stats      # nginx proxies /api -> backend:8000
curl -s http://localhost:13000/health
```

![frontend via nginx](screenshots/09-frontend.png)

Then I opened `http://localhost:13000` in a real browser (Playwright) and created a task through the "New task" modal:

![create task modal](screenshots/10a-ui-create-task-modal.png)

**Bug:** the first time I clicked "Create task", the task *was* saved (backend log: `POST /api/tasks 201`, stats went from 2 to 3), but the modal stayed open and the table never refreshed:

![modal stuck after create](screenshots/10b-ui-bug-modal-stuck.png)
![console error + evidence](screenshots/10-ui-create-bug.png)

The browser console said `TypeError: Cannot read properties of null (reading 'reset') at onSubmit`. In React, `e.currentTarget` on the synthetic event is only valid while the handler is running synchronously. After the `await fetch(...)` it's `null`, so `e.currentTarget.reset()` throws, and `setShowForm(false)` and `load()` never run. The fix is one line: grab the form before the `await` (`const form=e.currentTarget; ... form.reset()`). Then I rebuilt just the frontend:

![fix + rebuild](screenshots/10c-ui-fix.png)
![dashboard after fix](screenshots/10d-ui-dashboard-compose.png)

**What I saw after the fix:** the modal closes, the new task "Run Trivy on both images" appears straight away and the KPI cards update (4 total, 2 to do, 1 in progress, 1 completed).

### B.6 Database check

```bash
docker compose exec -T postgres psql -U taskboard -d taskboard -c "\dt"
docker compose exec -T postgres psql -U taskboard -d taskboard -c "\d tasks"
docker compose exec -T postgres psql -U taskboard -d taskboard -c "SELECT version_num FROM alembic_version;"
docker compose exec -T postgres psql -U taskboard -d taskboard -c "SELECT id, title, priority, status, assignee FROM tasks ORDER BY id;"
docker compose exec -T backend alembic current
```

![database](screenshots/12-database.png)

**What I saw:** two tables, `tasks` and `alembic_version` (= `0001_create_tasks (head)`). The column defaults match the migration file. The rows are the tasks I made by curl and through the UI, and id 3 is missing because I deleted it.

### B.7 Run the backend directly (section 6)

The README says Python 3.12+. My system Python is 3.14, which is too new for some of these pinned wheels, so I used a 3.12 interpreter for the venv. Port 8000 was taken, so I ran Uvicorn on 18010 against the compose Postgres (`localhost:5432`).

```bash
cd backend
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export DATABASE_URL='postgresql+psycopg://taskboard:taskboard@localhost:5432/taskboard'
alembic upgrade head
uvicorn app.main:app --reload --port 18010
curl http://localhost:18010/health
curl http://localhost:18010/api/tasks
```

![venv + alembic](screenshots/13-backend-venv.png)
![uvicorn directly](screenshots/14-backend-direct.png)

**What I saw:** `alembic upgrade head` was a no-op (already at head, since the container ran it). `--reload` started the WatchFiles reloader, and the API returned the same 4 tasks as the container, because it's the same database.

---

## Part C - Testing

### C.1 pytest, as written

```bash
cd backend
pytest -q
```

![pytest first run - 1 failed](screenshots/15-pytest-first-run.png)

**What I saw:** `1 failed, 2 passed`. `test_create_task_validation` died with `sqlite3.OperationalError: no such table: tasks`. The tests point `DATABASE_URL` at SQLite (`test.db`, a separate test DB, which is good) and rely on FastAPI's startup event (`Base.metadata.create_all`) to create the table. But `TestClient(app)` only runs startup/shutdown events when it's used as a context manager (`with TestClient(app) as client:`). The instructor's test just does `client = TestClient(app)`, so the table never gets created. `/health` and `/` passed only because they don't touch the DB.

**Fix:** I added a module-scoped autouse fixture to `tests/test_api.py` that does `with client: yield`, which runs startup once for the module. No other test or app code changed.

```bash
pytest -q
pytest -v
pytest --cov=app --cov-report=term-missing     # pytest-cov installed into the venv only
```

![pytest -q pass](screenshots/16-pytest-pass-a.png)
![pytest -v pass](screenshots/16-pytest-pass-b.png)
![coverage](screenshots/17-pytest-coverage.png)

**What I saw:** 3 passed. Coverage is 81% overall, but `app/main.py` is only 63% because GET-by-id, PUT, DELETE, stats and `/ready` have no tests. The `on_event is deprecated` warning is harmless for now (lifespan handlers are the new way).

After the dependency bump in Part G (FastAPI 0.142.2 / Starlette 1.7.0) I ran the tests again:

![pytest after bump](screenshots/29-pytest-after-dep-bump.png)

Why tests come before the image push: in the pipeline `build-scan-push` has `needs: test`, so a failing test stops the job chain and no broken image ever reaches GHCR. That's exactly what would have happened with the original test file.

---

## Part D - Git and GitHub

This homework lives in my existing repo, so I didn't `git init` again. Here's the current state (read-only, nothing committed by me yet):

```bash
git remote -v
git branch --show-current
git log --oneline -15
git rev-list --count HEAD
git status --short -- 20-final-capstone .github/workflows/s21-capstone.yml
git check-ignore -v 20-final-capstone/backend/.venv 20-final-capstone/backend/.pytest_cache 20-final-capstone/.env
```

![git](screenshots/18-git.png)

**What I saw:** `origin` is `git@github.com:Ridaa10394/DevOps.git` on `main` with 15 commits (the rubric wants at least 10). `20-final-capstone/` is untracked. The new `.gitignore` really ignores `.venv`, `.pytest_cache` and `.env`.

> TODO (after you push / run on your machine):
> ```bash
> cd ~/Desktop/AI-Labs/DevOps
> git add 20-final-capstone .github/workflows/s21-capstone.yml
> git commit -m "Session 21 - Final DevOps capstone (TaskBoard): run-through, fixes, screenshots"
> git push origin main
> git log --oneline -5      # screenshot this for the FINAL DEMO "Git" item
> ```
> For FINAL DEMO item 4 ("make a small application change and commit it"), change something visible (for example the greeting in `frontend/src/main.jsx`), commit it with a meaningful message, push it, and screenshot `git log --oneline -3` and the pipeline it triggers.

---

## Part E - Docker

### E.1 Backend image

`python:3.12-slim`, installs requirements, copies Alembic + app, creates `appuser` (uid 10001), runs as that user, and the `CMD` runs migrations and then Uvicorn.

```bash
docker build -t taskboard-backend:local ./backend
```

![backend build](screenshots/19-docker-build-backend.png)

### E.2 Frontend image (multi-stage)

Stage 1 `node:22-alpine` runs `npm install` + `vite build`. Stage 2 `nginx:1.27-alpine` only gets `dist/` + `nginx.conf`, so Node and `node_modules` never reach the runtime image.

```bash
docker build -t taskboard-frontend:local ./frontend
```

![frontend build](screenshots/20-docker-build-frontend.png)

### E.3 Images, sizes, users

```bash
docker images taskboard-backend; docker images taskboard-frontend
docker image inspect taskboard-backend:local --format "...size, user, cmd..."
docker image inspect taskboard-frontend:local --format "...size, user, expose..."
docker history taskboard-frontend:local
docker run --rm --entrypoint id taskboard-backend:local; docker run --rm --entrypoint id taskboard-frontend:local
```

![images](screenshots/21-docker-images.png)

**What I saw:** backend is 70.5 MB content (325 MB on disk unpacked) and frontend is only 21.9 MB (76.3 MB on disk), because the multi-stage build leaves Node behind. The backend runs as `uid=10001(appuser)`. **The frontend runs as root** (`uid=0`, no `USER` in the Dockerfile). The nginx workers drop privileges, but the rubric (M4) asks for non-root images, so that's a gap in the reference project. I didn't change it, since it isn't broken. The fix would be `nginxinc/nginx-unprivileged` on port 8080.

### E.4 Running the backend image on its own (README section 9)

```bash
docker run -d --name s21-backend-standalone -p 18001:8000 \
  -e DATABASE_URL='postgresql+psycopg://taskboard:taskboard@host.docker.internal:5432/taskboard' taskboard-backend:local
docker logs s21-backend-standalone
curl -s http://localhost:18001/ready; curl -s http://localhost:18001/api/tasks/stats
docker rm -f s21-backend-standalone
```

![docker run backend](screenshots/22-docker-run-backend.png)

**What I saw:** it reached the compose Postgres through `host.docker.internal` and returned READY plus the same stats.

---

## Part F - CI/CD

### F.1 The workflow

GitHub only reads workflows from the **repo root** `.github/workflows/`, so the instructor's `20-final-capstone/.github/workflows/ci-cd.yml` would never run where it sits. I kept it as-is (with a note at the top) and made the runnable copy [`../.github/workflows/s21-capstone.yml`](../.github/workflows/s21-capstone.yml). It's the same three stages (`test` -> `build-scan-push` -> `deploy`, image tag = `${{ github.sha }}`), with only these changes:

| Change | Why |
|---|---|
| `paths:` filter `20-final-capstone/**` + the workflow file, `working-directory: 20-final-capstone/...` | The repo holds 20 sessions, so only this folder should trigger it, and the paths are one level deeper |
| GHCR owner lowercased: `${GITHUB_REPOSITORY_OWNER,,}` | My owner is `Ridaa10394` and GHCR image names must be lowercase, so `docker build -t ghcr.io/Ridaa10394/...` would fail |
| Trivy from a pinned, sha256-verified binary (v0.75.0) instead of `aquasecurity/trivy-action@0.30.0` | Same flags (`HIGH,CRITICAL`, `--ignore-unfixed`, exit code 1). A version tag on a third-party action can be moved, and this is the security tool itself, so I reused the pinned-binary approach from my S17 pipeline |
| `pytest -v` instead of `-q` | The rubric asks for `pytest -v` output |
| Push only when `github.event_name != 'pull_request'` | PRs should test + scan, not publish images |
| `deploy` (the instructor's real-cluster job) guarded by `env.HAS_KUBECONFIG` (= `secrets.KUBE_CONFIG_DATA != ''`) | I don't have that secret (no EKS running). Without the guard, `base64 -d` of an empty secret writes an empty kubeconfig and `helm` fails, turning the pipeline red. Now it prints a notice and stays green; add the secret and it deploys for real |
| New `deploy-kind` job (main only) | Creates a throwaway kind cluster on the runner, pulls the exact SHA images from GHCR, loads them into kind, runs `helm upgrade --install` with the chart, waits for rollout and smoke-tests `/`, `/health`, `POST /api/tasks`, `/api/tasks/stats` through the frontend Service. The ServiceMonitor is disabled there (no Prometheus CRDs in kind) |

Both workflows pass actionlint:

```bash
actionlint -no-color .github/workflows/s21-capstone.yml
actionlint -no-color 20-final-capstone/.github/workflows/ci-cd.yml
```

![actionlint instructor original](screenshots/34-actionlint-original.png)
![actionlint s21-capstone](screenshots/76-actionlint.png)

**What I saw:** exit code 0 for both. (My first version of the new file had two shellcheck SC2086 infos for unquoted `${owner}` in the `--set` lines; I quoted them.)

Before this pipeline could go green, two more things had to be fixed in the project itself: the test bug (Part C) and the Trivy gate (Part G). With the original code, `test` fails, and even with tests fixed, both image scans exit 1.

> TODO (after you push / run on your machine):
> 1. Push (Part D TODO). The workflow is `S21 Capstone - TaskBoard CI/CD` in the Actions tab.
> 2. Screenshot the run summary showing `test`, `build-scan-push`, `deploy` (with the "KUBE_CONFIG_DATA secret not set" notice) and `deploy-kind` all green, plus the `Run backend tests` step (pytest -v output), the `Scan backend` / `Scan frontend` steps (Trivy output) and the `Smoke test` step of `deploy-kind`.
> 3. Paste the run URL here.
>
> If Trivy fails in CI on a day when a new CVE is published for these base images, that's the gate doing its job: re-run the rebuild + re-scan from Part G locally and bump/patch whatever it reports.

---

## Part G - Security scanning (Trivy)

### G.1 Filesystem scan (code, deps, IaC, Dockerfiles, secrets)

```bash
trivy fs --scanners vuln,secret,misconfig --severity HIGH,CRITICAL --skip-dirs backend/.venv --no-progress .
```

![trivy fs a](screenshots/23-trivy-fs-a.png)
![trivy fs b](screenshots/23-trivy-fs-b.png)

**What I saw:** `requirements.txt` had 0 known vulnerable packages and there were no secrets. Trivy's Terraform parser threw `Invalid single-argument block definition` for `main.tf` and `versions.tf`. That was the first hint that the Terraform files don't even parse (Part H confirmed it). The misconfig findings are the usual hardening ones: `DS-0002` (frontend Dockerfile has no `USER`), and for every Deployment `KSV-0014` (no `readOnlyRootFilesystem`) and `KSV-0118` (default security context). Those are findings, not breakages, so I left them, but they'd be the next thing to harden.

### G.2 Image scans, as the instructor built them

```bash
trivy image --severity HIGH,CRITICAL --no-progress taskboard-backend:local
trivy image --severity HIGH,CRITICAL --no-progress taskboard-frontend:local
```

![trivy backend a](screenshots/24-trivy-image-backend-a.png)
![trivy backend b](screenshots/24-trivy-image-backend-b.png)
![trivy frontend](screenshots/25-trivy-image-frontend.png)

Then the exact gate the pipeline uses (`--ignore-unfixed --exit-code 1`):

```bash
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --no-progress --quiet taskboard-backend:local; echo $?
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --no-progress --quiet taskboard-frontend:local; echo $?
```

![trivy gate fails](screenshots/26-trivy-ci-gate.png)

**What I saw:** **both gates exit 1**, so the instructor's pipeline would stop at "Scan backend" and nothing would ever be pushed.

- **Backend:** 44 HIGH in Debian 13.7 packages, but all `affected` with no fix yet, so `--ignore-unfixed` skips them. What actually fails the gate is 3 HIGH CVEs in **Starlette 0.41.3**, pulled in by `fastapi==0.115.6`: CVE-2025-62727 (DoS via Range header merging, fixed 0.49.1), CVE-2026-48818 (SSRF / NTLM credential theft via UNC paths in StaticFiles, fixed 1.1.0) and CVE-2026-54283 (`request.form()` limits ignored for urlencoded bodies, a DoS, fixed 1.3.1). Just bumping FastAPI wasn't enough: `prometheus-fastapi-instrumentator==7.0.2` pins `starlette<1.0.0`, so pip resolved Starlette 0.52.1, which was still vulnerable. Version 8.1.0 of the instrumentator allows Starlette 1.x.
- **Frontend:** 44 findings (42 HIGH, 2 CRITICAL), all in Alpine 3.21.3 OS packages of the old `nginx:1.27-alpine` base (OpenSSL `libcrypto3`/`libssl3`, `libexpat`, `libxml2`, `musl`, `zlib`, `c-ares`, ...), and all fixable. For example, CVE-2026-31789 (CRITICAL) is an OpenSSL heap buffer overflow on 32-bit systems from a large X.509 certificate, fixed in `3.3.7-r0`.

### G.3 Fixes + rescan

- `backend/requirements.txt`: `fastapi==0.142.2`, `prometheus-fastapi-instrumentator==8.1.0` (everything else unchanged). Before changing anything I tested it in a scratch venv: tests pass, and CRUD, `/ready` and `/metrics` all work on Starlette 1.7.0.
- `frontend/Dockerfile`: `RUN apk upgrade --no-cache` right after `FROM nginx:1.27-alpine`, which patches the base in place. Bumping to a newer nginx image would also work, but this was the smallest change.

```bash
docker build -q -t taskboard-backend:local ./backend
docker build -q -t taskboard-frontend:local ./frontend
docker run --rm --entrypoint pip taskboard-backend:local show fastapi starlette prometheus-fastapi-instrumentator
docker images taskboard-backend; docker images taskboard-frontend
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 ... taskboard-backend:local; echo $?
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 ... taskboard-frontend:local; echo $?
docker compose -f docker-compose.yml -f docker-compose.alt-ports.yml up -d --build   # still works
```

![rebuild after fixes](screenshots/27-rebuild-after-fixes.png)
![trivy gate passes](screenshots/28-trivy-gate-after-fixes.png)
![compose after fixes](screenshots/30-compose-after-fixes.png)

**What I saw:** both gates exit **0**. The frontend grew from 21.9 MB to 27.7 MB of content because of the upgraded packages, which is a fair price. The compose stack came back up on the new images and still served the same data.

What this means: Trivy checked the OS packages and the Python packages inside each image against its vulnerability DB. A clean `--ignore-unfixed` result does **not** mean "secure". The backend still has 44 known HIGH Debian CVEs that nobody has shipped a fix for yet. It only means there is nothing we *could* fix today that we didn't. Container scanning is also just one layer: SAST, dependency scanning, secret scanning and runtime security are separate controls (my S17 pipeline does several of those).

---

## Part H - Terraform

### H.1 init, as written

```bash
cd terraform
terraform init -input=false -no-color
terraform validate -no-color
```

![terraform init original a](screenshots/31-terraform-init-original-a.png)
![terraform init original b](screenshots/31-terraform-init-original-b.png)

**What I saw:** `Error: Invalid single-argument block definition` in `main.tf` line 1 and `versions.tf` line 1. The instructor wrote each module / `terraform {}` block on a single line, like `module "vpc" { source = "..." version = "5.8.1" name = ... }`. HCL only allows a one-line block if it has **exactly one** argument. With more than one, it can't tell where one argument ends. There's also a sneaky side effect: because the `version = "5.8.1"` / `"20.37.1"` pins couldn't be read, init downloaded the **latest** modules (vpc 6.7.3, eks 21.26.0). EKS v21 renamed inputs like `cluster_name`, so even after fixing the syntax this would have broken later.

**Fix:** I reformatted `main.tf` and `versions.tf` to one argument per line, with the same modules, versions, CIDRs, AZs, node group sizes, provider and region. It's purely layout, and it now passes `terraform fmt -check`. `variables.tf` and `outputs.tf` were already valid (single-argument one-liners are allowed).

### H.2 init / fmt / validate after the fix

```bash
terraform init -input=false -no-color
terraform fmt -check -recursive -diff; echo "fmt -check exit code: $?"
terraform validate -no-color
terraform providers
```

![terraform init ok](screenshots/32-terraform-init-validate-a.png)
![fmt validate providers](screenshots/32-terraform-init-validate-b.png)

**What I saw:** this time it downloaded the pinned vpc **5.8.1** and eks **20.37.1**, plus hashicorp/aws **v5.100.0** (satisfies `~> 5.0` and EKS's `>= 5.95, < 6.0`). `fmt -check` exit 0, `Success! The configuration is valid.`

### H.3 plan (no AWS credentials here)

```bash
aws sts get-caller-identity
terraform plan -input=false -no-color
```

![terraform plan no creds](screenshots/33-terraform-plan.png)

**What I saw:** `No valid credential sources found`. There are no AWS env vars or `~/.aws` on this laptop, so the provider ended up trying the EC2 instance metadata endpoint (169.254.169.254), which obviously isn't there (`host is down`). That's expected without an AWS account configured, and it's why plan/apply are TODOs.

What this creates: VPC `10.20.0.0/16` in `ap-south-1a/1b`, 2 private + 2 public subnets, **one** NAT gateway (`single_nat_gateway = true`, to save cost), and EKS 1.31 (`taskboard-eks`) with a managed node group of 2x `t3.medium` (min 2 / max 4), public API endpoint, and cluster creator as admin.

> TODO (after you push / run on your machine, needs an AWS account; EKS + NAT cost money while they run):
> ```bash
> aws configure            # or aws sso login
> cd 20-final-capstone/terraform
> terraform init && terraform plan -out tfplan        # screenshot: "Plan: N to add, 0 to change, 0 to destroy"
> terraform apply tfplan                              # ~15 min; screenshot the Outputs
> aws eks update-kubeconfig --region ap-south-1 --name taskboard-eks
> kubectl get nodes                                   # screenshot: 2 Ready t3.medium nodes
> # AWS Console screenshots: VPC "taskboard-vpc" + EKS "taskboard-eks" in ap-south-1
> terraform destroy                                   # screenshot: "Destroy complete! Resources: N destroyed."
> ```
> The rubric also wants a `terraform.tfvars.example`; the reference project doesn't have one. If you add it, put only `aws_region`, `cluster_name` and `environment` in it, never keys.

---

## Part I - Kubernetes + Helm

### I.1 Namespace + images

```bash
kubectl config current-context
kubectl apply -f k8s/namespace.yaml
minikube image load taskboard-backend:local && minikube image load taskboard-frontend:local
minikube image ls | grep taskboard
```

![namespace](screenshots/35-k8s-namespace.png)
![image load](screenshots/36-minikube-image-load.png)

The chart defaults to `ghcr.io/YOUR_ORG/...:latest`. Locally I override `backend.image/tag` and `frontend.image/tag` to the images I loaded (tag `local`, so the default pull policy is `IfNotPresent` and minikube never tries a registry).

### I.2 helm install, first try

```bash
helm lint ./helm/taskboard
helm upgrade --install taskboard ./helm/taskboard --namespace taskboard --create-namespace \
  --set backend.image=taskboard-backend --set backend.tag=local \
  --set frontend.image=taskboard-frontend --set frontend.tag=local
```

![helm install first try](screenshots/37-helm-install-first-try.png)

**What I saw:** `no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1" ... ensure CRDs are installed first`. The chart enables a ServiceMonitor by default, which only exists once the Prometheus Operator (Part M) is installed. That's not a code bug, just an ordering thing, so I installed with `--set monitoring.serviceMonitor.enabled=false`. With Part M skipped it stayed off for the rest of the run.

```bash
helm upgrade --install taskboard ./helm/taskboard --namespace taskboard --create-namespace \
  --set backend.image=taskboard-backend --set backend.tag=local \
  --set frontend.image=taskboard-frontend --set frontend.tag=local \
  --set monitoring.serviceMonitor.enabled=false
kubectl get all -n taskboard
```

![helm install](screenshots/38-helm-install.png)
![get all - frontend crashing](screenshots/39-kubectl-get-all-first-try.png)

### I.3 Frontend CrashLoopBackOff

```bash
kubectl -n taskboard logs <frontend-pod> --previous
kubectl -n taskboard describe <frontend-pod>
kubectl -n taskboard get svc
grep -n proxy_pass frontend/nginx.conf
grep -n 'backend: {service' helm/taskboard/templates/ingress.yaml
```

![frontend crash debug](screenshots/40-frontend-crash-debug.png)

**What I saw:** `nginx: [emerg] host not found in upstream "backend" in /etc/nginx/conf.d/default.conf:13`, exit code 1. `nginx.conf` proxies `/api/` to `http://backend:8000`. In compose that works because the service is literally called `backend`. But the chart names the Service `{{ .Release.Name }}-taskboard-backend` = `taskboard-taskboard-backend`, so in the cluster there is no `backend` DNS name, and nginx refuses to start if it can't resolve an upstream at startup. While I was there I also noticed the Ingress `/api` rule points at a Service `taskboard-backend` on port **8080**, which doesn't exist either (the real one listens on 8000).

**Fix (chart only):** in `backend-service.yaml` I named the Service `backend` (same name as in compose, so `nginx.conf` works unchanged in both places), and in `ingress.yaml` I pointed `/api` at `backend:8000`. Labels and selector were unchanged.

The backend also restarted 2-3 times right after install:

![backend restarts](screenshots/41-backend-restarts.png)

That's the same postgres race I mentioned in B.1: the `CMD` runs `alembic upgrade head` straight away, postgres wasn't accepting connections yet (`Connection refused`), the container exited and Kubernetes restarted it until postgres was ready. It heals itself, so I didn't change it (an initContainer that waits for `pg_isready` would be the clean fix).

### I.4 Upgrade with the fix

```bash
helm upgrade --install taskboard ./helm/taskboard --namespace taskboard ...same --set flags...
kubectl -n taskboard rollout restart deployment/taskboard-frontend
kubectl -n taskboard rollout status deployment/taskboard-frontend
kubectl get all -n taskboard
kubectl get pods -n taskboard -o wide
helm list -n taskboard; helm history taskboard -n taskboard; helm get values taskboard -n taskboard
```

![helm upgrade fixed](screenshots/42-helm-upgrade-fixed.png)
![get all running](screenshots/43-kubectl-get-all.png)
![helm list history values](screenshots/44-helm-list.png)

**What I saw:** everything is `Running`: 2 frontend, 2 backend, 1 postgres, Services `backend`, `taskboard-frontend`, `taskboard-postgres`, and the HPA (`cpu: 2%/60%`, 2 replicas). Helm history shows the install and the upgrade, and `helm get values` shows only my overrides. That's the "values" idea: the chart stays generic and each environment passes its own values (`values-dev.yaml`, `values-prod.yaml`).

---

## Part J - Kubernetes components

### J.1 Deployment self-healing

```bash
kubectl -n taskboard get deploy
kubectl -n taskboard delete pod <one backend pod> --wait=false
kubectl -n taskboard get pods -l app=taskboard-backend     # right after, and ~25s later
```

![self heal](screenshots/45-deployment-selfheal.png)

**What I saw:** while the deleted pod was still `Terminating`, the ReplicaSet had already created a replacement (`0/1 Running`, then `1/1` once `/ready` passed). Termination took more than 25 s. My guess is it's because the container runs `sh -c "alembic ... && uvicorn ..."`, so `sh` is PID 1 and doesn't forward SIGTERM to Uvicorn, and Kubernetes waits out the 30 s grace period. `exec uvicorn ...` in the CMD would fix that.

### J.2 Services and endpoints

```bash
kubectl -n taskboard get svc
kubectl -n taskboard get endpointslices -o wide
kubectl -n taskboard describe svc backend
kubectl -n taskboard run curl-test --restart=Never --image=curlimages/curl:8.11.1 -- sh -c "curl backend:8000/health; curl backend.taskboard.svc.cluster.local:8000/api/tasks/stats; curl taskboard-frontend/; curl taskboard-frontend/api/tasks/stats"
kubectl -n taskboard logs curl-test
```

![services endpoints](screenshots/46-services-endpoints.png)

**What I saw:** the Service has a stable ClusterIP while the pod IPs behind it change (the EndpointSlice still listed 3 backend IPs because one pod was in the middle of being replaced). From inside the cluster, both the short name `backend` and the FQDN `backend.taskboard.svc.cluster.local` work, and so does the frontend -> nginx -> backend path. Stats are 0 because this is a fresh in-cluster database, separate from the compose one.

### J.3 PostgreSQL in the cluster

```bash
kubectl -n taskboard get pvc,secret
kubectl -n taskboard exec deploy/taskboard-postgres -- psql -U taskboard -d taskboard -c "\dt"
kubectl -n taskboard exec deploy/taskboard-postgres -- psql -U taskboard -d taskboard -c "SELECT version_num FROM alembic_version;"
```

![k8s postgres](screenshots/47-k8s-postgres.png)

**What I saw:** the 5Gi PVC is `Bound` on minikube's `standard` (hostpath) StorageClass, the `taskboard-postgres` Secret holds the user and password, and the backend pods' Alembic created the tables. For a real AWS setup I'd use RDS instead: backups, Multi-AZ and patching become AWS's job, and the chart would only need `postgres.host` pointed at the RDS endpoint.

---

## Part K - Ingress

The instructor's command for this part uses `values-dev.yaml` (1 replica, ingress on, HPA off). I added my local image overrides:

```bash
cat helm/taskboard/values-dev.yaml
helm upgrade --install taskboard ./helm/taskboard -n taskboard -f helm/taskboard/values-dev.yaml \
  --set backend.image=taskboard-backend --set backend.tag=local \
  --set frontend.image=taskboard-frontend --set frontend.tag=local --set monitoring.serviceMonitor.enabled=false
kubectl -n taskboard get deploy,hpa,ingress
kubectl get ingressclass
kubectl -n ingress-nginx get pods,svc
kubectl -n taskboard describe ingress taskboard
```

![helm upgrade dev values](screenshots/48-helm-upgrade-dev-ingress.png)
![ingress](screenshots/49-ingress.png)

**What I saw:** with dev values, each Deployment dropped to 1 replica and the HPA disappeared. The Ingress `taskboard` (class `nginx`, host `taskboard.local`) has `/api -> backend:8000` and `/ -> taskboard-frontend:80`, and both resolve to real pod IPs. Before my chart fix, the `/api` line would have pointed at a Service that doesn't exist. The Ingress object is only configuration; the ingress-nginx controller pod in `ingress-nginx` is what actually serves it.

To reach it without `sudo` or editing `/etc/hosts`, I port-forwarded the controller and sent the `Host` header myself:

```bash
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 18321:80     # terminal 2
curl -s -i -H "Host: taskboard.local" http://localhost:18321/
curl -s -H "Host: taskboard.local" -X POST http://localhost:18321/api/tasks -H "Content-Type: application/json" -d '{...}'
curl -s -H "Host: taskboard.local" http://localhost:18321/api/tasks
curl -s -H "Host: taskboard.local" http://localhost:18321/api/tasks/stats
curl -s -o /dev/null -w "%{http_code}" http://localhost:18321/          # no Host header
```

![ingress curl](screenshots/50-ingress-curl.png)

**What I saw:** with `Host: taskboard.local`, `/` returns the React `index.html` and `/api/...` reaches FastAPI (POST 201, GET, stats). Without the Host header it's a **404** from nginx's default backend, because no rule matches. That's host-based routing working.

For a browser screenshot through the Ingress, Chromium can't set a custom `Host` header here, so I ran a tiny throwaway proxy on `127.0.0.1:18322` that forwards to the port-forward and sets `Host: taskboard.local`. It wasn't part of the project and is gone now. Then I created a task in the UI:

![TaskBoard through the Ingress](screenshots/51-ui-via-ingress.png)

**What I saw:** the full path minikube -> ingress-nginx -> `taskboard-frontend` -> nginx `/api` proxy -> `backend` -> postgres works from a real browser. The three tasks are the two I created by curl plus the one created in this browser session.

---

## Part L - HPA

### L.1 Back to default values (HPA on)

```bash
helm upgrade --install taskboard ./helm/taskboard -n taskboard --set ingress.enabled=true \
  --set backend.image=taskboard-backend --set backend.tag=local \
  --set frontend.image=taskboard-frontend --set frontend.tag=local --set monitoring.serviceMonitor.enabled=false
kubectl -n taskboard get deploy,hpa
kubectl -n taskboard describe hpa taskboard-backend
kubectl top pods -n taskboard
kubectl -n kube-system get deploy metrics-server
```

![helm upgrade hpa a](screenshots/52-helm-upgrade-hpa-a.png)
![helm upgrade hpa b](screenshots/52-helm-upgrade-hpa-b.png)

**What I saw:** HPA `taskboard-backend` -> `Deployment/taskboard-taskboard-backend`, min 2 / max 6, target 60% of the CPU **request** (100m, so it scales above about 60m per pod). `ScalingActive True / ValidMetricFound` means metrics-server is feeding it.

### L.2 Load with the instructor's script

`scripts/load-test.sh` loops 500 `curl`s at `$URL`. Its default `http://taskboard.local/api/health` doesn't work here: `taskboard.local` doesn't resolve without `/etc/hosts`, and the backend has no `/api/health` route anyway (it's `/health`, see the route list in B.2). The script already takes `URL` from the environment, so I didn't edit it. I mounted it unchanged from a ConfigMap into 3 small `curlimages/curl` pods that run it in a loop against `http://backend:8000/api/tasks` (that route queries Postgres, so it burns more CPU than `/health`). The pods were capped at 200m CPU each to keep the shared minikube happy.

```bash
cat scripts/load-test.sh
kubectl -n taskboard create configmap load-test-script --from-file=scripts/load-test.sh
cat <<'EOF' | kubectl apply -f -      # Deployment load-generator: 3 x "while true; do sh /scripts/load-test.sh; done"
...
EOF
kubectl -n taskboard logs deploy/load-generator --tail=3
```

![load test setup](screenshots/53-load-test-setup.png)

In another terminal I watched the HPA, adding a timestamp to each line:

```bash
kubectl get hpa -n taskboard -w
kubectl get hpa -n taskboard
kubectl -n taskboard describe hpa taskboard-backend      # Events
kubectl top pods -n taskboard -l app=taskboard-backend
```

![hpa under load](screenshots/54-hpa-under-load.png)
![hpa watch](screenshots/55-hpa-watch.png)

**What I saw:**

- 20:22:24 - 3%, 2 replicas
- 20:23:42 - load kicks in: **179%/60%** (each backend pod around 180m)
- 20:23:57 - **4** replicas (`New size: 4; reason: cpu resource utilization ... above target`)
- 20:24:12 - **6** replicas (= maxReplicas), and CPU per pod drops to 117% as the load spreads out
- I stopped the load right after it hit 6 replicas (`56-load-stop`). CPU fell to 2-15%, but the replicas stayed at 6, because scale-down has a 5-minute stabilisation window so it doesn't flap. (I ran the script once more with a single generator for a few minutes around 20:26-20:29, which is the small bump to 23-24%.)
- 20:30:43 - **3** replicas, 20:35:43 - back to **2** (`All metrics below target`)

![load stop](screenshots/56-load-stop.png)
![hpa scaled down](screenshots/74-hpa-scaled-down.png)

### L.3 Helm v4 vs the HPA (a Helm v4 difference)

While the HPA had the backend at 6 replicas, I ran another `helm upgrade` and it **failed**:

```bash
helm upgrade --install taskboard ./helm/taskboard -n taskboard --set ingress.enabled=true ...
helm history taskboard -n taskboard
kubectl -n taskboard get deploy taskboard-taskboard-backend --show-managed-fields -o json | python3 -c '...who owns spec.replicas...'
```

![helm v4 replicas conflict](screenshots/59-helm-v4-replicas-conflict.png)

**What I saw:** `conflict occurred while applying object ... Apply failed with 1 conflict: conflict with "kube-controller-manager" with subresource "scale" using apps/v1: .spec.replicas`, and revision 5 is `failed`. Helm **v4 uses server-side apply** by default. The HPA (running inside kube-controller-manager) had taken ownership of `.spec.replicas` through the `scale` subresource, and the chart was still setting `replicas: {{ .Values.replicaCount }}`, so the API server refused to let two managers fight over the field. Helm v3 used client-side 3-way merges and would have silently reset the Deployment to 2 replicas in the middle of a scale-up, which is arguably worse.

**Fix (chart):** `backend-deployment.yaml` now only sets `replicas` when the HPA is off (`{{- if not .Values.hpa.enabled }}`). That's the standard pattern for a Deployment managed by an HPA. With `values-dev.yaml` (HPA off) it still renders `replicas: 1`.

```bash
kubectl -n taskboard get hpa
helm upgrade --install taskboard ./helm/taskboard -n taskboard ...same flags...
helm history taskboard -n taskboard
```

![helm upgrade after fix](screenshots/60-helm-upgrade-replicas-fixed.png)

**What I saw:** revision 6 `deployed`, and the backend stayed at the 6 replicas the HPA wanted.

Other Helm v4 things I noticed: install/upgrade print a `DESCRIPTION:` line, and the `helm` commands themselves (`upgrade --install`, `list`, `history`, `get values`, `uninstall --wait`) worked the same as v3 for this chart. `azure/setup-helm@v4` in CI installs the latest Helm too, which is why this fix matters for the pipeline as well.

---

## Part M - Monitoring (skipped)

Part M (installing kube-prometheus-stack with `monitoring/prometheus-values.yaml`, scraping the backend through the chart's ServiceMonitor, and showing Prometheus + Grafana) is **skipped for this submission**. I'd started on it, but per the scope change I uninstalled the stack and deleted its `monitoring` namespace and the `monitoring.coreos.com` CRDs, and left those screenshots out. The chart's ServiceMonitor stays disabled (`monitoring.serviceMonitor.enabled=false`), so the chart installs fine without the operator.

The application side of observability is still covered elsewhere: the backend's Prometheus `/metrics` endpoint (B.3) and `/health` + `/ready` probes (Part I).

---

## Part N - Troubleshooting lab

### N.1 Broken image

```bash
kubectl apply -f troubleshooting/broken-image.yaml
kubectl -n taskboard get pods -l app=broken-image
kubectl -n taskboard describe pod <pod>                 # Containers + Events
kubectl -n taskboard get events --sort-by=.lastTimestamp --field-selector involvedObject.name=<pod>
```

![broken image](screenshots/69-broken-image.png)

**Investigation:** the pod is `ImagePullBackOff`. `describe` shows `Image: ghcr.io/example/taskboard-backend:does-not-exist`, and the events show the chain `Pulling` -> `Failed to pull image ... failed to fetch anonymous token ... 403 Forbidden` -> `ErrImagePull` -> `Back-off pulling image` -> `ImagePullBackOff`. GHCR returns 403 to anonymous pulls of a repo/tag that doesn't exist (or is private).

**Root cause:** wrong image reference (non-existent repo and tag).

**Fix + verify:**

```bash
kubectl -n taskboard set image deployment/taskboard-broken-image backend=taskboard-backend:local
kubectl -n taskboard rollout status deployment/taskboard-broken-image
kubectl -n taskboard get pods -l app=broken-image
# ...a few seconds later it errors and restarts -> second problem
kubectl -n taskboard set env deployment/taskboard-broken-image DATABASE_URL=postgresql+psycopg://taskboard:taskboard@taskboard-postgres:5432/taskboard
kubectl -n taskboard get pods -l app=broken-image
kubectl -n taskboard logs deploy/taskboard-broken-image --tail=4
```

![broken image fix](screenshots/70-broken-image-fix.png)

**What I saw:** this one had a second layer. Once the image pulled, `rollout status` said "successfully rolled out" and the pod showed `Running`, but the manifest has no readiness probe, so Kubernetes had no way to know it wasn't really working. A few seconds later the pod went `Error` with `RESTARTS 1`. The backend image runs Alembic first, and this manifest has no `DATABASE_URL`, so it fell back to the default `localhost:5432` and failed. After adding the env var it stayed `Running` with `0` restarts, and the log ended with `Uvicorn running on http://0.0.0.0:8000`. Lesson: a pod showing "Running" doesn't prove the app works. Probes do.

### N.2 Broken Service

```bash
kubectl apply -f troubleshooting/broken-service.yaml
kubectl -n taskboard get svc
kubectl -n taskboard get endpoints broken-service backend
kubectl -n taskboard describe svc broken-service
kubectl -n taskboard get pods --show-labels
kubectl -n taskboard get pods -l app=label-that-does-not-exist
kubectl -n taskboard run svc-test ... curl -m 5 http://broken-service:8080/health
```

![broken service](screenshots/71-broken-service.png)

**Investigation:** the Service exists and has a ClusterIP, but `ENDPOINTS <none>` (compare `backend`, which has 3). Its selector is `app=label-that-does-not-exist`, `--show-labels` shows no pod with that label, and selecting by it returns `No resources found`. curl from inside the cluster fails with exit code **7** (couldn't connect).

**Root cause:** no Pod matches the label selector, so there are no endpoints and no traffic.

**Fix + verify:**

```bash
kubectl -n taskboard patch svc broken-service -p '{"spec":{"selector":{"app":"taskboard-backend"}}}'
kubectl -n taskboard get endpointslices -l kubernetes.io/service-name=broken-service
# curl again -> still exit 7
kubectl -n taskboard get pod -l app=taskboard-backend -o jsonpath='{.items[0].spec.containers[0].ports}'
kubectl -n taskboard patch svc broken-service --type=json -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":8000}]'
# curl again -> {"status":"UP"} exit 0
kubectl -n taskboard describe svc broken-service
```

![broken service fix](screenshots/72-broken-service-fix.png)

**What I saw:** fixing the selector gave the Service endpoints, but on port **8080**, and curl *still* failed with exit 7. The manifest also has `targetPort: 8080`, while the backend container listens on **8000**. After pointing `targetPort` at 8000, `curl http://broken-service:8080/health` returned `{"status":"UP"}`. So `port` (what clients call, 8080) and `targetPort` (what the pod listens on, 8000) are separate things, and you have to check both.

Then I removed both lab objects:

![troubleshooting cleanup](screenshots/73-troubleshooting-cleanup.png)

---

## Part O - FINAL DEMO checklist

| # | Demo item | Evidence |
|---|---|---|
| 1 | Application - open TaskBoard and create a task | [10a](screenshots/10a-ui-create-task-modal.png), [10d](screenshots/10d-ui-dashboard-compose.png) (compose), [51](screenshots/51-ui-via-ingress.png) (Kubernetes via Ingress) |
| 2 | API - Swagger + create/read/update/delete | [11](screenshots/11-swagger-docs.png), [08a](screenshots/08-crud-a.png), [08b](screenshots/08-crud-b.png) |
| 3 | Database - show the `tasks` table | [12](screenshots/12-database.png) (compose), [47](screenshots/47-k8s-postgres.png) (cluster) |
| 4 | Git - make a change and commit it | [18](screenshots/18-git.png) (repo state). **TODO:** commit + push (Part D) |
| 5 | CI - push and show tests running | Workflow validated: [76](screenshots/76-actionlint.png); same tests locally: [16b](screenshots/16-pytest-pass-b.png). **TODO:** Actions run screenshot (Part F) |
| 6 | Docker - show the two images | [21](screenshots/21-docker-images.png), [27](screenshots/27-rebuild-after-fixes.png) |
| 7 | Security - Trivy scanning the images | [24a](screenshots/24-trivy-image-backend-a.png), [25](screenshots/25-trivy-image-frontend.png), [26](screenshots/26-trivy-ci-gate.png) (fail), [28](screenshots/28-trivy-gate-after-fixes.png) (pass) |
| 8 | Registry - images in GHCR | **TODO:** after the first green run, screenshot `github.com/Ridaa10394?tab=packages` showing `taskboard-backend` / `taskboard-frontend` with the commit-SHA tag |
| 9 | Terraform - show the AWS infrastructure code | [77e](screenshots/77-fixes-diff-e.png) (main.tf), [32a](screenshots/32-terraform-init-validate-a.png), [32b](screenshots/32-terraform-init-validate-b.png), [33](screenshots/33-terraform-plan.png). **TODO:** plan/apply/destroy with AWS (Part H) |
| 10 | Kubernetes - `kubectl get pods/svc -n taskboard` | [75](screenshots/75-final-demo-k8s.png), [43](screenshots/43-kubectl-get-all.png) |
| 11 | Helm - `helm list -n taskboard` | [75](screenshots/75-final-demo-k8s.png), [44](screenshots/44-helm-list.png) |
| 12 | Ingress - open the app through the Ingress hostname | [50](screenshots/50-ingress-curl.png), [51](screenshots/51-ui-via-ingress.png) |
| 13 | HPA - `kubectl get hpa -n taskboard` | [54](screenshots/54-hpa-under-load.png), [55](screenshots/55-hpa-watch.png), [74](screenshots/74-hpa-scaled-down.png) |
| 14 | Monitoring - Prometheus and Grafana | **Skipped** for this submission (Part M) |
| 15 | Failure simulation - break a Service/image and fix it | [69](screenshots/69-broken-image.png) -> [70](screenshots/70-broken-image-fix.png), [71](screenshots/71-broken-service.png) -> [72](screenshots/72-broken-service-fix.png) |

---

## GRADING.md rubric - where each module is covered

| Module | Points | Where | Notes / gaps in the reference project |
|---|---|---|---|
| M1 Application | 10 | Part B (06, 08, 09, 10a/10d, 11, 12) | `/health` 200; GET/POST/PUT/DELETE + stats; Alembic `0001_create_tasks`; responsive React UI (fixed the create-task bug) |
| M2 Testing | 10 | Part C (15, 16, 17, 29) | pytest passes after the fixture fix; uses a SQLite test DB; `pytest.ini` present. **Gap:** only 3 tests over 2 endpoints (`/health`, `/`) + POST, while the rubric wants at least 5 tests over 3+ endpoints |
| M3 Git/GitHub | 5 | Part D (18) | 15 commits on `main`; `.gitignore` covers `.env`, `__pycache__`, `node_modules`, `.venv`. Repo link after push |
| M4 Docker | 10 | Part B (04, 05, 30), Part E (19-22) | Both build; frontend is multi-stage; `docker compose up --build` runs all 3. **Gap:** frontend image runs as root (backend is uid 10001) |
| M5 CI/CD | 15 | Part F (34, 76) + root workflow | Triggers on push to main; pytest gates the build; frontend built; both images built; GHCR push; SHA tags. **TODO:** green run URL + GHCR screenshot |
| M6 DevSecOps | 5 | Part G (23-28) | Trivy on both images in CI, fails on fixable HIGH/CRITICAL; CVEs explained in G.2. **TODO:** CI Trivy step screenshot |
| M7 Terraform | 15 | Part H (31-33) | Valid HCL (after the syntax fix), init OK, validate OK; VPC with 2 public subnets + EKS with a managed node group in code. **TODO:** plan/apply/console/destroy with AWS. **Gap:** no `terraform.tfvars.example` |
| M8 Kubernetes + Helm | 15 | Parts I-L (35-56, 59-60, 74, 75) | namespace.yaml applies; chart has Chart.yaml/values/templates; `helm upgrade --install` works (after 3 chart fixes); 2 replicas each; ClusterIP Services; Ingress `/` + `/api`; all pods Running |
| M9 Observability | 10 | **Skipped** (Part M) | Not done for this submission; only the app's `/metrics` endpoint is shown (07) |
| M10 Docs + presentation | 5 | This README | Live demo: commit -> pipeline -> `deploy-kind` redeploys the new SHA (TODO after push) |

---

## Fixes I made to the instructor's code

Everything below is shown as a real `diff -ru` against the instructor's original in [`outputs/77-fixes-diff.txt`](outputs/77-fixes-diff.txt):

![diff a](screenshots/77-fixes-diff-a.png)
![diff b](screenshots/77-fixes-diff-b.png)
![diff c](screenshots/77-fixes-diff-c.png)
![diff d](screenshots/77-fixes-diff-d.png)
![diff e](screenshots/77-fixes-diff-e.png)
![diff f](screenshots/77-fixes-diff-f.png)

| # | File | What broke | Why | What I changed |
|---|---|---|---|---|
| 1 | `frontend/src/main.jsx` | "Create task" saved the task but the modal stayed open and the list didn't refresh (`TypeError: Cannot read properties of null (reading 'reset')`) | React clears `e.currentTarget` after the handler's synchronous part, and it was used after `await fetch(...)` | Save `const form=e.currentTarget` before the `await` and call `form.reset()` |
| 2 | `backend/tests/test_api.py` | `pytest`: 1 failed, `no such table: tasks` | `TestClient(app)` without `with` never runs the startup event that creates the table | Module-scoped autouse fixture: `with client: yield` |
| 3 | `backend/requirements.txt` | CI Trivy gate (exit-code 1) failed on the backend image | Starlette 0.41.3 (via FastAPI 0.115.6) has 3 fixable HIGH CVEs; instrumentator 7.0.2 pins Starlette below 1.0 | `fastapi==0.142.2`, `prometheus-fastapi-instrumentator==8.1.0` (gives Starlette 1.7.0) |
| 4 | `frontend/Dockerfile` | CI Trivy gate failed on the frontend image (42 HIGH + 2 CRITICAL, all fixable) | Old `nginx:1.27-alpine` base, Alpine 3.21.3 packages | `RUN apk upgrade --no-cache` in the runtime stage |
| 5 | `terraform/main.tf`, `terraform/versions.tf` | `terraform init` / `validate`: `Invalid single-argument block definition` | HCL one-line blocks may only hold one argument; the version pins weren't even read | Same content, one argument per line (`terraform fmt` clean) |
| 6 | `helm/taskboard/templates/backend-service.yaml` | Frontend pods `CrashLoopBackOff`: `host not found in upstream "backend"` | `nginx.conf` proxies to `backend:8000`, but the chart named the Service `taskboard-taskboard-backend` | Service name `backend` |
| 7 | `helm/taskboard/templates/ingress.yaml` | `/api` rule pointed at Service `taskboard-backend:8080`, which doesn't exist | Name and port didn't match the real Service (port 8000) | `backend:8000` |
| 8 | `helm/taskboard/templates/backend-deployment.yaml` | `helm upgrade` failed while the HPA had scaled: conflict on `.spec.replicas` | Helm v4 server-side apply vs the HPA owning `replicas` | Only render `replicas` when `hpa.enabled` is false |

Not code changes, but things I added: `docker-compose.alt-ports.yml` (my laptop's ports), the extended `.gitignore`, the note at the top of the instructor's `ci-cd.yml`, and the root workflow `s21-capstone.yml` (Part F).

## TODO (things that can't run from my laptop)

1. **Push** `20-final-capstone/` + `.github/workflows/s21-capstone.yml` (commands in Part D), then make one small visible change, commit and push it (FINAL DEMO item 4).
2. **GitHub Actions run**: screenshot the green run (all 4 jobs) plus the pytest, Trivy and `deploy-kind` smoke-test steps, and paste the run URL (Part F).
3. **GHCR**: screenshot the `taskboard-backend` and `taskboard-frontend` packages with the commit-SHA tag (FINAL DEMO item 8).
4. **AWS Terraform**: `terraform plan` / `apply` / console screenshots / `destroy` with a real AWS account (Part H).
5. (Optional) To deploy to the real EKS cluster from CI, add the base64 kubeconfig as the `KUBE_CONFIG_DATA` repo secret. The guarded `deploy` job then runs the instructor's `helm upgrade --install` against it.

## Cleanup

At the end I removed everything I'd created, without touching `s09`, `s17` or restarting minikube:

```bash
helm uninstall taskboard -n taskboard --wait
kubectl delete namespace taskboard
minikube image rm docker.io/library/taskboard-backend:local docker.io/library/taskboard-frontend:local
docker compose -f docker-compose.yml -f docker-compose.alt-ports.yml down -v
docker rmi taskboard-backend:local taskboard-frontend:local 20-final-capstone-backend:latest 20-final-capstone-frontend:latest
rm -rf backend/.venv backend/.pytest_cache terraform/.terraform terraform/.terraform.lock.hcl
kubectl get ns; helm list -A
```

(The monitoring stack had already been uninstalled, and its namespace and CRDs deleted, when Part M was dropped.)

![cleanup a](screenshots/78-cleanup-a.png)
![cleanup b](screenshots/78-cleanup-b.png)

## Lessons learned

- **"It works on compose" doesn't mean it works on Kubernetes.** The nginx `backend` hostname only existed because of the compose service name. In the cluster, Service names are part of the contract between components, and so are ports (the Ingress pointed at 8080 while the Service and pod use 8000).
- **Read the error all the way down.** Trivy's Terraform parser, `terraform init` and the nginx `[emerg]` line all said exactly what was wrong. The Terraform one even hid a second problem: unreadable version pins quietly pulled newer, incompatible modules.
- **A security gate that fails on day one is still useful.** It caught three real Starlette CVEs and an unpatched Alpine base before anything was pushed. Fixing the dependency also showed that a transitive pin (`starlette<1.0` in the instrumentator) can block a security fix.
- **Running isn't the same as Ready.** The broken-image deployment said "successfully rolled out" and then crashed, because it had no readiness probe. The real chart has `/ready`, which checks the DB, and that's why the HPA scale-out only sent traffic to pods that could actually serve.
- **HPA needs requests + metrics, and it's slow to scale down on purpose.** 2 -> 4 -> 6 in about 30 s, but 6 -> 2 took about 10 minutes because of the scale-down stabilisation window.
- **Helm v4's server-side apply surfaces ownership conflicts** that Helm v3 used to paper over. If an HPA owns `replicas`, the chart must not set it.
- **Tests have to actually exercise the DB.** Two of the three original tests passed without touching the database, which is how the startup bug got through. With only 63% coverage of `main.py`, PUT/DELETE/stats are untested, and that's the first thing I'd add.

# Session 17 - DevSecOps app image
# Multi-stage: deps are installed in a throwaway stage, the runtime stage has no
# pip cache and runs as a fixed non-root UID (matches the k8s securityContext).

FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
# Patch fixable Debian CVEs at build time, drop pip from the runtime image
# (trivy found 6 CVEs in the bundled pip 25.0.1 and the app never needs pip
# at runtime), and create the non-root user.
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/* \
 && python -m pip uninstall -y pip \
 && groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app
COPY --from=builder /install /usr/local
WORKDIR /app
# Code is owned by root and only readable by the app user - it cannot modify itself.
COPY --chown=root:root app ./app
USER 10001:10001
EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:5000/health', timeout=2).status == 200 else 1)"
# gunicorn instead of the Flask dev server. For a read-only root filesystem:
#   --worker-tmp-dir /tmp   heartbeat files go to /tmp (an emptyDir in k8s)
#   --no-control-socket     gunicorn 26 otherwise creates ~/.gunicorn/gunicorn.ctl
#                           and logs "Read-only file system" on every start
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--worker-tmp-dir", "/tmp", "--no-control-socket", "--access-logfile", "-", "app.app:app"]

#!/usr/bin/env bash
# Run the same stages as .github/workflows/s17-devsecops.yml on a laptop.
#
#   cd 16-devsecops
#   ./scripts/local-pipeline.sh            # stages 1-8 (build ... security gate)
#   DEPLOY=1 ./scripts/local-pipeline.sh   # + load into minikube and deploy to namespace s17
#
# Needs: python3 (>= 3.11), docker, trivy, gitleaks (+ minikube/kubectl for DEPLOY=1).
# bandit / pip-audit / pytest are installed into a venv ($VENV, default .venv).
set -euo pipefail
cd "$(dirname "$0")/.."

VENV="${VENV:-.venv}"
IMAGE="${IMAGE:-s17-devsecops:1.0}"
stage() { printf '\n========== %s ==========\n' "$*"; }

stage "1. Build"
[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --disable-pip-version-check -r requirements-dev.txt bandit==1.9.4 pip-audit==2.10.1
"$VENV/bin/python" -m compileall -q app
"$VENV/bin/pip" check

stage "2. Unit Test"
"$VENV/bin/pytest" -q -p no:cacheprovider --cov=app --cov-report=term --cov-fail-under=80

rm -rf reports && mkdir -p reports

stage "3. SAST (bandit)"
"$VENV/bin/bandit" -q -c security/bandit.yaml -r app -f json -o reports/bandit.json --exit-zero
"$VENV/bin/bandit" -q -c security/bandit.yaml -r app || true

stage "4. SCA (pip-audit + trivy fs)"
"$VENV/bin/pip-audit" -r requirements.txt -f json -o reports/pip-audit.json || true
"$VENV/bin/pip-audit" -r requirements.txt || true
trivy fs --config security/trivy.yaml --severity HIGH,CRITICAL --no-progress --quiet .

stage "5. Secret Scan (gitleaks)"
gitleaks detect --no-git --source . --config security/.gitleaks.toml --redact --no-banner --no-color \
  --exit-code 0 --report-format json --report-path reports/gitleaks.json

stage "6. Docker Build"
docker build -q -t "$IMAGE" .

stage "7. Container Image Scan (trivy)"
trivy image --config security/trivy.yaml --no-progress --quiet -f json -o reports/trivy-image.json "$IMAGE"
trivy image --ignorefile security/.trivyignore --severity HIGH,CRITICAL --ignore-unfixed \
  --no-progress --quiet "$IMAGE"

stage "8. Security Gate"
"$VENV/bin/python" security/gate.py --reports reports   # set -e: a FAIL stops the script here

if [ "${DEPLOY:-0}" = "1" ]; then
  stage "9. Push (local: minikube image load instead of GHCR)"
  minikube image load "$IMAGE"

  stage "10. Deploy to Kubernetes (minikube, namespace s17)"
  kubectl --context minikube apply -f k8s/namespace.yaml
  kubectl --context minikube apply -f k8s/deployment.yaml -f k8s/service.yaml
  kubectl --context minikube -n s17 rollout restart deployment/s17-devsecops
  kubectl --context minikube -n s17 rollout status deployment/s17-devsecops --timeout=180s
  kubectl --context minikube -n s17 get pods -o wide
fi

printf '\nLocal pipeline finished OK\n'

#!/usr/bin/env bash
# ==============================================================================
# Script: triage_all.sh
# Purpose: Deploys all 5 broken pods for the Session 14 Triage Gauntlet
# (adapted from the class repo: everything goes into one namespace, NS, default s14-triage,
#  so it doesn't touch anything else on a shared cluster)
# usage: ./triage_all.sh            -> deploy broken pods
#        ./triage_all.sh fix        -> apply fixed.yaml for every scenario
#        ./triage_all.sh clean      -> delete the namespace's triage pods
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS="${NS:-s14-triage}"
MODE="${1:-broken}"
SCENARIOS=(scenario-1-crashloop scenario-2-imagepull scenario-3-pending scenario-4-dns-failure scenario-5-oomkilled)

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

case "$MODE" in
  broken)
    echo "=================================================="
    echo "      KUBERNETES INCIDENT TRIAGE GAUNTLET         "
    echo "=================================================="
    echo "Deploying 5 intentionally broken workloads into namespace: $NS"
    echo ""
    for s in "${SCENARIOS[@]}"; do
      kubectl -n "$NS" apply -f "$SCRIPT_DIR/$s/broken.yaml"
    done
    echo ""
    echo "Workloads deployed! Sleeping 5s to allow states to settle..."
    sleep 5
    echo ""
    echo "=== CURRENT CLUSTER CARNAGE ==="
    kubectl -n "$NS" get pods -l tier=triage-gauntlet
    ;;
  fix)
    for s in "${SCENARIOS[@]}"; do
      # pod specs are mostly immutable, so delete + re-apply
      kubectl -n "$NS" delete -f "$SCRIPT_DIR/$s/broken.yaml" --ignore-not-found --wait=true
      kubectl -n "$NS" apply -f "$SCRIPT_DIR/$s/fixed.yaml"
    done
    ;;
  clean)
    kubectl -n "$NS" delete pods,svc -l tier=triage-gauntlet --ignore-not-found
    ;;
  *)
    echo "unknown mode: $MODE (use broken | fix | clean)"; exit 1 ;;
esac

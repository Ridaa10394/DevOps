#!/usr/bin/env bash
# Takes a timestamped snapshot of the HPA every INTERVAL seconds.
# usage: ./watch-hpa.sh <namespace> <hpa-name> <app-label> <outfile> [interval]
NS=${1:-s13}
HPA=${2:-yatri-backend-hpa}
APP=${3:-yatri-backend}
OUT=${4:-outputs/hpa-snapshots.txt}
INTERVAL=${5:-20}

while true; do
  {
    echo "=================== $(date '+%Y-%m-%d %H:%M:%S') ==================="
    echo "\$ kubectl get hpa $HPA -n $NS"
    kubectl get hpa "$HPA" -n "$NS"
    echo
    echo "\$ kubectl get pods -n $NS -l app=$APP"
    kubectl get pods -n "$NS" -l app="$APP"
    echo
    echo "\$ kubectl top pods -n $NS"
    kubectl top pods -n "$NS" 2>&1
    echo
    echo "\$ kubectl describe hpa $HPA -n $NS (tail)"
    kubectl describe hpa "$HPA" -n "$NS" | sed -n '/Metrics:/,$p'
    echo
  } >> "$OUT" 2>&1
  sleep "$INTERVAL"
done

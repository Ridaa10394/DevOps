# Session 20 - Observability (Task 2)

Name: Ridaa Mirza
Enrollment No: 24BCS10394

This is the theory half of the session. The hands-on half (Prometheus, Grafana, alerts, ArgoCD) is in the main [README](../README.md).

## Monitoring vs observability

I used to think these were the same word. They're not, but they overlap a lot.

- **Monitoring** answers questions you already knew to ask. "Is CPU above 80%?", "Is the pod up?", "Is the error rate above 1%?". You decide the checks up front, set thresholds, and get alerted when one trips. It's great for *known* failure modes.
- **Observability** is a property of the system: how well you can understand what's going on inside it just by looking at what it emits. It's for the *unknown* failures - the "why is checkout slow only for users in one region on Tuesdays" type of question nobody wrote a dashboard for.

A simple way I remember it:

```
Monitoring    -> tells you THAT something is wrong      (alert: p99 latency > 2s)
Observability -> lets you find out WHY it is wrong      (trace shows 1.8s spent in one DB query
                                                          from one pod after a deploy)
```

Monitoring is something you *do*; observability is something the system *has*. You can't really do good monitoring on a system that isn't observable, because there's nothing useful to monitor.

### Why observability is needed

- **Microservices / Kubernetes are distributed.** One user request can go through an ingress, 5 services, a queue and a DB. When it's slow, "the server" doesn't exist any more - you need to follow the request.
- **Things are ephemeral.** Pods get killed and rescheduled. If you didn't ship the logs/metrics out of the pod, they're gone when the pod is gone.
- **Failure modes are unknown in advance.** You can't write an alert for every possible bug. You need raw signals rich enough to ask new questions later.
- **MTTR (mean time to recovery).** Faster root cause = less downtime. That's the actual business reason.
- **Deploy confidence.** After a release you want to *see* whether error rate / latency changed, not guess.

## The three pillars

### 1. Metrics

Numbers measured over time. Each data point is basically `name{labels} value @ timestamp`.

```
http_requests_total{method="GET", status="200", pod="podinfo-abc"}  10423
container_memory_working_set_bytes{pod="podinfo-abc"}             1.2e7
```

- Cheap to store and fast to query, because it's just numbers.
- Perfect for dashboards, trends and alerting ("rate of 5xx over the last 5m").
- Common types (Prometheus naming): **counter** (only goes up, e.g. requests_total), **gauge** (up and down, e.g. memory in use), **histogram / summary** (distributions, e.g. request duration buckets -> p95/p99).
- Weakness: aggregated, so they tell you *that* the error rate went up, not *which* request failed and why.
- Watch out for **high cardinality** - putting user IDs or request IDs in labels explodes the number of series.

Golden signals people usually start with: **latency, traffic, errors, saturation** (Google SRE). For resources there's also **USE** (utilization, saturation, errors) and for services **RED** (rate, errors, duration).

### 2. Logs

Timestamped text (ideally structured JSON) records of discrete events.

```json
{"level":"info","ts":"2026-10-07T11:45:01Z","msg":"request","method":"GET","path":"/","status":200,"duration":"0.3ms"}
```

- The richest detail - exact error messages, stack traces, input values.
- Expensive at volume (storage + indexing), and hard to aggregate unless they're structured.
- In Kubernetes, containers write to stdout/stderr, the kubelet/container runtime stores them on the node under `/var/log/pods/...`, and `kubectl logs` reads them from there. Once the pod is deleted those files go too, which is why you need a log shipper.

### 3. Traces

A trace follows **one request** across every service it touches. It's made of **spans** (one per operation), each with a start time, duration, and parent span.

```
trace 4bf92f...  GET /checkout                                   [=========================] 820ms
  span  api-gateway                                              [==]                         35ms
  span  cart-service  GET /cart                                     [====]                    90ms
  span  payment-service  POST /charge                                    [===============]   610ms
    span  postgres  SELECT ... FROM cards                                   [=============]  580ms  <- here
```

- Answers "where did the time go?" and "which service actually threw the error?".
- Needs context propagation - every service passes the trace ID along (e.g. W3C `traceparent` header). That's what OpenTelemetry SDKs do for you.
- Usually sampled (you don't keep 100% of traces in prod).

### How they work together

```
 alert fires on a METRIC  ->  open the dashboard, see which service/pod  ->
 jump to its TRACES for slow requests  ->  open the LOGS for that trace_id  ->  root cause
```

The good stacks link these together with shared labels (namespace, pod, service) and a shared `trace_id` that shows up in logs too.

## Common tools

| Category | Tools | Notes |
|---|---|---|
| Metrics collection + storage | **Prometheus**, Thanos, Cortex / Mimir, VictoriaMetrics | Prometheus pulls (`/metrics`) and stores time series; Thanos/Mimir add long-term storage + HA |
| Dashboards | **Grafana**, Kibana | Grafana can read Prometheus, Loki, Tempo, Elasticsearch and more from one UI |
| Alerting | Prometheus rules + **Alertmanager**, Grafana Alerting, PagerDuty / Opsgenie | Alertmanager does grouping, silencing and routing to Slack / email / pager |
| Logs | **Loki** (+ Promtail / Grafana Alloy), **ELK / EFK** (Elasticsearch, Logstash or Fluentd/Fluent Bit, Kibana), Splunk | Loki only indexes labels (cheap); Elasticsearch indexes full text (powerful, heavier) |
| Traces | **Jaeger**, **Grafana Tempo**, Zipkin | All of them accept OpenTelemetry data now |
| Instrumentation standard | **OpenTelemetry** (SDKs + Collector) | Vendor-neutral API for metrics, logs and traces. Instrument once, send anywhere |
| All-in-one SaaS | **Datadog**, New Relic, Dynatrace, Grafana Cloud, Honeycomb, AWS CloudWatch, GCP Cloud Monitoring, Azure Monitor | Less to run yourself, costs money per host / GB |

The "LGTM" stack people mention is Grafana's open source set: **L**oki (logs), **G**rafana (UI), **T**empo (traces), **M**imir (metrics).

## Observability in Kubernetes

Kubernetes gives you a lot of signals for free, but they come from different components:

```
                 +-------------------------- node ----------------------------+
                 |                                                            |
  pods --------> | kubelet + cAdvisor  --(container cpu/mem, /metrics/cadvisor)-+--> Prometheus
  stdout/stderr  | /var/log/pods/*  ---> Fluent Bit / Promtail / Alloy (DaemonSet) --> Loki / Elasticsearch
                 | node-exporter (DaemonSet) --(node cpu, mem, disk, network)-----+--> Prometheus
                 +------------------------------------------------------------+
  API server ----> kube-state-metrics --(desired vs actual state of objects)------> Prometheus
  kubelet -------> metrics-server --(latest cpu/mem only, in memory)--> `kubectl top`, HPA
  API server ----> Events (`kubectl get events`) --(optional event exporter)--> logs backend
  apps ----------> /metrics endpoint (prometheus_client) + OpenTelemetry SDK --> Prometheus / OTel Collector --> Tempo / Jaeger
```

| Component | What it gives you | Example |
|---|---|---|
| **cAdvisor** (built into the kubelet) | Per-container CPU, memory, filesystem, network usage | `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes` |
| **metrics-server** | Latest CPU/memory snapshot per pod/node, kept in memory only. Feeds `kubectl top` and the HPA. Not a history DB | `kubectl top pods -n s20-app` |
| **kube-state-metrics** | The *state* of Kubernetes objects as metrics - replicas desired/available, pod phase, restarts, job status | `kube_deployment_status_replicas_available`, `kube_pod_container_status_restarts_total` |
| **node-exporter** | OS level node metrics: CPU modes, load, memory, disk, network | `node_cpu_seconds_total`, `node_filesystem_avail_bytes` |
| **Probes** | Kubelet's own health checks - liveness restarts, readiness removes from Service endpoints, startup protects slow boots | `livenessProbe: httpGet /healthz` |
| **Events** | Short-lived (1h by default) records of what the control plane did - scheduling, pulls, OOMKills, probe failures | `kubectl get events -n s20-app --sort-by=.lastTimestamp` |
| **Logs pipeline** | Container stdout/stderr -> node files -> a DaemonSet agent (Fluent Bit / Promtail / Alloy) -> Loki or Elasticsearch | `kubectl logs deploy/podinfo` for the quick look |
| **Prometheus Operator** | CRDs (`ServiceMonitor`, `PodMonitor`, `PrometheusRule`) so scrape config and alert rules are declarative YAML next to the app | used in the main README |
| **Tracing** | Apps instrumented with OpenTelemetry -> OTel Collector -> Tempo / Jaeger | not deployed here (see below) |

`kube-prometheus-stack` (what I used in the main README) bundles Prometheus, the Operator, Alertmanager, Grafana, kube-state-metrics and node-exporter, plus a set of default dashboards and alert rules. cAdvisor metrics come from the kubelet it already scrapes.

### What I didn't deploy and why

- **Loki** - the cluster is a shared 4 CPU / 6 GB minikube with other workloads on it. Loki + an agent DaemonSet would work but it's another few hundred MB, so for logs I stuck with `kubectl logs` (which is reading the same node files a Promtail/Alloy agent would tail). On a bigger machine: `helm install loki grafana/loki` in single-binary mode + `grafana/alloy`, then add Loki as a Grafana data source and query `{namespace="s20-app"}` in Explore.
- **Tempo / Jaeger** - podinfo can emit OpenTelemetry traces if you pass `--otel-service-name` and point `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` at a collector, but standing up Tempo + a collector for one demo app was too heavy for the shared cluster.

## Quick summary

- Monitoring = known questions + alerts. Observability = being able to ask new questions.
- Metrics tell you *something* is wrong, traces tell you *where*, logs tell you *why*.
- In Kubernetes: cAdvisor + node-exporter + kube-state-metrics -> Prometheus -> Grafana/Alertmanager for metrics; DaemonSet agent -> Loki/ELK for logs; OpenTelemetry -> Tempo/Jaeger for traces; metrics-server only for `kubectl top` and autoscaling.

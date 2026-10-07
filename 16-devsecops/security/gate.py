#!/usr/bin/env python3
"""Security gate: read the scanner reports, apply gate-policy.toml, exit 1 on violation.

Usage (from 16-devsecops/):
    python security/gate.py --reports reports/ [--policy security/gate-policy.toml]

Expected files in the reports dir (missing ones are treated as a failure,
because a scan that silently did not run must not count as a pass):
    bandit.json      bandit -f json
    pip-audit.json   pip-audit -f json
    gitleaks.json    gitleaks --report-format json
    trivy-image.json trivy image -f json
"""
import argparse
import json
import os
import sys
import tomllib
from pathlib import Path

LEVELS = {"UNDEFINED": 0, "LOW": 1, "MEDIUM": 2, "HIGH": 3}


def load(path):
    if not path.exists():
        return None
    text = path.read_text().strip()
    return json.loads(text) if text else []


def check_sast(report, policy):
    sev = LEVELS[policy["min_severity"]]
    conf = LEVELS[policy["min_confidence"]]
    bad = [
        r for r in report.get("results", [])
        if LEVELS[r["issue_severity"]] >= sev and LEVELS[r["issue_confidence"]] >= conf
    ]
    lines = [
        f"{r['test_id']} {r['issue_severity']}/{r['issue_confidence']} "
        f"{r['filename']}:{r['line_number']} {r['issue_text']}"
        for r in bad
    ]
    return len(bad) == 0, f"{len(report.get('results', []))} total, {len(bad)} blocking", lines


def check_sca(report, policy):
    allowed = {a["id"] for a in policy.get("allow", [])}
    vulns = []
    seen = set()
    for dep in report.get("dependencies", []):
        for v in dep.get("vulns", []):
            ids = {v["id"], *v.get("aliases", [])}
            # pip-audit can list the same advisory twice for one package; count it once
            key = (dep["name"], v["id"])
            if ids & allowed or key in seen:
                continue
            seen.add(key)
            fix = ",".join(v.get("fix_versions", [])) or "none"
            vulns.append(f"{dep['name']}=={dep['version']} {v['id']} (fix: {fix})")
    ok = len(vulns) <= policy["max_vulnerabilities"]
    return ok, f"{len(vulns)} vulnerable (limit {policy['max_vulnerabilities']})", vulns


def check_secrets(report, policy):
    lines = [f"{f['RuleID']} {f['File']}:{f['StartLine']}" for f in report]
    ok = len(report) <= policy["max_findings"]
    return ok, f"{len(report)} findings (limit {policy['max_findings']})", lines


def check_image(report, policy):
    block = set(policy["block_severities"])
    bad = []
    for res in report.get("Results", []) or []:
        for v in res.get("Vulnerabilities", []) or []:
            if v["Severity"] not in block:
                continue
            if policy["ignore_unfixed"] and not v.get("FixedVersion"):
                continue
            bad.append(
                f"{v['Severity']} {v['VulnerabilityID']} {v['PkgName']} "
                f"{v['InstalledVersion']} -> {v.get('FixedVersion')} ({res['Target']})"
            )
    return len(bad) == 0, f"{len(bad)} fixable {'/'.join(sorted(block))}", bad


CHECKS = [
    ("SAST (bandit)", "bandit.json", "sast", check_sast),
    ("SCA (pip-audit)", "pip-audit.json", "sca", check_sca),
    ("Secrets (gitleaks)", "gitleaks.json", "secrets", check_secrets),
    ("Image (trivy)", "trivy-image.json", "image", check_image),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reports", default="reports", type=Path)
    ap.add_argument("--policy", default=Path(__file__).with_name("gate-policy.toml"), type=Path)
    args = ap.parse_args()

    policy = tomllib.loads(args.policy.read_text())
    failed = False
    print(f"Security gate - policy {os.path.relpath(args.policy)}, reports {args.reports}/")
    print("-" * 64)
    for title, fname, key, fn in CHECKS:
        report = load(args.reports / fname)
        if report is None:
            print(f"[FAIL] {title:20} report {fname} missing")
            failed = True
            continue
        ok, summary, details = fn(report, policy[key])
        print(f"[{'PASS' if ok else 'FAIL'}] {title:20} {summary}")
        for d in details[:20]:
            print(f"         - {d}")
        if len(details) > 20:
            print(f"         ... and {len(details) - 20} more")
        failed |= not ok
    print("-" * 64)
    print("GATE RESULT: " + ("FAILED - release blocked" if failed else "PASSED - ok to push and deploy"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

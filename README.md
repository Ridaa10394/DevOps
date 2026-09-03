# DevOps Homework Submission

Name: Ridaa Mirza
Enrollment No: 24BCS10394

This is my homework for the devops-heros course (sessions 1-8): https://github.com/Nency-Ravaliya/devops-heros

## What's in here

1. [Linux Fundamentals](01-linux/) - done
2. [Shell Scripting](02-shell-scripting/) - done
3. [Networking Fundamentals](03-networking/) - done
4. [Git / GitHub](04-git-github/) - done
5. [Docker Fundamentals](05-docker-apps/) - done, logs in [docker-run-logs/](docker-run-logs/)
6. [Dockerfiles & Multi-Stage Builds](06-multi-stage/) - done, logs in [docker-run-logs/](docker-run-logs/)
7. [Docker Networking & Volumes](07-docker-network-volume/) - done, logs in [docker-run-logs/](docker-run-logs/)

## Quick summary of each

**01 - Linux** - soft vs hard links (with a real demo showing the hard link survives deletion), adduser vs useradd, journalctl basics, and a cheat sheet of commands I keep forgetting.

**02 - Shell scripting** - `sysinfo.sh`, prints date/hostname/user/disk/processes, takes input with `read -p`, and writes the process list to a file.

**03 - Networking** - ran through ip addr, ip route, ping, ss, netstat, arp, curl, nc, ifconfig, resolv.conf, hosts etc and wrote down what each one actually tells you. Also did subnetting notes with a few worked examples.

**04 - Git/GitHub** - the difference between `git commit -m` and `git commit -a -m` (with a demo where `-a` skips a new file), plus a full cherry-pick example: 5 commits on main, 3 on a feature branch, cherry-picked one across and checked that it gets a new hash.

**05 - Docker Fundamentals** - 6 hello world apps (Node, Python, Java, Apache, React, Nginx), each with its own Dockerfile.

**06 - Multi-stage builds** - the course's multi-stage app, plus notes on why multi-stage builds are smaller/safer.

**07 - Docker networking & volumes** - 3 containers on 3 networks (with the backend attached to two of them), Apache on the host network, a bind mount demo, and some overlay network research.

## Environment

- OS: Ubuntu 24.04.1 LTS (WSL2), kernel 6.18.33.2-microsoft-standard-WSL2
- Git 2.49.0
- systemd 255


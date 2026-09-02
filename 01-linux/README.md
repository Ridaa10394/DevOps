# Session 1–2 — Linux Fundamentals

**Name:** Ridaa Mirza
**Enrollment No:** 24BCS10394

All commands in this document were executed on **Ubuntu 24.04.1 LTS** (kernel `6.18.33.2-microsoft-standard-WSL2`).
Full raw output is saved in [`links-output.txt`](links-output.txt) and [`journalctl-output.txt`](journalctl-output.txt).

---

## Task 1 — Soft Link vs Hard Link

### The difference

| | Hard link | Soft link (symbolic link) |
|---|---|---|
| What it is | A second **name** for the same inode | A small file that **stores a path** to another file |
| Inode | **Same** inode as the original | **Its own** inode |
| `ls -l` type flag | `-` (regular file) | `l` (link) |
| Link count | Increments the target's count | Target's count unchanged |
| If the original is deleted | **Still works** — data survives until the last hard link goes | **Breaks** — becomes a dangling link |
| Across filesystems | Not allowed | Allowed |
| To a directory | Not allowed | Allowed |
| Size | Same as the file | Size of the stored path string |

The one-line version: **a hard link points at the data, a soft link points at the name.**

### Commands

```bash
ln  original.txt hardlink.txt     # hard link
ln -s original.txt softlink.txt   # soft link  (-s = symbolic)
ls -li                            # -i shows inode numbers
rm hardlink.txt                   # deleting a link never deletes the data
                                  # unless it was the last hard link
```

### Practical demonstration (real output)

Creating both links — note the inode column (first) and the link count (third):

```
$ ls -li
total 8
11856 -rw-r--r-- 2 ridaa ridaa 27 Sep  2 17:16 hardlink.txt
11856 -rw-r--r-- 2 ridaa ridaa 27 Sep  2 17:16 original.txt
11857 lrwxrwxrwx 1 ridaa ridaa 12 Sep  2 17:16 softlink.txt -> original.txt
```

- `original.txt` and `hardlink.txt` both show inode **11856** and link count **2** — they are the same file.
- `softlink.txt` has its own inode **11857**, link count **1**, type `l`, and displays `-> original.txt`.

**The key test — delete the original:**

```
$ rm original.txt

$ cat hardlink.txt   # still works - data survives
This is the original file.
Line added via hardlink.

$ cat softlink.txt   # BROKEN - target is gone
cat: softlink.txt: No such file or directory
```

That is the whole point: the hard link kept the data alive, the soft link broke.

### Interview answer

> A hard link is an additional directory entry pointing to the same inode, so it *is* the file — the data is only freed when the link count drops to zero. A soft link is a separate small file whose contents are a path to the target, so it breaks if the target is moved or deleted. Hard links cannot cross filesystems or point to directories, because inode numbers are only unique within a filesystem; soft links can do both, since they merely store a path.

---

## Task 2 — `adduser` vs `useradd`

| | `useradd` | `adduser` |
|---|---|---|
| Type | Low-level **binary** (`/usr/sbin/useradd`) | High-level **Perl script** wrapping `useradd` |
| Availability | All Linux distributions | Debian / Ubuntu family |
| Interactive | No — silent, flag-driven | Yes — prompts for password, full name |
| Home directory | **Not created** unless you pass `-m` | Created automatically |
| Password | Not set — account stays locked | Prompts you to set one |
| Shell | Distro default, often `/bin/sh` or none | Sets `/bin/bash` |
| Skeleton files | Only with `-m` (copies `/etc/skel`) | Copies `/etc/skel` automatically |
| Best for | **Scripts and automation** | **Humans at a terminal** |

### Which is preferred on Ubuntu, and why

**`adduser` is preferred on Ubuntu for interactive use.** It is the Debian-recommended front-end: it applies distro policy from `/etc/adduser.conf`, creates the home directory, copies `/etc/skel`, sets a sane shell, creates the matching user group, and prompts for a password — all in one step.

A bare `useradd bob` does none of that, leaving a passwordless, home-less, effectively unusable account. `useradd` remains the correct choice **inside scripts, Dockerfiles, and configuration management**, because it is non-interactive and behaves identically across distributions.

### Creating a test user with the recommended command

```bash
# Recommended on Ubuntu - interactive, sets everything up
sudo adduser testuser

# Equivalent using the low-level command (note how many flags are needed)
sudo useradd -m -s /bin/bash -c "Test User" testuser
sudo passwd testuser

# Verify
grep testuser /etc/passwd
id testuser
ls -ld /home/testuser

# Clean up
sudo deluser --remove-home testuser
```

> **Note:** these are the only commands in this homework that require `root`. They were not executed in this environment because `sudo` is password-protected here. Every other command in this repository shows real captured output.

---

## Task 3 — `journalctl`

### What it is

`journalctl` queries the **systemd journal** — the binary, indexed, structured log store written by `systemd-journald`. It replaces scattered plain-text files such as `/var/log/syslog`. Because entries carry structured metadata (unit, PID, UID, priority, boot ID), you can filter precisely instead of grepping text.

### Most useful invocations

| Command | What it does |
|---|---|
| `journalctl` | Everything, oldest first |
| `journalctl -n 20` | Last 20 lines |
| `journalctl -f` | **Follow** live, like `tail -f` |
| `journalctl -u nginx.service` | Logs for **one service** |
| `journalctl -u nginx -f` | Follow one service live |
| `journalctl -b` | Logs from the **current boot** |
| `journalctl -b -1` | Logs from the **previous** boot |
| `journalctl -p err` | Only priority `err` and worse |
| `journalctl --since today` | Time filter |
| `journalctl --since "1 hour ago"` | Relative time window |
| `journalctl -o json-pretty` | Structured output with all metadata |
| `journalctl --disk-usage` | Disk consumed by the journal |
| `journalctl --vacuum-time=7d` | Delete entries older than 7 days |
| `journalctl -k` | Kernel messages only (like `dmesg`) |

Priority levels for `-p`: `emerg(0) alert(1) crit(2) err(3) warning(4) notice(5) info(6) debug(7)`.

### Checking logs for a specific service (real output)

```
$ journalctl -u systemd-resolved.service -n 10 --no-pager
Sep 02 17:18:32 RidasDen systemd[1]: Stopped systemd-resolved.service - Network Name Resolution.
Sep 02 17:18:53 RidasDen systemd[1]: Starting systemd-resolved.service - Network Name Resolution...
Sep 02 17:18:53 RidasDen systemd-resolved[116]: Positive Trust Anchors:
Sep 02 17:18:53 RidasDen systemd-resolved[116]: Using system hostname 'RidasDen'.
Sep 02 17:18:53 RidasDen systemd[1]: Started systemd-resolved.service - Network Name Resolution.
```

Filtering to errors only:

```
$ journalctl -p err -n 10 --no-pager
Sep 02 17:18:53 RidasDen systemd[1]: Failed to start wsl-pro.service - Bridge to Ubuntu Pro agent on Windows.
Sep 02 17:18:42 RidasDen login[362]: PAM unable to dlopen(pam_lastlog.so): No such file or directory
Sep 02 17:18:42 RidasDen login[362]: PAM adding faulty module: pam_lastlog.so
```

This is the practical value of the journal: one flag narrowed thousands of lines down to the three that actually indicate a problem.

Full output including `-b`, `--disk-usage` and `-o json-pretty` is in [`journalctl-output.txt`](journalctl-output.txt).

---

## Task 4 — Linux Command Cheat Sheet

### Navigation and files
| Command | Purpose |
|---|---|
| `pwd` | Print working directory |
| `ls -la` | List all files, long format |
| `cd -` | Jump back to previous directory |
| `touch f` | Create empty file / update timestamp |
| `mkdir -p a/b/c` | Create nested directories |
| `cp -r src dst` | Copy recursively |
| `mv a b` | Move or rename |
| `rm -rf dir` | Delete recursively and forcefully |
| `find . -name "*.log"` | Find files by name |
| `find . -mtime -1` | Files modified in the last day |

### Viewing and editing
| Command | Purpose |
|---|---|
| `cat f` | Print whole file |
| `less f` | Page through a file |
| `head -20 f` | First 20 lines |
| `tail -20 f` | Last 20 lines |
| `tail -f f` | Follow a growing file |
| `grep -rn "text" .` | Recursive search with line numbers |
| `sed -i 's/a/b/g' f` | In-place find and replace |
| `awk '{print $1}' f` | Print the first column |
| `wc -l f` | Count lines |
| `diff a b` | Compare two files |

### Permissions and ownership
| Command | Purpose |
|---|---|
| `chmod 755 f` | rwx for owner, rx for group and others |
| `chmod +x f` | Make executable |
| `chown user:group f` | Change owner and group |
| `umask` | Default permission mask |
| `sudo -i` | Interactive root shell |

### Processes
| Command | Purpose |
|---|---|
| `ps aux` | All running processes |
| `ps -ef` | Same, different format |
| `top` / `htop` | Live process monitor |
| `kill -9 PID` | Force kill |
| `pkill name` | Kill by name |
| `jobs` / `fg` / `bg` | Job control |
| `nohup cmd &` | Run detached from the terminal |

### Disk and system
| Command | Purpose |
|---|---|
| `df -h` | Disk free, human readable |
| `du -sh *` | Size of each item here |
| `free -h` | Memory usage |
| `uname -a` | Kernel and architecture |
| `uptime` | Load average |
| `lsblk` | Block devices |
| `mount` / `umount` | Attach / detach filesystems |

### Services and logs
| Command | Purpose |
|---|---|
| `systemctl status nginx` | Service state |
| `systemctl start nginx` | Start a service |
| `systemctl restart nginx` | Restart a service |
| `systemctl enable nginx` | Start at boot |
| `journalctl -u nginx -f` | Follow service logs |

### Archives, networking, packages
| Command | Purpose |
|---|---|
| `tar -czvf a.tar.gz dir/` | Create a gzip archive |
| `tar -xzvf a.tar.gz` | Extract a gzip archive |
| `curl -I url` | Fetch headers only |
| `wget url` | Download a file |
| `scp f user@host:/path` | Copy over SSH |
| `apt update` | Refresh package lists |
| `apt install pkg` | Install a package |

### Pipes and redirection
| Syntax | Meaning |
|---|---|
| `>` | Redirect stdout, overwrite |
| `>>` | Redirect stdout, append |
| `2>` | Redirect stderr |
| `&>` | Redirect both |
| `\|` | Pipe stdout into the next command |
| `tee f` | Write to a file *and* stdout |
| `xargs` | Turn stdin into arguments |

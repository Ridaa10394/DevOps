# Session 3 — Shell Scripting

**Name:** Ridaa Mirza
**Enrollment No:** 24BCS10394

**Script:** [`sysinfo.sh`](sysinfo.sh)
**Raw captured output:** [`run-output.txt`](run-output.txt)

Executed on **Ubuntu 24.04.1 LTS**.

---

## Task — System Information Script

### Requirements checklist

| Requirement | Where it is met in `sysinfo.sh` |
|---|---|
| Prints the current date | `current_date=$(date)` then `echo` |
| Prints the hostname | `host_name=$(hostname)` |
| Prints the username | `user_name=$(whoami)` |
| Prints the disk usage | `df -h` |
| Prints the running processes | `ps` |
| Uses variables to store and use data | `current_date`, `host_name`, `user_name`, `report_dir`, `process_file`, `name`, `roll_no`, `comment` |
| Takes user input using `read -p` | three `read -p` prompts |
| Creates a directory using `mkdir` | `mkdir -p "$report_dir"` |
| Creates a file using `touch` | `touch "$process_file"` |
| Stores processes in the file using `>` | `ps -ef > "$process_file"` |

All ten requirements are covered.

---

## How to run

```bash
chmod +x sysinfo.sh
./sysinfo.sh
```

The script prompts for three values (name, roll number, comment), then writes a report directory containing `process.log`.

---

## Command outputs

### Full script run

```
==============================================
           SYSTEM INFORMATION REPORT
==============================================
Current Date : Wed Sep  2 17:17:16 UTC 2026
Hostname     : RidasDen
Username     : ridaa

---------------- DISK USAGE ------------------
Filesystem      Size  Used Avail Use% Mounted on
none            3.8G     0  3.8G   0% /usr/lib/modules/6.18.33.2-microsoft-standard-WSL2
none            3.8G  4.0K  3.8G   1% /mnt/wsl
drivers         534G  238G  297G  45% /usr/lib/wsl/drivers
/dev/sdd       1007G  2.8G  953G   1% /
none            3.8G   32K  3.8G   1% /mnt/wslg
rootfs          3.8G  2.8M  3.8G   1% /init
none            3.8G  576K  3.8G   1% /run
C:\             534G  238G  297G  45% /mnt/c
D:\             396G  1.6G  394G   1% /mnt/d
tmpfs           767M   20K  767M   1% /run/user/1000

------------- RUNNING PROCESSES --------------
    PID TTY          TIME CMD
    458 pts/2    00:00:00 bash
    463 pts/2    00:00:00 ps

Enter your name        : Ridaa Mirza
Enter your roll number : 24BCS10394
Enter a short comment  : Completed the shell scripting homework task.

[+] Directory created : sysinfo_report
[+] File created      : sysinfo_report/process.log
[+] Running processes saved to sysinfo_report/process.log

==============================================
                   SUMMARY
==============================================
My name is        : Ridaa Mirza
My roll number is : 24BCS10394
My comment is     : Completed the shell scripting homework task.
Report generated  : Wed Sep  2 17:17:16 UTC 2026
Report location   : /home/ridaa/sysinfo-run/sysinfo_report
==============================================
```

### Verifying `mkdir` and `touch` worked

```
$ ls -l /home/ridaa/sysinfo-run
total 8
-rwxr-xr-x 1 ridaa ridaa 2331 Sep  2 17:17 sysinfo.sh
drwxr-xr-x 2 ridaa ridaa 4096 Sep  2 17:17 sysinfo_report

$ ls -l sysinfo_report/
total 8
-rw-r--r-- 1 ridaa ridaa 6961 Sep  2 17:17 process.log
```

The directory `sysinfo_report/` and the file `process.log` were both created by the script.

### Verifying the `>` redirection captured the process list

```
$ head -15 sysinfo_report/process.log
UID          PID    PPID  C STIME TTY          TIME CMD
root           1       0 14 17:17 ?        00:00:00 /sbin/init
root           2       1  0 17:17 hvc0     00:00:00 /init
root           7       2  0 17:17 hvc0     00:00:00 plan9 --control-socket 7 --log-level 4 --server-fd 8
root          57       1  3 17:17 ?        00:00:00 /usr/lib/systemd/systemd-journald
root         107       1  3 17:17 ?        00:00:00 /usr/lib/systemd/systemd-udevd
systemd+     116       1  2 17:17 ?        00:00:00 /usr/lib/systemd/systemd-resolved
systemd+     117       1  1 17:17 ?        00:00:00 /usr/lib/systemd/systemd-timesyncd
root         121     107  0 17:17 ?        00:00:00 (udev-worker)
root         122     107  0 17:17 ?        00:00:00 (udev-worker)

$ wc -l sysinfo_report/process.log
93 sysinfo_report/process.log
```

93 process lines were written into the file by `ps -ef > "$process_file"`.

---

## Commands used, and what each one does

| Command | Purpose in this script |
|---|---|
| `date` | Current date and time |
| `hostname` | Machine name |
| `whoami` | Current effective username |
| `df -h` | Disk usage, `-h` for human-readable sizes |
| `ps` | Processes in the current shell |
| `ps -ef` | **Every** process, full format — written to the log |
| `read -p` | Prompt for and read user input |
| `mkdir -p` | Create directory, `-p` avoids an error if it exists |
| `touch` | Create the empty log file |
| `>` | Redirect stdout into the file, overwriting |
| `$(...)` | Command substitution — capture output into a variable |
| `echo` | Print text and variable values |

### A note on command substitution

Storing command output in a variable requires `$(...)`:

```bash
current_date=$(date)     # correct - runs date, stores the result
echo $current_date

hostname_wrong=$hostname # wrong - $hostname is an undefined variable, prints nothing
```

Referencing `$hostname` or `$whoami` directly prints an empty string, because those are command *names*, not shell variables. They must be invoked with `$(hostname)` and `$(whoami)`.

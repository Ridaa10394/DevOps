# Session 1-2 - Linux Fundamentals

Name: Ridaa Mirza
Enrollment No: 24BCS10394

Ran everything on Ubuntu 24.04.1 LTS (kernel 6.18.33.2-microsoft-standard-WSL2). Full raw output is in [links-output.txt](links-output.txt) and [journalctl-output.txt](journalctl-output.txt).

## Task 1 - Soft link vs hard link

Basically: a hard link is just another name pointing at the same inode (same data), while a soft link is its own tiny file that just stores a path to the target.

| | Hard link | Soft link |
|---|---|---|
| What it is | another name for the same inode | a file that stores a path |
| Inode | same as original | its own |
| ls -l type | - | l |
| Link count | goes up on the original | original count unchanged |
| Original deleted | still works, data is safe | breaks (dangling link) |
| Across filesystems | no | yes |
| Can point at a directory | no | yes |

Commands:

```bash
ln  original.txt hardlink.txt     # hard link
ln -s original.txt softlink.txt   # soft link
ls -li                            # -i shows inode numbers
rm hardlink.txt                   # doesnt delete the data unless its the last hard link
```

Here is the demo I ran. Look at the inode column (first) and link count (third):

```
$ ls -li
total 8
11856 -rw-r--r-- 2 ridaa ridaa 27 Sep  2 17:16 hardlink.txt
11856 -rw-r--r-- 2 ridaa ridaa 27 Sep  2 17:16 original.txt
11857 lrwxrwxrwx 1 ridaa ridaa 12 Sep  2 17:16 softlink.txt -> original.txt
```

original.txt and hardlink.txt share inode 11856 and both show link count 2, so they are really the same file. softlink.txt has its own inode (11857), link count 1, type l, and just points at original.txt.

Now the actual test - delete the original and see what happens to each link:

```
$ rm original.txt

$ cat hardlink.txt   # still works, data survives
This is the original file.
Line added via hardlink.

$ cat softlink.txt   # broken, target is gone
cat: softlink.txt: No such file or directory
```

That is the whole point of the exercise - the hard link kept the data alive, the soft link broke because it only had the path, not the data.

Why this happens: a hard link is basically an extra directory entry pointing to the same inode, so the data only actually gets freed once every hard link to it is gone. A soft link is a separate little file whose content is just a path, so if the target moves or gets deleted, it breaks. That is also why hard links cannot cross filesystems or point at directories (inode numbers only make sense within one filesystem) but soft links can do both since they are just storing text.

## Task 2 - adduser vs useradd

| | useradd | adduser |
|---|---|---|
| Type | low-level binary | perl script that wraps useradd |
| Works on | any distro | Debian/Ubuntu family |
| Interactive | no | yes, asks for password + full name |
| Home directory | not created unless you pass -m | created automatically |
| Password | not set | prompts you |
| Shell | usually /bin/sh or nothing | sets /bin/bash |
| Skeleton files | only with -m | copied automatically |
| Best for | scripts / automation | a human typing at a terminal |

adduser is the one to use on Ubuntu if you are doing it by hand. It follows Debian's own conventions (reads /etc/adduser.conf), makes the home dir, copies /etc/skel, sets a real shell, makes a matching group, and asks for a password, all in one go.

Just running `useradd bob` on its own does none of that, so you end up with a locked, home-less account that is basically useless until you fix it up manually. That said, useradd is still the right tool inside scripts, Dockerfiles, Ansible etc, because it is non-interactive and works the same everywhere.

```bash
# recommended on Ubuntu for a human
sudo adduser testuser

# same result the long way
sudo useradd -m -s /bin/bash -c "Test User" testuser
sudo passwd testuser

# check it worked
grep testuser /etc/passwd
id testuser
ls -ld /home/testuser

# clean up
sudo deluser --remove-home testuser
```

Note: these are the only commands here that need root, and I could not actually run them since sudo is password protected in this environment. Everything else in this repo has real captured output.

## Task 3 - journalctl

journalctl reads the systemd journal - the binary, indexed log store that systemd-journald writes to, instead of plain text files like /var/log/syslog. Since every entry has metadata attached (unit, PID, UID, priority, boot ID) you can filter it a lot more precisely than just grepping through text files.

Some useful ones:

| Command | What it does |
|---|---|
| `journalctl` | everything, oldest first |
| `journalctl -n 20` | last 20 lines |
| `journalctl -f` | follow live, like tail -f |
| `journalctl -u nginx.service` | logs for one service |
| `journalctl -u nginx -f` | follow one service live |
| `journalctl -b` | logs from this boot |
| `journalctl -b -1` | logs from the previous boot |
| `journalctl -p err` | only err and worse |
| `journalctl --since today` | time filter |
| `journalctl --since "1 hour ago"` | relative time window |
| `journalctl -o json-pretty` | full structured output |
| `journalctl --disk-usage` | how much disk the journal is using |
| `journalctl --vacuum-time=7d` | delete anything older than 7 days |
| `journalctl -k` | kernel messages only, like dmesg |

Priority levels for -p, from worst to least bad: emerg(0) alert(1) crit(2) err(3) warning(4) notice(5) info(6) debug(7).

Checked logs for a specific service:

```
$ journalctl -u systemd-resolved.service -n 10 --no-pager
Sep 02 17:18:32 RidasDen systemd[1]: Stopped systemd-resolved.service - Network Name Resolution.
Sep 02 17:18:53 RidasDen systemd[1]: Starting systemd-resolved.service - Network Name Resolution...
Sep 02 17:18:53 RidasDen systemd-resolved[116]: Positive Trust Anchors:
Sep 02 17:18:53 RidasDen systemd-resolved[116]: Using system hostname 'RidasDen'.
Sep 02 17:18:53 RidasDen systemd[1]: Started systemd-resolved.service - Network Name Resolution.
```

And filtered down to just errors:

```
$ journalctl -p err -n 10 --no-pager
Sep 02 17:18:53 RidasDen systemd[1]: Failed to start wsl-pro.service - Bridge to Ubuntu Pro agent on Windows.
Sep 02 17:18:42 RidasDen login[362]: PAM unable to dlopen(pam_lastlog.so): No such file or directory
Sep 02 17:18:42 RidasDen login[362]: PAM adding faulty module: pam_lastlog.so
```

That is basically the whole point of journalctl - one flag cut thousands of lines down to the 3 that actually matter.

Full output including -b, --disk-usage and -o json-pretty is in [journalctl-output.txt](journalctl-output.txt).

## Task 4 - Linux command cheat sheet

Navigation and files:

| Command | Purpose |
|---|---|
| `pwd` | print working directory |
| `ls -la` | list all files, long format |
| `cd -` | jump back to previous directory |
| `touch f` | create empty file / update timestamp |
| `mkdir -p a/b/c` | create nested directories |
| `cp -r src dst` | copy recursively |
| `mv a b` | move or rename |
| `rm -rf dir` | delete recursively and forcefully |
| `find . -name "*.log"` | find files by name |
| `find . -mtime -1` | files modified in the last day |

Viewing and editing:

| Command | Purpose |
|---|---|
| `cat f` | print whole file |
| `less f` | page through a file |
| `head -20 f` | first 20 lines |
| `tail -20 f` | last 20 lines |
| `tail -f f` | follow a growing file |
| `grep -rn "text" .` | recursive search with line numbers |
| `sed -i 's/a/b/g' f` | in-place find and replace |
| `awk '{print $1}' f` | print the first column |
| `wc -l f` | count lines |
| `diff a b` | compare two files |

Permissions and ownership:

| Command | Purpose |
|---|---|
| `chmod 755 f` | rwx for owner, rx for group and others |
| `chmod +x f` | make executable |
| `chown user:group f` | change owner and group |
| `umask` | default permission mask |
| `sudo -i` | interactive root shell |

Processes:

| Command | Purpose |
|---|---|
| `ps aux` | all running processes |
| `ps -ef` | same, different format |
| `top` / `htop` | live process monitor |
| `kill -9 PID` | force kill |
| `pkill name` | kill by name |
| `jobs` / `fg` / `bg` | job control |
| `nohup cmd &` | run detached from the terminal |

Disk and system:

| Command | Purpose |
|---|---|
| `df -h` | disk free, human readable |
| `du -sh *` | size of each item here |
| `free -h` | memory usage |
| `uname -a` | kernel and architecture |
| `uptime` | load average |
| `lsblk` | block devices |
| `mount` / `umount` | attach / detach filesystems |

Services and logs:

| Command | Purpose |
|---|---|
| `systemctl status nginx` | service state |
| `systemctl start nginx` | start a service |
| `systemctl restart nginx` | restart a service |
| `systemctl enable nginx` | start at boot |
| `journalctl -u nginx -f` | follow service logs |

Archives, networking, packages:

| Command | Purpose |
|---|---|
| `tar -czvf a.tar.gz dir/` | create a gzip archive |
| `tar -xzvf a.tar.gz` | extract a gzip archive |
| `curl -I url` | fetch headers only |
| `wget url` | download a file |
| `scp f user@host:/path` | copy over SSH |
| `apt update` | refresh package lists |
| `apt install pkg` | install a package |

Pipes and redirection:

| Syntax | Meaning |
|---|---|
| `>` | redirect stdout, overwrite |
| `>>` | redirect stdout, append |
| `2>` | redirect stderr |
| `&>` | redirect both |
| `\|` | pipe stdout into the next command |
| `tee f` | write to a file and stdout |
| `xargs` | turn stdin into arguments |

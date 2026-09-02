#!/bin/bash
# ---------------------------------------------------------------
# System Information Script
# DevOps Homework - Shell Scripting
# ---------------------------------------------------------------
# Requirements covered:
#   - prints current date, hostname, username, disk usage, processes
#   - uses variables to store and reuse data
#   - takes user input with read -p
#   - creates a directory with mkdir and a file with touch
#   - stores running processes in the file using > redirection
# ---------------------------------------------------------------

# ---- 1. Store system data in variables -------------------------
current_date=$(date)
host_name=$(hostname)
user_name=$(whoami)

# ---- 2. Print the system information ---------------------------
echo "=============================================="
echo "           SYSTEM INFORMATION REPORT          "
echo "=============================================="
echo "Current Date : $current_date"
echo "Hostname     : $host_name"
echo "Username     : $user_name"
echo

echo "---------------- DISK USAGE ------------------"
df -h
echo

echo "------------- RUNNING PROCESSES --------------"
ps
echo

# ---- 3. Take user input with read -p ---------------------------
read -p "Enter your name        : " name
read -p "Enter your roll number : " roll_no
read -p "Enter a short comment  : " comment
echo

# ---- 4. Create a directory with mkdir --------------------------
report_dir="sysinfo_report"
mkdir -p "$report_dir"
echo "[+] Directory created : $report_dir"

# ---- 5. Create a file with touch -------------------------------
process_file="$report_dir/process.log"
touch "$process_file"
echo "[+] File created      : $process_file"

# ---- 6. Store running processes in the file using > ------------
ps -ef > "$process_file"
echo "[+] Running processes saved to $process_file"
echo

# ---- 7. Summary using the input variables ----------------------
echo "=============================================="
echo "                   SUMMARY                    "
echo "=============================================="
echo "My name is        : $name"
echo "My roll number is : $roll_no"
echo "My comment is     : $comment"
echo "Report generated  : $current_date"
echo "Report location   : $(pwd)/$report_dir"
echo "=============================================="

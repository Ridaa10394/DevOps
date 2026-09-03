#!/bin/bash

current_date=$(date)
host_name=$(hostname)
user_name=$(whoami)

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

read -p "Enter your name        : " name
read -p "Enter your roll number : " roll_no
read -p "Enter a short comment  : " comment
echo

report_dir="sysinfo_report"
mkdir -p "$report_dir"
echo "[+] Directory created : $report_dir"

process_file="$report_dir/process.log"
touch "$process_file"
echo "[+] File created      : $process_file"

ps -ef > "$process_file"
echo "[+] Running processes saved to $process_file"
echo

echo "=============================================="
echo "                   SUMMARY                    "
echo "=============================================="
echo "My name is        : $name"
echo "My roll number is : $roll_no"
echo "My comment is     : $comment"
echo "Report generated  : $current_date"
echo "Report location   : $(pwd)/$report_dir"
echo "=============================================="

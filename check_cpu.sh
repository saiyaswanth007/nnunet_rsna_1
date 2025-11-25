#!/bin/bash
#
#SBATCH --job-name=check_cpu
#SBATCH --output=cpu_info.out
#SBATCH --error=cpu_info.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1  # Just need 1 core to run the check
#SBATCH --time=00:05:00    # 5 minutes is plenty

echo "=========================================="
echo "Running on node: $(hostname)"
echo "=========================================="

echo "--- CPU Architecture (lscpu) ---"
lscpu

echo "------------------------------------------"
echo "--- Total Logical Cores (nproc) ---"
nproc --all

echo "------------------------------------------"
echo "--- Memory Info (free -h) ---"
free -h

echo "=========================================="

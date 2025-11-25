#!/bin/bash
#
#SBATCH --job-name=rsna_train         # Descriptive job name
#SBATCH --output=rsna_train_%j.out    # Standard output log
#SBATCH --error=rsna_train_%j.err     # Standard error log
#SBATCH --gpus=a100:2                 # Request 2 A100 GPUs
#SBATCH --time=3-00:00:00             # Request 3 days
#SBATCH --mem=64G                     # Request 64GB RAM (increased for 3D data)
#SBATCH --cpus-per-task=16            # Match num_workers in config (12) + overhead

# --- Setup ---

echo "======================================================"
echo "Starting job at $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Running on node: $(hostname)"
echo "======================================================"

# Initialize Conda
source /maahr/home/internuser17/anaconda3/etc/profile.d/conda.sh

# Activate environment
echo "Activating conda environment: rsna_aneurysm"
conda activate rsna_aneurysm

if [ $? -ne 0 ]; then
    echo "Error: Failed to activate conda environment 'rsna_aneurysm'"
    exit 1
fi

# --- Environment Variables ---
# Set these to point to your actual data locations
export PROJECT_ROOT="/maahr/home/internuser17/nnunet_rsna_1"
export PYTHONPATH="$PROJECT_ROOT:$PYTHONPATH"

# nnU-Net specific paths (Adjust these if your data is elsewhere)
export nnUNet_raw="$PROJECT_ROOT/data/nnUNet_raw"
export nnUNet_preprocessed="$PROJECT_ROOT/data/nnUNet_preprocessed"
export nnUNet_results="$PROJECT_ROOT/data/nnUNet_results"

# --- Execution ---

echo "Conda environment activated."
echo "Running Training Script..."

# Navigate to project root
cd $PROJECT_ROOT

# Run the training script
# Note: Using 'python src/train.py' as that is the entry point for the ROI classifier
# If you intended to run nnU-Net training, the command would be different (nnUNetv2_train ...)
python src/train.py

echo "======================================================"
echo "Job finished at $(date)"
echo "======================================================"

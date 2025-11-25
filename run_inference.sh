#!/bin/bash
#
#SBATCH --job-name=rsna_infer
#SBATCH --output=rsna_infer_%j.out
#SBATCH --error=rsna_infer_%j.err
#SBATCH --gpus=a100:1                 # Inference is fast, 1 GPU is usually enough
#SBATCH --time=0-04:00:00             # 4 hours
#SBATCH --mem=64G                     # 64GB RAM
#SBATCH --cpus-per-task=8             # 8 CPUs

# --- Setup ---
source /maahr/home/internuser17/anaconda3/etc/profile.d/conda.sh
conda activate rsna_aneurysm
export PROJECT_ROOT="/maahr/home/internuser17/nnunet_rsna_1"
export PYTHONPATH="$PROJECT_ROOT:$PYTHONPATH"
export nnUNet_raw="$PROJECT_ROOT/data/nnUNet_raw"
export nnUNet_preprocessed="$PROJECT_ROOT/data/nnUNet_preprocessed"
export nnUNet_results="$PROJECT_ROOT/data/nnUNet_results"

# --- Configuration ---
# Point to your trained models here
export VESSEL_NNUNET_MODEL_DIR="$nnUNet_results/Dataset001_VesselSegmentation/RSNA2025Trainer_moreDAv6_1_SkeletonRecallTverskyBeta07__nnUNetResEncUNetMPlans__3d_fullres"
export ROI_EXPERIMENTS="251018-seg_tf-v4-nnunet_truncate1_preV6_1-ex_dav6w3-m32g64-e25-w01_005_1-s128_256_256-test"
export ROI_FOLDS="0,1,2,3,4"
export ROI_CKPT="last"
export VESSEL_FOLDS="all"

# --- Execution ---
# This python script needs to be created to call the predict() function
# We will create a small wrapper script 'run_inference_wrapper.py' on the fly
cat <<EOF > run_inference_wrapper.py
import os
import sys
import glob
from scripts.rsna_submission_roi import predict

# INPUT: Directory containing DICOM series (e.g., /path/to/test_data/series_id)
# You can change this to iterate over a CSV or directory
TEST_DATA_DIR = "$PROJECT_ROOT/data/test_series" 

if not os.path.exists(TEST_DATA_DIR):
    print(f"Error: Test directory {TEST_DATA_DIR} not found.")
    sys.exit(1)

# Iterate over series folders
series_paths = glob.glob(os.path.join(TEST_DATA_DIR, "*"))
print(f"Found {len(series_paths)} series to process.")

for series_path in series_paths:
    if not os.path.isdir(series_path):
        continue
        
    series_id = os.path.basename(series_path)
    print(f"Processing {series_id}...")
    
    try:
        # Run prediction
        results = predict(series_path)
        print(f"Results for {series_id}: {results}")
        
        # Save results (optional)
        # ...
        
    except Exception as e:
        print(f"Error processing {series_id}: {e}")

EOF

echo "Starting Inference..."
python run_inference_wrapper.py
echo "Inference Finished."

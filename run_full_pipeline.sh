#!/bin/bash
#
#SBATCH --job-name=rsna_full          # Descriptive job name
#SBATCH --output=rsna_full_%j.out     # Standard output log
#SBATCH --error=rsna_full_%j.err      # Standard error log
#SBATCH --gpus=a100:2                 # Request 2 A100 GPUs
#SBATCH --time=7-00:00:00             # Request 7 days (this is a LONG pipeline)
#SBATCH --mem=256G                    # Request 256GB RAM (preprocessing needs memory)
#SBATCH --cpus-per-task=24            # Reserve 24 cores (2 GPUs * 12 workers = 24)

# --- Setup ---

echo "======================================================"
echo "Starting FULL PIPELINE job at $(date)"
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
export PROJECT_ROOT="/maahr/home/internuser17/nnunet_rsna_1"
export PYTHONPATH="$PROJECT_ROOT:$PYTHONPATH"
export nnUNet_raw="$PROJECT_ROOT/data/nnUNet_raw"
export nnUNet_preprocessed="$PROJECT_ROOT/data/nnUNet_preprocessed"
export nnUNet_results="$PROJECT_ROOT/data/nnUNet_results"

# Navigate to project root
cd $PROJECT_ROOT

# Install requirements
echo "Installing requirements..."
pip install -r pip_packages/requirements.txt

# ==============================================================================
# STEP 1: DICOM to NIfTI Conversion
# ==============================================================================
echo "--- STEP 1: DICOM to NIfTI Conversion ---"
python src/my_utils/rsna_dcm2niix.py

# ==============================================================================
# STEP 2: Move Erroneous Data
# ==============================================================================
echo "--- STEP 2: Cleaning Error Data ---"
python src/my_utils/move_error_data.py

# ==============================================================================
# STEP 3: Create nnU-Net Datasets
# ==============================================================================
echo "--- STEP 3: Creating nnU-Net Datasets ---"
python src/nnUnet_utils/create_nnunet_dataset.py
python src/nnUnet_utils/create_nnunet_dataset.py --dataset-id 3

# ==============================================================================
# STEP 4: nnU-Net Planning & Preprocessing
# ==============================================================================
echo "--- STEP 4: nnU-Net Planning & Preprocessing ---"
# Dataset 1
nnUNetv2_plan_and_preprocess -d 1 --verify_dataset_integrity -pl nnUNetPlannerResEncM

# Dataset 3 (Special handling for lowres)
nnUNetv2_plan_and_preprocess -d 3 --verify_dataset_integrity -pl nnUNetPlannerResEncMForcedLowres -overwrite_target_spacing 1.0 1.0 1.0 -c 3d_fullres
https://www.kaggle.com/code/tomoon33/rsna2025-submission-1st-place/input

https://www.kaggle.com/datasets/tomoon33/251013-prev6-1-ex-dav6w3-e25-w01-005-1-s128-256

https://www.kaggle.com/datasets/tomoon33/nnunet-da3-sklr-ep800

https://www.kaggle.com/datasets/tomoon33/nnunet-da3-sklr-with-all

https://www.kaggle.com/datasets/tomoon33/nnunet-da6-1-sklr-tv07
https://www.kaggle.com/datasets/tomoon33/nnunet-da6-sklr-w3-tv07
https://www.kaggle.com/datasets/tomoon33/nnunet-vessel-grouping-da7
# Dataset 3 Patch Size Fix (Manual step automated here via sed if needed, but assuming default plan works or user edited it)
# NOTE: The README says "In Dataset003 plans.json, set patch_size to [128, 128, 128]".
# We will attempt to patch this automatically using python to be safe.
echo "Patching Dataset003 plans..."
python -c "import json; f='$nnUNet_preprocessed/Dataset003_VesselGrouping/nnUNetResEncUNetMPlans.json'; d=json.load(open(f)); d['configurations']['3d_fullres']['patch_size']=[128,128,128]; json.dump(d, open(f,'w'), indent=4)"

# Re-preprocess Dataset 3
nnUNetv2_preprocess -d 3 -plans_name nnUNetResEncUNetMPlans -c 3d_fullres

# ==============================================================================
# STEP 5: Create Inference Set
# ==============================================================================
echo "--- STEP 5: Creating Inference Set ---"
python src/nnUnet_utils/create_nnunet_inference_dataset.py

# ==============================================================================
# STEP 6: nnU-Net Training (The Long Part)
# ==============================================================================
echo "--- STEP 6: Training nnU-Net Models ---"
# Train Dataset 1 (Vessel Segmentation) - 5 Folds
# Using 'all' to train on all data for production/submission model, or 0 1 2 3 4 for CV
# The README suggests 'all' for the final models.
nnUNetv2_train 1 3d_fullres all -num_gpus 2 -p nnUNetResEncUNetMPlans -tr nnUNetTrainerSkeletonRecall_more_DAv3
nnUNetv2_train 1 3d_fullres all -num_gpus 2 -p nnUNetResEncUNetMPlans -tr RSNA2025Trainer_moreDAv6_SkeletonRecallW3TverskyBeta07
nnUNetv2_train 1 3d_fullres all -num_gpus 2 -p nnUNetResEncUNetMPlans -tr RSNA2025Trainer_moreDAv6_1_SkeletonRecallTverskyBeta07

# Train Dataset 3 (Vessel Grouping)
nnUNetv2_train 3 3d_fullres all -num_gpus 2 -p nnUNetResEncUNetMPlans -tr RSNA2025Trainer_moreDAv7

# ==============================================================================
# STEP 7: Vessel Segmentation Inference (Generate ROIs)
# ==============================================================================
echo "--- STEP 7: Running Vessel Segmentation Inference ---"
python src/my_utils/vessel_segmentation.py

# ==============================================================================
# STEP 8: ROI Classification Training
# ==============================================================================
echo "--- STEP 8: Training ROI Classifier ---"
# Using train_cv.py for 5-fold CV as per README
python src/train_cv.py

echo "======================================================"
echo "FULL PIPELINE FINISHED at $(date)"
echo "======================================================"

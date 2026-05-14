#!/bin/bash --login

#SBATCH --job-name=s3-file-transfer   # Job name
#SBATCH --partition=copy             # Queue (partition) name
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G                     # Minimal memory allocation (1GB)
#SBATCH --account=y95
#SBATCH --time=48:00:00              # Maximum runtime (48 hours)

# Load necessary modules
module load rclone/1.68.1

# Input path to transfer.
# This can be either:
# - a single file
# - an entire directory
data=$1

# Destination path on the remote storage (y95).
# Example:
#   myfolder/results
# Files will be copied to:
#   y95:myfolder/results
remote_dir=$2

# Generate timestamp for unique log filenames
timestamp=$(date +"%Y%m%d_%H%M%S")

# Copy files/directories to remote storage using rclone
rclone copy "${data}" "y95:${remote_dir}" \
  --progress \                         # Show real-time transfer progress
  --log-file="rclone_${timestamp}.log" \  # Save transfer log to file
  --log-level=INFO \                  # Log transfer information
  --checksum                          # Verify files using checksums

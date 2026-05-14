#!/bin/bash --login

#SBATCH --job-name=s3-file-transfer   # Job name
#SBATCH --partition=copy             # Queue (partition) name
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G                     # Minimal memory allocation (1GB)
#SBATCH --account=pawsey1142
#SBATCH --time=48:00:00              # Maximum runtime (48 hours)

# Load necessary modules
module load rclone/1.68.1

#
# Example usage:
#
# Copy a single file:
#   sbatch transfer-acacia.sbatch results.txt backup/results
#
# Copy an entire directory:
#   sbatch transfer-acacia.sbatch /scratch/project/run1 backup/run1
#
# Copy sequencing files stored in a directory:
#   sbatch transfer-acacia.sbatch /scratch/project/fastq_files sequencing_backup/fastqs
#
# Files will be copied to:
#   pawsey1142:<remote_dir>

# Input path to transfer.
# This can be either:
# - a single file
# - an entire directory
data=$1

# Destination path on the remote storage.
# Example:
#   myfolder/results
# Files will be copied to:
#   pawsey1142:myfolder/results
remote_dir=$2

# Generate timestamp for unique log filenames
timestamp=$(date +"%Y%m%d_%H%M%S")

# Copy files/directories to remote storage using rclone
rclone copy "${data}" "pawsey1142:${remote_dir}" \
  --progress \                         # Show real-time transfer progress
  --log-file="rclone_${timestamp}.log" \  # Save transfer log to file
  --log-level=INFO \                  # Log transfer information
  --checksum                          # Verify files using checksums

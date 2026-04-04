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

data=$1
remote_dir=$2

timestamp=$(date +"%Y%m%d_%H%M%S")

# move files
rclone copy ${data} y95:${remote_dir} \
  --progress \
  --log-file="rclone_${timestamp}.log" \
  --log-level=INFO \
  --checksum

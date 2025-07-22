## Initialize conda environment on scratch space

Example commands
```
#!/bin/bash
set -euo pipefail

# Define scratch install directory
INSTALL_DIR="/scratch/y95/kgagalova/miniforge"

# Download and install Miniforge
curl -LO https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash Miniforge3-Linux-x86_64.sh -b -p "$INSTALL_DIR"

# Set Conda-related environment variables
export CONDARC="$INSTALL_DIR/.condarc"
export CONDA_ENVS_PATH="$INSTALL_DIR/conda_envs"
export CONDA_PKGS_DIRS="$INSTALL_DIR/conda_pkgs"
export CONDA_CACHE_DIR="$INSTALL_DIR/conda_cache"
export HOME="$INSTALL_DIR"  # Optional but ensures isolation from $HOME/.conda

# Create the .condarc configuration file before running mamba/conda
cat <<EOF > "$CONDARC"
channels:
  - conda-forge
  - bioconda
  - defaults
channel_priority: strict
auto_activate_base: false
show_channel_urls: true
envs_dirs:
  - $CONDA_ENVS_PATH
pkgs_dirs:
  - $CONDA_PKGS_DIRS
EOF

# Activate the shell environment for this Miniforge installation
eval "$($INSTALL_DIR/bin/conda shell.bash hook)"

# Show environment info
conda info | grep -E 'pkgs|envs|rc file|base environment'

# Install mamba in the base environment
conda install -n base mamba -c conda-forge

# Create a new environment (adjust Python version as needed)
mamba create -n myenv python=3.7 poetry=1.1.12 -y

# Activate environment (interactive use only; for scripts, prefer conda run or PATH export)
# conda activate myenv

# Use the environment (example usage without activate)
$INSTALL_DIR/bin/conda run -n myenv python --version
```

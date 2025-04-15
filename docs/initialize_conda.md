## Initialize conda environment on scratch space

Example commands
```
curl -LO https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh

bash Miniforge3-Linux-x86_64.sh -b -p "$(pwd)/miniforge"
eval "$(/scratch/y95/kgagalova/mamba/miniforge/bin/conda shell.bash hook)"
conda info | grep -E 'pkgs|envs|rc file|base environment'

export CONDARC="$(pwd)/condarc"
export CONDA_ENVS_PATH="$(pwd)/conda_envs"
export CONDA_PKGS_DIRS="$(pwd)/conda_pkgs"
export CONDA_CACHE_DIR="$(pwd)/conda_cache"
export HOME="$(pwd)"

# Activate Conda environment
eval "$($(pwd)/miniforge/bin/conda shell.bash hook)"

conda info | grep -E 'pkgs|envs|rc file|base environment'

conda install mamba -n base -c conda-forge
mamba create -n myenv python=3.7.4 poetry=1.1.12
conda activate myenv
```
